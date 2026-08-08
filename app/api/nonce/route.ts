import { NextRequest, NextResponse } from "next/server";
import { generateNonce } from "@/lib/nonce";

export const revalidate = 0;

// No UA check here — mobile executors may strip custom headers so we
// can't rely on User-Agent. The nonce is useless without immediately
// pairing it with a valid key in /api/unlock, so there's no security
// gain from gating this endpoint.
export async function GET(req: NextRequest) {
  const nonce = await generateNonce();
  return NextResponse.json({ nonce });
}
