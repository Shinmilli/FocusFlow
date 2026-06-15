import crypto from "node:crypto";

import { geminiGenerateJson } from "../gemini.js";
import {
  buildGoogleAuthUrl,
  fetchGoogleCalendarItems,
  googleMcpConfigured,
  handleGoogleCallback,
} from "./google-calendar.js";
import {
  buildNotionAuthUrl,
  fetchNotionItems,
  handleNotionCallback,
  notionMcpConfigured,
} from "./notion.js";
import {
  consumeOAuthState,
  deleteToken,
  ensureMcpSchema,
  listConnectedProviders,
  saveOAuthState,
} from "./oauth-store.js";

const ORGANIZE_SYSTEM = `You are FocusFlow's ADHD-friendly planning assistant.
Given external items (calendar events, Notion tasks), produce a focused plan for TODAY.
Rules:
- Suggest at most 3 task blocks for deep focus.
- Each block has 2-5 small actionable units (first step should be tiny, under 5 minutes).
- Merge related items when sensible; skip all-day low-priority events.
- Respond ONLY with valid JSON matching this schema:
{
  "messageForUser": "short encouraging Korean message",
  "blocks": [
    {
      "title": "block title in Korean",
      "units": ["step1", "step2"],
      "sourceRefs": ["google_calendar:abc", "notion:xyz"]
    }
  ]
}`;

function oauthSuccessHtml(provider) {
  const label =
    provider === "google" ? "Google Calendar" : provider === "notion" ? "Notion" : provider;
  return `<!DOCTYPE html><html lang="ko"><head><meta charset="utf-8"/>
<title>FocusFlow 연결 완료</title>
<style>body{font-family:system-ui,sans-serif;max-width:420px;margin:48px auto;padding:0 20px;color:#1a1c26}
h1{font-size:1.35rem}p{color:#5c6378;line-height:1.5}</style></head>
<body><h1>${label} 연결 완료</h1>
<p>이 창을 닫고 FocusFlow 앱으로 돌아가 주세요. 연결 상태가 자동으로 반영돼요.</p></body></html>`;
}

/**
 * @param {import("express").Express} app
 * @param {{ pool: import("pg").Pool; authMiddleware: Function; geminiApiKey: string; geminiModel: string }} deps
 */
export function registerMcpRoutes(app, { pool, authMiddleware, geminiApiKey, geminiModel }) {
  ensureMcpSchema(pool).catch((e) => console.error("MCP schema error:", e));

  app.get("/mcp/status", authMiddleware, async (req, res) => {
    const connected = await listConnectedProviders(pool, req.user.id);
    const map = Object.fromEntries(connected.map((r) => [r.provider, { connected: true }]));

    return res.json({
      google: {
        configured: googleMcpConfigured(),
        connected: Boolean(map.google?.connected),
      },
      notion: {
        configured: notionMcpConfigured(),
        connected: Boolean(map.notion?.connected),
      },
      samsungCalendar: {
        configured: true,
        connected: null,
        note: "기기 캘린더(삼성 포함)는 앱에서 직접 읽어요",
      },
    });
  });

  app.get("/mcp/google/auth-url", authMiddleware, async (req, res) => {
    if (!googleMcpConfigured()) {
      return res.status(503).json({ error: "Google OAuth is not configured on this server" });
    }
    const state = crypto.randomBytes(24).toString("hex");
    await saveOAuthState(pool, { state, userId: req.user.id, provider: "google" });
    return res.json({ url: buildGoogleAuthUrl(state) });
  });

  app.get("/mcp/notion/auth-url", authMiddleware, async (req, res) => {
    if (!notionMcpConfigured()) {
      return res.status(503).json({ error: "Notion OAuth is not configured on this server" });
    }
    const state = crypto.randomBytes(24).toString("hex");
    await saveOAuthState(pool, { state, userId: req.user.id, provider: "notion" });
    return res.json({ url: buildNotionAuthUrl(state) });
  });

  app.get("/mcp/google/callback", async (req, res) => {
    const code = String(req.query?.code || "");
    const state = String(req.query?.state || "");
    if (!code || !state) {
      return res.status(400).send("Missing code or state");
    }
    try {
      const row = await consumeOAuthState(pool, state);
      if (!row || row.provider !== "google") {
        return res.status(400).send("Invalid or expired OAuth state");
      }
      await handleGoogleCallback(pool, code, row.user_id);
      return res.type("html").send(oauthSuccessHtml("google"));
    } catch (e) {
      console.error("Google OAuth callback:", e);
      return res.status(500).send("OAuth failed");
    }
  });

  app.get("/mcp/notion/callback", async (req, res) => {
    const code = String(req.query?.code || "");
    const state = String(req.query?.state || "");
    if (!code || !state) {
      return res.status(400).send("Missing code or state");
    }
    try {
      const row = await consumeOAuthState(pool, state);
      if (!row || row.provider !== "notion") {
        return res.status(400).send("Invalid or expired OAuth state");
      }
      await handleNotionCallback(pool, code, row.user_id);
      return res.type("html").send(oauthSuccessHtml("notion"));
    } catch (e) {
      console.error("Notion OAuth callback:", e);
      return res.status(500).send("OAuth failed");
    }
  });

  app.post("/mcp/disconnect", authMiddleware, async (req, res) => {
    const provider = String(req.body?.provider || "").trim();
    if (!["google", "notion"].includes(provider)) {
      return res.status(400).json({ error: "provider must be google or notion" });
    }
    await deleteToken(pool, req.user.id, provider);
    return res.json({ ok: true });
  });

  app.post("/mcp/fetch", authMiddleware, async (req, res) => {
    const [googleItems, notionItems] = await Promise.all([
      fetchGoogleCalendarItems(pool, req.user.id),
      fetchNotionItems(pool, req.user.id),
    ]);
    return res.json({
      items: [...googleItems, ...notionItems],
    });
  });

  app.post("/mcp/organize", authMiddleware, async (req, res) => {
    if (!geminiApiKey) {
      return res.status(503).json({ error: "GEMINI_API_KEY is not set on this server" });
    }

    const items = Array.isArray(req.body?.items) ? req.body.items : [];
    const lifeContext = req.body?.lifeContext ?? {};
    const existingTitles = Array.isArray(req.body?.existingTitles) ? req.body.existingTitles : [];

    if (items.length === 0) {
      return res.status(400).json({ error: "items array is required and must not be empty" });
    }

    const userPrompt = JSON.stringify({
      externalItems: items.slice(0, 40),
      lifeContext,
      existingTitles: existingTitles.slice(0, 20),
      today: new Date().toISOString().slice(0, 10),
    });

    try {
      const result = await geminiGenerateJson({
        apiKey: geminiApiKey,
        model: geminiModel,
        system: ORGANIZE_SYSTEM,
        user: userPrompt,
      });

      const blocks = Array.isArray(result?.blocks) ? result.blocks : [];
      const normalized = blocks.slice(0, 3).map((b) => ({
        title: String(b?.title || "").trim(),
        units: (Array.isArray(b?.units) ? b.units : [])
          .map((u) => String(u || "").trim())
          .filter(Boolean)
          .slice(0, 6),
        sourceRefs: Array.isArray(b?.sourceRefs) ? b.sourceRefs.map(String) : [],
      }));

      return res.json({
        messageForUser: String(result?.messageForUser || "오늘 할 일을 정리했어요."),
        blocks: normalized.filter((b) => b.title && b.units.length > 0),
      });
    } catch (e) {
      console.error("MCP organize error:", e);
      return res.status(502).json({ error: String(e?.message || e) });
    }
  });
}
