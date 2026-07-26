import { NextRequest, NextResponse } from "next/server";
import { isRobloxClient } from "@/lib/roblox";
import { upsertSession } from "@/lib/stats";

export const revalidate = 0;

// Called from *inside* the loaded script, roughly every 30-60s, so the
// admin dashboard can show which servers currently have it running and
// let you jump straight into one. See the heartbeat snippet in /admin.
export async function POST(req: NextRequest) {
  if (!isRobloxClient(req.headers.get("user-agent"))) {
    return NextResponse.json({ error: "forbidden" }, { status: 403 });
  }

  let body: any;
  try {
    body = await req.json();
  } catch {
    return NextResponse.json({ error: "bad json" }, { status: 400 });
  }

  const jobId = typeof body.jobId === "string" ? body.jobId.slice(0, 64) : null;
  const placeId =
    typeof body.placeId === "string" || typeof body.placeId === "number"
      ? String(body.placeId).slice(0, 32)
      : null;
  const playerCount = Number.isFinite(body.playerCount)
    ? Math.max(0, Math.min(1000, Math.floor(body.playerCount)))
    : 0;

  if (!jobId || !placeId) {
    return NextResponse.json({ error: "missing jobId/placeId" }, { status: 400 });
  }

  await upsertSession(jobId, placeId, playerCount);
  return NextResponse.json({ ok: true });
}
