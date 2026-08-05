import { NextResponse } from "next/server";

// Ping endpoint is retired — execution is now reported via Discord webhook.
// Returns 200 silently so any old script versions don't throw errors.
export async function POST() {
  return NextResponse.json({ ok: true });
}
