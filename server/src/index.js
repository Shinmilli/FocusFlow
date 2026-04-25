import "dotenv/config";
import crypto from "node:crypto";
import express from "express";
import cors from "cors";
import bcrypt from "bcryptjs";
import jwt from "jsonwebtoken";
import pg from "pg";

import { geminiGenerateJson, geminiGenerateText } from "./gemini.js";

const { Pool } = pg;

const PORT = Number(process.env.PORT) || 8787;
const DATABASE_URL = process.env.DATABASE_URL;
const JWT_SECRET = process.env.JWT_SECRET;
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
app.use(express.json({ limit: "256kb" }));

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
