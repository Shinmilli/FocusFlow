/**
 * Per-user OAuth tokens for MCP providers (Google Calendar, Notion).
 */

export async function ensureMcpSchema(pool) {
  await pool.query(`
    CREATE TABLE IF NOT EXISTS mcp_oauth_tokens (
      user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
      provider TEXT NOT NULL,
      access_token TEXT NOT NULL,
      refresh_token TEXT,
      expires_at TIMESTAMPTZ,
      metadata JSONB NOT NULL DEFAULT '{}'::jsonb,
      updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
      PRIMARY KEY (user_id, provider)
    );
  `);
  await pool.query(`
    CREATE TABLE IF NOT EXISTS mcp_oauth_states (
      state TEXT PRIMARY KEY,
      user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
      provider TEXT NOT NULL,
      created_at TIMESTAMPTZ NOT NULL DEFAULT now()
    );
  `);
}

export async function saveOAuthState(pool, { state, userId, provider }) {
  await pool.query(
    `INSERT INTO mcp_oauth_states (state, user_id, provider) VALUES ($1, $2, $3)`,
    [state, userId, provider],
  );
}

export async function consumeOAuthState(pool, state) {
  const { rows } = await pool.query(
    `DELETE FROM mcp_oauth_states WHERE state = $1 RETURNING user_id, provider`,
    [state],
  );
  return rows[0] ?? null;
}

export async function upsertToken(pool, { userId, provider, accessToken, refreshToken, expiresAt, metadata }) {
  await pool.query(
    `INSERT INTO mcp_oauth_tokens (user_id, provider, access_token, refresh_token, expires_at, metadata, updated_at)
     VALUES ($1, $2, $3, $4, $5, $6::jsonb, now())
     ON CONFLICT (user_id, provider) DO UPDATE SET
       access_token = EXCLUDED.access_token,
       refresh_token = COALESCE(EXCLUDED.refresh_token, mcp_oauth_tokens.refresh_token),
       expires_at = EXCLUDED.expires_at,
       metadata = EXCLUDED.metadata,
       updated_at = now()`,
    [
      userId,
      provider,
      accessToken,
      refreshToken ?? null,
      expiresAt ?? null,
      JSON.stringify(metadata ?? {}),
    ],
  );
}

export async function getToken(pool, userId, provider) {
  const { rows } = await pool.query(
    `SELECT access_token, refresh_token, expires_at, metadata FROM mcp_oauth_tokens
     WHERE user_id = $1 AND provider = $2`,
    [userId, provider],
  );
  return rows[0] ?? null;
}

export async function deleteToken(pool, userId, provider) {
  await pool.query(`DELETE FROM mcp_oauth_tokens WHERE user_id = $1 AND provider = $2`, [
    userId,
    provider,
  ]);
}

export async function listConnectedProviders(pool, userId) {
  const { rows } = await pool.query(
    `SELECT provider, updated_at FROM mcp_oauth_tokens WHERE user_id = $1`,
    [userId],
  );
  return rows;
}
