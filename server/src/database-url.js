import { env } from "./env.js";

/**
 * Render Postgres URL 정규화.
 * - Internal URL: 호스트가 `dpg-xxxx-a`만 있어도 Render 네트워크 안에서는 정상입니다.
 * - External URL이 필요하면 DATABASE_HOST_SUFFIX=oregon-postgres.render.com 등으로 확장.
 */
export function resolveDatabaseUrl() {
  let url = env("DATABASE_URL");
  if (!url) {
    return { url: "", internal: false };
  }

  let internal = false;
  try {
    const parsed = new URL(url.replace(/^postgresql:\/\//, "http://"));
    const host = parsed.hostname;

    if (host.startsWith("dpg-") && !host.includes(".")) {
      const suffix = env("DATABASE_HOST_SUFFIX");
      if (suffix) {
        const fullHost = `${host}.${suffix}`;
        url = url.replace(host, fullHost);
        console.log(`[DB] host expanded with DATABASE_HOST_SUFFIX → ${fullHost}`);
      } else {
        internal = true;
        console.log(`[DB] Render internal Postgres host: ${host}`);
      }
    }
  } catch (e) {
    console.error("Invalid DATABASE_URL format:", e.message);
    process.exit(1);
  }

  return { url, internal };
}
