import { NextRequest, NextResponse } from "next/server";
import { isRobloxClient } from "@/lib/roblox";
import { recordLoad } from "@/lib/stats";
import { BOOTSTRAP_LUA } from "@/lib/heartbeat";

export const revalidate = 0;

export async function GET(req: NextRequest, { params }: { params: { file: string } }) {
  const userAgent = req.headers.get("user-agent");

  if (!isRobloxClient(userAgent)) {
    // Don't reveal anything useful to a browser poking at the URL directly.
    return new NextResponse("Not found", { status: 404 });
  }

  if (params.file !== "juru.lua") {
    return new NextResponse("Not found", { status: 404 });
  }

  // Fire-and-forget: log the load for stats without slowing the response.
  recordLoad().catch(() => {});

  // This never contains the actual script — just the bootstrap that
  // pings, detects the executor, and calls /api/unlock to fetch the
  // real script (which only comes back if no key is required, or a
  // valid key/HWID pair is supplied). See lib/heartbeat.ts.
  return new NextResponse(BOOTSTRAP_LUA, {
    status: 200,
    headers: {
      "Content-Type": "text/plain; charset=utf-8",
      "Cache-Control": "no-store",
    },
  });
}
