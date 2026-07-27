import { sql } from "@/lib/db";

// A "load" = one fetch of /script/loader/juru.lua. Recorded with no
// place/job info, since that's not known until the script itself runs.
export async function recordLoad() {
  await sql`INSERT INTO loads (loaded_at) VALUES (now())`;
}

// A "session" = one player currently running the script in one server,
// kept alive by periodic heartbeat pings sent from inside the script
// itself. Keyed on (job_id, user_id) so multiple players in the same
// server each get their own row instead of overwriting each other.
export async function upsertSession(
  jobId: string,
  placeId: string,
  userId: number,
  playerName: string,
  displayName: string,
  playerCount: number,
  executor: string,
  executorVersion: string
) {
  await sql`
    INSERT INTO sessions (job_id, place_id, user_id, player_name, display_name, player_count, executor, executor_version, first_seen, last_seen)
    VALUES (${jobId}, ${placeId}, ${userId}, ${playerName}, ${displayName}, ${playerCount}, ${executor}, ${executorVersion}, now(), now())
    ON CONFLICT (job_id, user_id) DO UPDATE SET
      place_id = EXCLUDED.place_id,
      player_name = EXCLUDED.player_name,
      display_name = EXCLUDED.display_name,
      player_count = EXCLUDED.player_count,
      executor = EXCLUDED.executor,
      executor_version = EXCLUDED.executor_version,
      last_seen = now()
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

// Servers/players are considered "active" if we've heard from them in the
// last 60 seconds. The script pings roughly every 45s (baked into every
// served response, see lib/heartbeat.ts), so a player who leaves or a
// server that dies drops out of the list within about 15-60s of their
// last ping — keep this above the 45s ping interval or things will
// flicker in and out of "active" between pings.

export async function getStats(): Promise<Stats> {
  const [totalLoadsRows, loadsTodayRows, activeRows, sessionRows] = await Promise.all([
    sql`SELECT COUNT(*)::int AS count FROM loads`,
    sql`SELECT COUNT(*)::int AS count FROM loads WHERE loaded_at > now() - interval '24 hours'`,
    sql`
      SELECT COUNT(DISTINCT job_id)::int AS servers, COUNT(*)::int AS scripters
      FROM sessions
      WHERE last_seen > now() - interval '60 seconds'
    `,
    sql`
      SELECT job_id, place_id, user_id, player_name, display_name, player_count, executor, executor_version, first_seen, last_seen
      FROM sessions
      WHERE last_seen > now() - interval '60 seconds'
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
