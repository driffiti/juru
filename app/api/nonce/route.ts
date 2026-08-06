import { NextRequest, NextResponse } from "next/server";
import { isRobloxClient } from "@/lib/roblox";
import { generateNonce } from "@/lib/nonce";

export const revalidate = 0;

// Called by the in-game GUI right before the user submits their key,
// so the nonce is always fresh regardless of how long they took to type.
export async function GET(req: NextRequest) {
  if (!isRobloxClient(req.headers.get("user-agent"))) {
    return new NextResponse("Not found", { status: 404 });
  }
  const ip = req.headers.get("cf-connecting-ip") ??
    req.headers.get("x-real-ip") ??
    req.headers.get("x-forwarded-for")?.split(",")[0]?.trim() ?? "unknown";
  const nonce = await generateNonce(ip);
  return NextResponse.json({ nonce });
}
