import "dotenv/config";
import crypto from "node:crypto";
import express from "express";
import cors from "cors";
import bcrypt from "bcryptjs";
import jwt from "jsonwebtoken";
import pg from "pg";

import { geminiGenerateJson, geminiGenerateText } from "./gemini.js";
import { registerMcpRoutes } from "./mcp/routes.js";
import { ensureMcpSchema } from "./mcp/oauth-store.js";

const { Pool } = pg;

const PORT = Number(process.env.PORT) || 8787;

function normalizeEnv(value) {
  return String(value ?? "")
    .trim()
    .replace(/^['"]|['"]$/g, "");
}

const DATABASE_URL = normalizeEnv(process.env.DATABASE_URL);
const JWT_SECRET = normalizeEnv(process.env.JWT_SECRET);
// Long-lived until explicit logout; override with JWT_EXPIRES (e.g. "90d") if you prefer shorter tokens.
const JWT_EXPIRES = process.env.JWT_EXPIRES || "365d";
const CORS_ORIGIN = process.env.CORS_ORIGIN || "";
/** Google AI Studio API key — set on Render only, never in Flutter web. */
const GEMINI_API_KEY = process.env.GEMINI_API_KEY || "";
const GEMINI_MODEL = process.env.GEMINI_MODEL || "gemini-1.5-flash";

if (!DATABASE_URL) {
  console.error("Missing DATABASE_URL (add Render PostgreSQL and link to this service).");
  process.exit(1);
}

function validateDatabaseUrl(url) {
  try {
    const parsed = new URL(url.replace(/^postgresql:\/\//, "http://"));
    if (!parsed.hostname.includes(".")) {
      console.error(
        `DATABASE_URL hostname looks truncated: "${parsed.hostname}"`,
      );
      console.error(
        "Render Postgres needs the full host, e.g. dpg-xxxx.singapore-postgres.render.com",
      );
      console.error(
        "Fix: Render Dashboard → PostgreSQL → Connect → copy Internal Database URL → paste into Web Service DATABASE_URL (no quotes).",
      );
      process.exit(1);
    }
  } catch (e) {
    console.error("Invalid DATABASE_URL format:", e.message);
    process.exit(1);
  }
}

validateDatabaseUrl(DATABASE_URL);

if (!JWT_SECRET || JWT_SECRET.length < 16) {
  console.error("Missing or weak JWT_SECRET (use at least 16 random characters).");
  process.exit(1);
}

const pool = new Pool({
  connectionString: DATABASE_URL,
  ssl: DATABASE_URL.includes("localhost") ? false : { rejectUnauthorized: false },
});

async function ensureSchema() {
  await pool.query(`
    CREATE TABLE IF NOT EXISTS users (
      id UUID PRIMARY KEY,
      email TEXT UNIQUE NOT NULL,
      password_hash TEXT NOT NULL,
      nickname TEXT NOT NULL DEFAULT '',
      created_at TIMESTAMPTZ NOT NULL DEFAULT now()
    );
  `);
  // Existing DBs from before "nickname" — CREATE TABLE IF NOT EXISTS does not add columns.
  await pool.query(`
    ALTER TABLE users ADD COLUMN IF NOT EXISTS nickname TEXT NOT NULL DEFAULT '';
  `);
  await pool.query(`
    CREATE TABLE IF NOT EXISTS user_app_sync (
      user_id UUID PRIMARY KEY REFERENCES users(id) ON DELETE CASCADE,
      payload JSONB NOT NULL DEFAULT '{}'::jsonb,
      updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
    );
  `);
  await ensureMcpSchema(pool);
}

function signToken(userId, email) {
  return jwt.sign({ sub: userId, email }, JWT_SECRET, { expiresIn: JWT_EXPIRES });
}

function authMiddleware(req, res, next) {
  const header = req.headers.authorization || "";
  const token = header.startsWith("Bearer ") ? header.slice(7) : null;
  if (!token) {
    return res.status(401).json({ error: "Unauthorized" });
  }
  try {
    const payload = jwt.verify(token, JWT_SECRET);
    req.user = { id: payload.sub, email: payload.email };
    next();
  } catch {
    return res.status(401).json({ error: "Invalid or expired token" });
  }
}

const app = express();
app.use(express.json({ limit: "1536kb" }));

function normalizeOrigin(o) {
  return String(o || "")
    .trim()
    .replace(/\/+$/, "");
}

const allowedOrigins = CORS_ORIGIN
  ? CORS_ORIGIN.split(",")
      .map((s) => normalizeOrigin(s))
      .filter(Boolean)
  : [];

const corsOptions = {
  origin(origin, cb) {
    // Non-browser clients (curl, server-to-server) often send no Origin.
    if (!origin) return cb(null, true);
    // If not configured, allow any origin (useful for demos).
    if (allowedOrigins.length === 0) return cb(null, true);
    const o = normalizeOrigin(origin);
    return cb(null, allowedOrigins.includes(o));
  },
  credentials: true,
};

app.use(cors(corsOptions));
// Preflight: be explicit so browsers don't fail OPTIONS.
app.options("*", cors(corsOptions));

app.get("/health", (_req, res) => {
  res.json({ ok: true });
});

app.post("/auth/register", async (req, res) => {
  const email = String(req.body?.email || "")
    .trim()
    .toLowerCase();
  const password = String(req.body?.password || "");

  if (!email || !email.includes("@")) {
    return res.status(400).json({ error: "Valid email required" });
  }
  if (password.length < 8) {
    return res.status(400).json({ error: "Password must be at least 8 characters" });
  }

  const id = crypto.randomUUID();
  const passwordHash = await bcrypt.hash(password, 12);

  try {
    await pool.query(
      "INSERT INTO users (id, email, password_hash) VALUES ($1, $2, $3)",
      [id, email, passwordHash],
    );
  } catch (e) {
    if (e.code === "23505") {
      return res.status(409).json({ error: "Email already registered" });
    }
    console.error(e);
    return res.status(500).json({ error: "Registration failed" });
  }

  const accessToken = signToken(id, email);
  return res.status(201).json({
    accessToken,
    user: { id, email },
  });
});

app.post("/auth/login", async (req, res) => {
  const email = String(req.body?.email || "")
    .trim()
    .toLowerCase();
  const password = String(req.body?.password || "");

  if (!email || !password) {
    return res.status(400).json({ error: "Email and password required" });
  }

  const { rows } = await pool.query(
    "SELECT id, email, password_hash FROM users WHERE email = $1",
    [email],
  );
  const row = rows[0];
  if (!row) {
    return res.status(401).json({ error: "Invalid email or password" });
  }

  const ok = await bcrypt.compare(password, row.password_hash);
  if (!ok) {
    return res.status(401).json({ error: "Invalid email or password" });
  }

  const accessToken = signToken(row.id, row.email);
  return res.json({
    accessToken,
    user: { id: row.id, email: row.email },
  });
});

app.get("/auth/me", authMiddleware, async (req, res) => {
  const { rows } = await pool.query("SELECT id, email, nickname, created_at FROM users WHERE id = $1", [
    req.user.id,
  ]);
  const row = rows[0];
  if (!row) {
    return res.status(401).json({ error: "User not found" });
  }
  return res.json({
    user: { id: row.id, email: row.email, nickname: row.nickname ?? "", createdAt: row.created_at },
  });
});

/// 클라이언트 로컬 상태(블록·집중 로그·레벨·목표 등) — 기기 간 동기화.
app.get("/sync/state", authMiddleware, async (req, res) => {
  const { rows } = await pool.query(
    "SELECT payload, updated_at FROM user_app_sync WHERE user_id = $1",
    [req.user.id],
  );
  const row = rows[0];
  if (!row) {
    return res.json({
      payload: {},
      updatedAt: null,
    });
  }
  return res.json({
    payload: row.payload ?? {},
    updatedAt: row.updated_at,
  });
});

const MAX_FOCUS_EVENTS = 500;

app.put("/sync/state", authMiddleware, async (req, res) => {
  const body = req.body;
  const payload = body && typeof body.payload === "object" && body.payload !== null ? body.payload : {};
  const planningBlocks = payload.planningBlocks;
  const focusEvents = payload.focusEvents;
  if (Array.isArray(focusEvents) && focusEvents.length > MAX_FOCUS_EVENTS) {
    return res.status(400).json({ error: `focusEvents must be at most ${MAX_FOCUS_EVENTS} items` });
  }
  if (planningBlocks != null && !Array.isArray(planningBlocks)) {
    return res.status(400).json({ error: "planningBlocks must be an array when present" });
  }

  try {
    await pool.query(
      `INSERT INTO user_app_sync (user_id, payload, updated_at)
       VALUES ($1, $2::jsonb, now())
       ON CONFLICT (user_id) DO UPDATE SET payload = EXCLUDED.payload, updated_at = now()`,
      [req.user.id, JSON.stringify(payload)],
    );
  } catch (e) {
    console.error("sync/state PUT error:", e);
    return res.status(500).json({ error: "Failed to save sync state" });
  }
  return res.json({ ok: true });
});

app.patch("/user/profile", authMiddleware, async (req, res) => {
  const nickname = String(req.body?.nickname ?? "").trim();
  if (nickname.length > 24) {
    return res.status(400).json({ error: "Nickname must be 24 characters or less" });
  }
  const { rows } = await pool.query(
    "UPDATE users SET nickname = $2 WHERE id = $1 RETURNING id, email, nickname, created_at",
    [req.user.id, nickname],
  );
  const row = rows[0];
  if (!row) return res.status(401).json({ error: "User not found" });
  return res.json({
    user: { id: row.id, email: row.email, nickname: row.nickname ?? "", createdAt: row.created_at },
  });
});

// --- Gemini (Google AI Studio) proxy: key stays on Render; app sends JWT only. ---
app.get("/ai/gemini/status", (_req, res) => {
  res.json({ configured: Boolean(GEMINI_API_KEY), model: GEMINI_MODEL });
});

app.post("/ai/gemini-json", authMiddleware, async (req, res) => {
  if (!GEMINI_API_KEY) {
    return res.status(503).json({ error: "GEMINI_API_KEY is not set on this server" });
  }
  const system = String(req.body?.system ?? "");
  const user = String(req.body?.user ?? "");
  if (!system.trim() || !user.trim()) {
    return res.status(400).json({ error: "body.system and body.user (non-empty strings) are required" });
  }
  try {
    const result = await geminiGenerateJson({
      apiKey: GEMINI_API_KEY,
      model: GEMINI_MODEL,
      system,
      user,
    });
    return res.json({ result });
  } catch (e) {
    console.error("Gemini JSON error:", e);
    return res.status(502).json({ error: String(e?.message || e) });
  }
});

registerMcpRoutes(app, {
  pool,
  authMiddleware,
  geminiApiKey: GEMINI_API_KEY,
  geminiModel: GEMINI_MODEL,
});

app.post("/ai/gemini-text", authMiddleware, async (req, res) => {
  if (!GEMINI_API_KEY) {
    return res.status(503).json({ error: "GEMINI_API_KEY is not set on this server" });
  }
  const system = String(req.body?.system ?? "");
  const user = String(req.body?.user ?? "");
  if (!system.trim() || !user.trim()) {
    return res.status(400).json({ error: "body.system and body.user (non-empty strings) are required" });
  }
  try {
    const text = await geminiGenerateText({
      apiKey: GEMINI_API_KEY,
      model: GEMINI_MODEL,
      system,
      user,
    });
    return res.json({ text });
  } catch (e) {
    console.error("Gemini text error:", e);
    return res.status(502).json({ error: String(e?.message || e) });
  }
});

app.use((_req, res) => {
  res.status(404).json({ error: "Not found" });
});

ensureSchema()
  .then(() => {
    app.listen(PORT, "0.0.0.0", () => {
      console.log(`FocusFlow API listening on ${PORT}`);
    });
  })
  .catch((err) => {
    console.error("Schema / DB error:", err);
    process.exit(1);
  });
