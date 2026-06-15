import { getToken, upsertToken } from "./oauth-store.js";

const NOTION_AUTH = "https://api.notion.com/v1/oauth/authorize";
const NOTION_TOKEN = "https://api.notion.com/v1/oauth/token";
const NOTION_VERSION = "2022-06-28";

function isConfigured() {
  return Boolean(process.env.NOTION_CLIENT_ID && process.env.NOTION_CLIENT_SECRET);
}

function redirectUri() {
  return process.env.NOTION_REDIRECT_URI || "";
}

export function notionMcpConfigured() {
  return isConfigured() && Boolean(redirectUri());
}

export function buildNotionAuthUrl(state) {
  const params = new URLSearchParams({
    client_id: process.env.NOTION_CLIENT_ID,
    redirect_uri: redirectUri(),
    response_type: "code",
    owner: "user",
    state,
  });
  return `${NOTION_AUTH}?${params}`;
}

async function exchangeCode(code) {
  const basic = Buffer.from(
    `${process.env.NOTION_CLIENT_ID}:${process.env.NOTION_CLIENT_SECRET}`,
  ).toString("base64");

  const res = await fetch(NOTION_TOKEN, {
    method: "POST",
    headers: {
      Authorization: `Basic ${basic}`,
      "Content-Type": "application/json",
    },
    body: JSON.stringify({
      grant_type: "authorization_code",
      code,
      redirect_uri: redirectUri(),
    }),
  });
  const raw = await res.text();
  if (!res.ok) throw new Error(`Notion token exchange failed: ${raw.slice(0, 400)}`);
  return JSON.parse(raw);
}

export async function handleNotionCallback(pool, code, userId) {
  const data = await exchangeCode(code);
  await upsertToken(pool, {
    userId,
    provider: "notion",
    accessToken: data.access_token,
    refreshToken: null,
    expiresAt: null,
    metadata: {
      workspaceId: data.workspace_id ?? null,
      workspaceName: data.workspace_name ?? null,
      botId: data.bot_id ?? null,
    },
  });
}

async function notionFetch(accessToken, path, body) {
  const res = await fetch(`https://api.notion.com/v1${path}`, {
    method: body ? "POST" : "GET",
    headers: {
      Authorization: `Bearer ${accessToken}`,
      "Notion-Version": NOTION_VERSION,
      "Content-Type": "application/json",
    },
    body: body ? JSON.stringify(body) : undefined,
  });
  const raw = await res.text();
  if (!res.ok) {
    console.error("Notion API error:", path, raw.slice(0, 400));
    return null;
  }
  return JSON.parse(raw);
}

function extractTitle(props) {
  if (!props || typeof props !== "object") return "";
  for (const key of Object.keys(props)) {
    const p = props[key];
    if (p?.type === "title" && Array.isArray(p.title)) {
      return p.title.map((t) => t.plain_text || "").join("").trim();
    }
  }
  return "";
}

function isDoneStatus(props) {
  if (!props || typeof props !== "object") return false;
  for (const key of Object.keys(props)) {
    const p = props[key];
    if (p?.type === "checkbox" && p.checkbox === true) return true;
    if (p?.type === "status") {
      const name = String(p.status?.name || "").toLowerCase();
      if (name.includes("done") || name.includes("완료")) return true;
    }
  }
  return false;
}

export async function fetchNotionItems(pool, userId) {
  const row = await getToken(pool, userId, "notion");
  if (!row?.access_token) return [];

  const items = [];
  const search = await notionFetch(row.access_token, "/search", {
    filter: { value: "page", property: "object" },
    page_size: 25,
    sort: { direction: "descending", timestamp: "last_edited_time" },
  });
  if (!search?.results) return [];

  for (const page of search.results) {
    if (page.object !== "page" || page.archived) continue;
    const title = extractTitle(page.properties);
    if (!title) continue;
    if (isDoneStatus(page.properties)) continue;

    items.push({
      source: "notion",
      externalId: page.id ?? "",
      title,
      description: "",
      dueAt: page.last_edited_time ?? null,
      kind: "task",
    });
    if (items.length >= 20) break;
  }

  return items;
}
