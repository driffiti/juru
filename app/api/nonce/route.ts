import { NextRequest, NextResponse } from "next/server";
import { isRobloxClient } from "@/lib/roblox";
import { generateNonce } from "@/lib/nonce";

export const revalidate = 0;

export async function GET(req: NextRequest) {
  if (!isRobloxClient(req.headers.get("user-agent"))) {
    return new NextResponse("Not found", { status: 404 });
  }
  const nonce = await generateNonce();
  return NextResponse.json({ nonce });
}
