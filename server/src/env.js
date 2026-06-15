/** Strip quotes/whitespace from Render / .env values. */
export function env(name) {
  return String(process.env[name] ?? "")
    .trim()
    .replace(/^['"]|['"]$/g, "");
}

export function envBool(name) {
  return env(name).length > 0;
}
