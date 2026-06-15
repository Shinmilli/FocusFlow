import { getToken, upsertToken } from "./oauth-store.js";

const GOOGLE_AUTH = "https://accounts.google.com/o/oauth2/v2/auth";
const GOOGLE_TOKEN = "https://oauth2.googleapis.com/token";
const CALENDAR_SCOPE = "https://www.googleapis.com/auth/calendar.readonly";

function isConfigured() {
  return Boolean(process.env.GOOGLE_CLIENT_ID && process.env.GOOGLE_CLIENT_SECRET);
}

function redirectUri() {
  return process.env.GOOGLE_REDIRECT_URI || "";
}

export function googleMcpConfigured() {
  return isConfigured() && Boolean(redirectUri());
}

export function buildGoogleAuthUrl(state) {
  const params = new URLSearchParams({
    client_id: process.env.GOOGLE_CLIENT_ID,
    redirect_uri: redirectUri(),
    response_type: "code",
    scope: CALENDAR_SCOPE,
    access_type: "offline",
    prompt: "consent",
    state,
  });
  return `${GOOGLE_AUTH}?${params}`;
}

async function exchangeCode(code) {
  const res = await fetch(GOOGLE_TOKEN, {
    method: "POST",
    headers: { "Content-Type": "application/x-www-form-urlencoded" },
    body: new URLSearchParams({
      code,
      client_id: process.env.GOOGLE_CLIENT_ID,
      client_secret: process.env.GOOGLE_CLIENT_SECRET,
      redirect_uri: redirectUri(),
      grant_type: "authorization_code",
    }),
  });
  const raw = await res.text();
  if (!res.ok) throw new Error(`Google token exchange failed: ${raw.slice(0, 400)}`);
  return JSON.parse(raw);
}

async function refreshAccessToken(refreshToken) {
  const res = await fetch(GOOGLE_TOKEN, {
    method: "POST",
    headers: { "Content-Type": "application/x-www-form-urlencoded" },
    body: new URLSearchParams({
      client_id: process.env.GOOGLE_CLIENT_ID,
      client_secret: process.env.GOOGLE_CLIENT_SECRET,
      refresh_token: refreshToken,
      grant_type: "refresh_token",
    }),
  });
  const raw = await res.text();
  if (!res.ok) throw new Error(`Google token refresh failed: ${raw.slice(0, 400)}`);
  return JSON.parse(raw);
}

export async function handleGoogleCallback(pool, code, userId) {
  const data = await exchangeCode(code);
  const expiresAt =
    data.expires_in != null
      ? new Date(Date.now() + Number(data.expires_in) * 1000).toISOString()
      : null;
  await upsertToken(pool, {
    userId,
    provider: "google",
    accessToken: data.access_token,
    refreshToken: data.refresh_token ?? null,
    expiresAt,
    metadata: { scope: CALENDAR_SCOPE },
  });
}

async function ensureAccessToken(pool, userId) {
  const row = await getToken(pool, userId, "google");
  if (!row) return null;

  const expiresAt = row.expires_at ? new Date(row.expires_at).getTime() : null;
  const needsRefresh = expiresAt != null && expiresAt < Date.now() + 60_000;

  if (!needsRefresh) return row.access_token;
  if (!row.refresh_token) return row.access_token;

  const data = await refreshAccessToken(row.refresh_token);
  const newExpires =
    data.expires_in != null
      ? new Date(Date.now() + Number(data.expires_in) * 1000).toISOString()
      : row.expires_at;
  await upsertToken(pool, {
    userId,
    provider: "google",
    accessToken: data.access_token,
    refreshToken: row.refresh_token,
    expiresAt: newExpires,
    metadata: row.metadata ?? {},
  });
  return data.access_token;
}

function dayBounds() {
  const start = new Date();
  start.setHours(0, 0, 0, 0);
  const end = new Date(start);
  end.setDate(end.getDate() + 2);
  return { timeMin: start.toISOString(), timeMax: end.toISOString() };
}

export async function fetchGoogleCalendarItems(pool, userId) {
  const accessToken = await ensureAccessToken(pool, userId);
  if (!accessToken) return [];

  const { timeMin, timeMax } = dayBounds();
  const params = new URLSearchParams({
    timeMin,
    timeMax,
    singleEvents: "true",
    orderBy: "startTime",
    maxResults: "30",
  });

  const res = await fetch(
    `https://www.googleapis.com/calendar/v3/calendars/primary/events?${params}`,
    { headers: { Authorization: `Bearer ${accessToken}` } },
  );
  const raw = await res.text();
  if (!res.ok) {
    console.error("Google Calendar fetch error:", raw.slice(0, 400));
    return [];
  }

  const data = JSON.parse(raw);
  const events = Array.isArray(data.items) ? data.items : [];

  return events
    .filter((e) => e.status !== "cancelled")
    .map((e) => {
      const start = e.start?.dateTime || e.start?.date || null;
      return {
        source: "google_calendar",
        externalId: e.id ?? "",
        title: String(e.summary || "(제목 없음)").trim(),
        description: String(e.description || "").slice(0, 500),
        dueAt: start,
        kind: "event",
      };
    });
}
