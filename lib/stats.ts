import { sql } from "@/lib/db";

export async function recordLoad() {
  await sql`INSERT INTO loads (loaded_at) VALUES (now())`;
}

export async function upsertSession(
  jobId: string,
  placeId: string,
  userId: number,
  playerName: string,
  displayName: string,
  playerCount: number,
  executor: string,
  executorVersion: string,
  keyUsed: string
) {
  await sql`
    INSERT INTO sessions (job_id, place_id, user_id, player_name, display_name, player_count, executor, executor_version, key_used, first_seen, last_seen)
    VALUES (${jobId}, ${placeId}, ${userId}, ${playerName}, ${displayName}, ${playerCount}, ${executor}, ${executorVersion}, ${keyUsed}, now(), now())
    ON CONFLICT (job_id, user_id) DO UPDATE SET
      place_id = EXCLUDED.place_id,
      player_name = EXCLUDED.player_name,
      display_name = EXCLUDED.display_name,
      player_count = EXCLUDED.player_count,
      executor = EXCLUDED.executor,
      executor_version = EXCLUDED.executor_version,
      key_used = EXCLUDED.key_used,
      last_seen = now()
  `;
}

// Returns whether a kick was pending, and clears it atomically.
export async function checkAndClearKick(jobId: string, userId: number): Promise<boolean> {
  const rows = await sql`
    UPDATE sessions
    SET kick_requested = false
    WHERE job_id = ${jobId} AND user_id = ${userId} AND kick_requested = true
    RETURNING job_id
  `;
  return rows.length > 0;
}

export async function requestKick(jobId: string, userId: number) {
  await sql`
    UPDATE sessions SET kick_requested = true
    WHERE job_id = ${jobId} AND user_id = ${userId}
  `;
}

export type ActiveSession = {
  job_id: string;
  place_id: string;
  user_id: number;
  player_name: string;
  display_name: string;
  player_count: number;
  executor: string;
  executor_version: string;
  key_used: string;
  kick_requested: boolean;
  first_seen: string;
  last_seen: string;
};

export type Stats = {
  total_loads: number;
  loads_last_24h: number;
  active_servers: number;
  active_scripters: number;
  sessions: ActiveSession[];
};

export async function getStats(): Promise<Stats> {
  const [totalLoadsRows, loadsTodayRows, activeRows, sessionRows] = await Promise.all([
    sql`SELECT COUNT(*)::int AS count FROM loads`,
    sql`SELECT COUNT(*)::int AS count FROM loads WHERE loaded_at > now() - interval '24 hours'`,
    sql`
      SELECT COUNT(DISTINCT job_id)::int AS servers, COUNT(*)::int AS scripters
      FROM sessions
      WHERE last_seen > now() - interval '45 seconds'
    `,
    sql`
      SELECT job_id, place_id, user_id, player_name, display_name, player_count, executor, executor_version, key_used, kick_requested, first_seen, last_seen
      FROM sessions
      WHERE last_seen > now() - interval '45 seconds'
      ORDER BY last_seen DESC
      LIMIT 200
    `,
  ]);

  return {
    total_loads: totalLoadsRows[0]?.count ?? 0,
    loads_last_24h: loadsTodayRows[0]?.count ?? 0,
    active_servers: activeRows[0]?.servers ?? 0,
    active_scripters: activeRows[0]?.scripters ?? 0,
    sessions: sessionRows as ActiveSession[],
  };
}
