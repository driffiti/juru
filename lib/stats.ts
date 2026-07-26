import { sql } from "@/lib/db";

// A "load" = one fetch of /script/loader/juru.lua. Recorded with no
// place/job info, since that's not known until the script itself runs.
export async function recordLoad() {
  await sql`INSERT INTO loads (loaded_at) VALUES (now())`;
}

// A "session" = one Roblox server currently running the script, kept
// alive by periodic heartbeat pings sent from inside the script itself.
// Upserting on job_id means repeated pings from the same server just
// bump last_seen instead of creating duplicates.
export async function upsertSession(jobId: string, placeId: string, playerCount: number) {
  await sql`
    INSERT INTO sessions (job_id, place_id, player_count, first_seen, last_seen)
    VALUES (${jobId}, ${placeId}, ${playerCount}, now(), now())
    ON CONFLICT (job_id) DO UPDATE SET
      place_id = EXCLUDED.place_id,
      player_count = EXCLUDED.player_count,
      last_seen = now()
  `;
}

export type ActiveSession = {
  job_id: string;
  place_id: string;
  player_count: number;
  first_seen: string;
  last_seen: string;
};

export type Stats = {
  total_loads: number;
  loads_last_24h: number;
  active_servers: number;
  active_players: number;
  sessions: ActiveSession[];
};

// Servers are considered "active" if we've heard from them in the last
// 90 seconds. The script should ping roughly every 30-60s (see the
// heartbeat snippet on the admin dashboard), so a server that stops
// responding drops out of the list within about a minute and a half.

export async function getStats(): Promise<Stats> {
  const [totalLoadsRows, loadsTodayRows, activeRows, sessionRows] = await Promise.all([
    sql`SELECT COUNT(*)::int AS count FROM loads`,
    sql`SELECT COUNT(*)::int AS count FROM loads WHERE loaded_at > now() - interval '24 hours'`,
    sql`
      SELECT COUNT(*)::int AS servers, COALESCE(SUM(player_count), 0)::int AS players
      FROM sessions
      WHERE last_seen > now() - interval '90 seconds'
    `,
    sql`
      SELECT job_id, place_id, player_count, first_seen, last_seen
      FROM sessions
      WHERE last_seen > now() - interval '90 seconds'
      ORDER BY last_seen DESC
      LIMIT 100
    `,
  ]);

  return {
    total_loads: totalLoadsRows[0]?.count ?? 0,
    loads_last_24h: loadsTodayRows[0]?.count ?? 0,
    active_servers: activeRows[0]?.servers ?? 0,
    active_players: activeRows[0]?.players ?? 0,
    sessions: sessionRows as ActiveSession[],
  };
}
