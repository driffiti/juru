import { NextResponse } from "next/server";

// Change this URL whenever your Discord invite changes — no need to
// update anything you've shared, since juru.lol/discord stays the same.
const DISCORD_INVITE = "https://discord.gg/vd5smhB9cF";

export function GET() {
  return NextResponse.redirect(DISCORD_INVITE, { status: 307 });
}
