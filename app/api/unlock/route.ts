import { NextRequest, NextResponse } from "next/server";
import { isRobloxClient } from "@/lib/roblox";
import { getSiteData } from "@/lib/db";
import { verifyKey } from "@/lib/keys";

export const revalidate = 0;

// This is the only place the real script content ever leaves the server.
// The loader (/script/loader/juru.lua) only ever serves the bootstrap —
// it calls here to actually fetch the runnable script, and only gets it
// back if no key is required, or a valid key + matching HWID is supplied.
export async function POST(req: NextRequest) {
  if (!isRobloxClient(req.headers.get("user-agent"))) {
    return NextResponse.json({ valid: false, reason: "Forbidden." }, { status: 403 });
  }

  let body: any;
  try {
    body = await req.json();
  } catch {
    return NextResponse.json({ valid: false, reason: "Bad request." }, { status: 400 });
  }

  let data;
  try {
    data = await getSiteData();
  } catch (e) {
    console.error("juru.lol /api/unlock getSiteData failed:", e);
    return NextResponse.json({ valid: false, reason: "juru.lol is having issues, try again shortly." });
  }

  if (data.status === "down") {
    return NextResponse.json({ valid: false, reason: "juru.lol is currently down." });
  }

  if (!data.require_key) {
    return NextResponse.json({ valid: true, script: data.script_content });
  }

  const key = typeof body.key === "string" ? body.key.trim().toUpperCase() : "";
  const hwid = typeof body.hwid === "string" && body.hwid ? body.hwid.slice(0, 128) : "unknown-hwid";

  if (!key) {
    return NextResponse.json({ valid: false, reason: "No key provided." });
  }

  try {
    const result = await verifyKey(key, hwid);
    if (!result.valid) {
      return NextResponse.json({ valid: false, reason: result.reason });
    }
  } catch (e) {
    console.error("juru.lol /api/unlock verifyKey failed:", e);
    return NextResponse.json({ valid: false, reason: "juru.lol is having issues, try again shortly." });
  }

  return NextResponse.json({ valid: true, script: data.script_content });
}
