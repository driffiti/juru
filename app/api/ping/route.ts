import { NextRequest, NextResponse } from "next/server";
import { isRobloxClient } from "@/lib/roblox";
import { upsertSession } from "@/lib/stats";

export const revalidate = 0;

// Called from *inside* the loaded script, roughly every 45s, so the
// admin dashboard can show which servers currently have it running,
// who's running it in each one, and let you jump straight into one.
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
  const userId =
    typeof body.userId === "number" && Number.isFinite(body.userId)
      ? Math.floor(body.userId)
      : null;
  const playerName =
    typeof body.playerName === "string" ? body.playerName.slice(0, 40) : "unknown";
  const displayName =
    typeof body.displayName === "string" ? body.displayName.slice(0, 40) : playerName;
  const playerCount = Number.isFinite(body.playerCount)
    ? Math.max(0, Math.min(1000, Math.floor(body.playerCount)))
    : 0;

  if (!jobId || !placeId || userId === null) {
    return NextResponse.json({ error: "missing jobId/placeId/userId" }, { status: 400 });
  }

  await upsertSession(jobId, placeId, userId, playerName, displayName, playerCount);
  return NextResponse.json({ ok: true });
}
