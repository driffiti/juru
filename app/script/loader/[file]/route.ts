import { NextRequest, NextResponse } from "next/server";
import { isRobloxClient } from "@/lib/roblox";
import { recordLoad } from "@/lib/stats";
import { buildBootstrap } from "@/lib/heartbeat";
import { generateNonce } from "@/lib/nonce";

export const revalidate = 0;

export async function GET(req: NextRequest, { params }: { params: { file: string } }) {
  const userAgent = req.headers.get("user-agent");

  if (!isRobloxClient(userAgent)) {
    return new NextResponse("Not found", { status: 404 });
  }

  if (params.file !== "juru.lua") {
    return new NextResponse("Not found", { status: 404 });
  }

  recordLoad().catch(() => {});

  // Generate a fresh nonce on every request. It's embedded as a Lua
  // variable and must be echoed back to /api/unlock. Valid for ~60s,
  // so a cached/replayed curl response stops working quickly.
  const nonce = await generateNonce();

  return new NextResponse(buildBootstrap(nonce), {
    status: 200,
    headers: {
      "Content-Type": "text/plain; charset=utf-8",
      "Cache-Control": "no-store",
    },
  });
}
