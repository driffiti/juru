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

  // Bind the nonce to the client IP so it can only be redeemed from the
  // same machine that fetched the loader.
  const ip = req.headers.get("cf-connecting-ip") ?? req.headers.get("x-real-ip") ?? req.headers.get("x-forwarded-for")?.split(",")[0]?.trim() ?? "unknown";
  const nonce = await generateNonce(ip);

  return new NextResponse(buildBootstrap(nonce), {
    status: 200,
    headers: {
      "Content-Type": "text/plain; charset=utf-8",
      "Cache-Control": "no-store",
    },
  });
}
