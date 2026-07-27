import { NextRequest, NextResponse } from "next/server";
import { isRobloxClient } from "@/lib/roblox";
import { getSiteData } from "@/lib/db";
import { verifyKey } from "@/lib/keys";
import { verifyTestKey } from "@/lib/testkey";

export const revalidate = 0;

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

  const key = typeof body.key === "string" ? body.key.trim().toUpperCase() : "";
  const hwid = typeof body.hwid === "string" && body.hwid ? body.hwid.slice(0, 128) : "unknown-hwid";

  // Test key path — checked first, before the normal require_key gate.
  // The test key works regardless of whether the key toggle is on or off.
  if (data.test_key && key === data.test_key.toUpperCase()) {
    try {
      const playerName = typeof body.playerName === "string" ? body.playerName.slice(0, 40) : "unknown";
      const displayName = typeof body.displayName === "string" ? body.displayName.slice(0, 40) : playerName;
      const result = await verifyTestKey(hwid, playerName, displayName);
      if (!result.valid) {
        return NextResponse.json({ valid: false, reason: result.reason });
      }
      return NextResponse.json({ valid: true, script: data.script_content });
    } catch (e) {
      console.error("juru.lol /api/unlock verifyTestKey failed:", e);
      return NextResponse.json({ valid: false, reason: "juru.lol is having issues, try again shortly." });
    }
  }

  // Normal key gate.
  if (!data.require_key) {
    return NextResponse.json({ valid: true, script: data.script_content });
  }

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
