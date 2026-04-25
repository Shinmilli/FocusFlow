/**
 * Google AI Studio (Gemini) — server-side only. Key stays on Render, never in the Flutter web bundle.
 * Docs: https://ai.google.dev/gemini-api/docs
 */

/** Override with env `GEMINI_MODEL` (e.g. `gemini-2.0-flash` on AI Studio). */
const DEFAULT_MODEL = "gemini-1.5-flash";

function extractText(data) {
  const parts = data?.candidates?.[0]?.content?.parts;
  if (!Array.isArray(parts)) return "";
  return parts.map((p) => (typeof p?.text === "string" ? p.text : "")).join("");
}

/**
 * @param {{ apiKey: string; model?: string; system: string; user: string }} opts
 * @returns {Promise<unknown>} Parsed JSON from model output
 */
export async function geminiGenerateJson(opts) {
  const { apiKey, system, user } = opts;
  const model = opts.model || DEFAULT_MODEL;
  const url = `https://generativelanguage.googleapis.com/v1beta/models/${encodeURIComponent(
    model,
  )}:generateContent?key=${encodeURIComponent(apiKey)}`;

  const res = await fetch(url, {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify({
      systemInstruction: { parts: [{ text: system }] },
      contents: [{ role: "user", parts: [{ text: user }] }],
      generationConfig: {
        temperature: 0.2,
        responseMimeType: "application/json",
      },
    }),
  });

  const raw = await res.text();
  if (!res.ok) {
    throw new Error(`Gemini HTTP ${res.status}: ${raw.slice(0, 800)}`);
  }

  let data;
  try {
    data = JSON.parse(raw);
  } catch {
    throw new Error("Gemini returned non-JSON envelope");
  }

  const text = extractText(data).trim();
  if (!text) {
    throw new Error("Empty Gemini text (check finishReason / safety)");
  }

  try {
    return JSON.parse(text);
  } catch {
    throw new Error(`Model output was not valid JSON: ${text.slice(0, 400)}`);
  }
}

/**
 * Plain text (e.g. short consulting paragraph).
 * @param {{ apiKey: string; model?: string; system: string; user: string }} opts
 */
export async function geminiGenerateText(opts) {
  const { apiKey, system, user } = opts;
  const model = opts.model || DEFAULT_MODEL;
  const url = `https://generativelanguage.googleapis.com/v1beta/models/${encodeURIComponent(
    model,
  )}:generateContent?key=${encodeURIComponent(apiKey)}`;

  const res = await fetch(url, {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify({
      systemInstruction: { parts: [{ text: system }] },
      contents: [{ role: "user", parts: [{ text: user }] }],
      generationConfig: {
        temperature: 0.3,
      },
    }),
  });

  const raw = await res.text();
  if (!res.ok) {
    throw new Error(`Gemini HTTP ${res.status}: ${raw.slice(0, 800)}`);
  }

  const data = JSON.parse(raw);
  const text = extractText(data).trim();
  if (!text) {
    throw new Error("Empty Gemini text");
  }
  return text;
}
