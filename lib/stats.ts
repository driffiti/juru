import { sql } from "@/lib/db";

// Only tracks total load counts now — no more session/heartbeat pinging.
export async function recordLoad() {
  await sql`INSERT INTO loads (loaded_at) VALUES (now())`;
}

export type Stats = {
  total_loads: number;
  loads_last_24h: number;
};

export async function getStats(): Promise<Stats> {
  const [total, today] = await Promise.all([
    sql`SELECT COUNT(*)::int AS count FROM loads`,
    sql`SELECT COUNT(*)::int AS count FROM loads WHERE loaded_at > now() - interval '24 hours'`,
  ]);
  return {
    total_loads: total[0]?.count ?? 0,
    loads_last_24h: today[0]?.count ?? 0,
  };
}
