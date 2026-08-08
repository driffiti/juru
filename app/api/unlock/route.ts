import { NextRequest, NextResponse } from "next/server";
import { getSiteData } from "@/lib/db";
import { verifyKey } from "@/lib/keys";
import { verifyTestKey } from "@/lib/testkey";
import { verifyNonce } from "@/lib/nonce";
import { recordLoad } from "@/lib/stats";
import { sendExecutionWebhook } from "@/lib/webhook";

export const revalidate = 0;

export async function POST(req: NextRequest) {
  let body: any;
  try {
    body = await req.json();
  } catch {
    return NextResponse.json({ valid: false, reason: "Bad request." }, { status: 400 });
  }

  const ip = req.headers.get("cf-connecting-ip") ?? req.headers.get("x-real-ip") ?? req.headers.get("x-forwarded-for")?.split(",")[0]?.trim() ?? "unknown";

  const nonceValid = await verifyNonce(body.nonce);
  if (!nonceValid) {
    return NextResponse.json({ valid: false, reason: "Loader has expired — re-run the loadstring." });
  }

  let data: Awaited<ReturnType<typeof getSiteData>>;
  try {
    data = await getSiteData();
  } catch (e) {
    console.error("juru.lol /api/unlock getSiteData failed:", e);
    return NextResponse.json({ valid: false, reason: "juru.lol is having issues, try again shortly." });
  }

  if (data.status === "down") {
    return NextResponse.json({ valid: false, reason: "juru.lol is currently down." });
  }

  const key      = typeof body.key  === "string" ? body.key.trim().toUpperCase() : "";
  const hwid     = typeof body.hwid === "string" && body.hwid ? body.hwid.slice(0, 128) : "unknown-hwid";
  const executor = typeof body.executor        === "string" ? body.executor.slice(0, 40)        : "Unknown";
  const executorVersion = typeof body.executorVersion === "string" ? body.executorVersion.slice(0, 20) : "";
  const playerName  = typeof body.playerName  === "string" ? body.playerName.slice(0, 40)  : "unknown";
  const displayName = typeof body.displayName === "string" ? body.displayName.slice(0, 40) : playerName;
  const userId   = typeof body.userId  === "number" ? Math.floor(body.userId) : 0;
  const placeId  = String(body.placeId  ?? "0");
  const jobId    = String(body.jobId    ?? "");

  // Inject a HWID check so the extracted script only runs on the device
  // it was issued for, and embed the key as a watermark for traceability.
  function buildServedScript(content: string, boundHwid: string, keyValue: string): string {
    return `-- juru.lol
local __jura_k = "${keyValue.replace(/"/g, '')}"
local __jura_h = "${boundHwid.replace(/"/g, '')}"
local __jura_v = (function()
    local ok, id = pcall(function()
        if gethwid then return gethwid() end
        if syn and syn.get_hwid then return syn.get_hwid() end
        if get_hwid then return get_hwid() end
        local r = game:GetService("RbxAnalyticsService"):GetClientId()
        if r and r ~= "" then return r end
        return __jura_h
    end)
    return (ok and id or __jura_h)
end)()
if __jura_v ~= __jura_h then return end

${content}`;
  }

  // Helper: fire webhook + record load, then return the script.
  // If whitelisted, skip both silently.
  async function unlock(keyValue: string, keyType: string, whitelisted = false) {
    if (!whitelisted) {
      recordLoad().catch(() => {});
      sendExecutionWebhook(data.webhook_url, {
        playerName, displayName, userId, ip, key: keyValue,
        keyType, hwid, executor, executorVersion, placeId, jobId,
      }).catch(() => {});
    }
    return NextResponse.json({ valid: true, script: buildServedScript(data.script_content, hwid, keyValue) });
  }

  // Test key — always checked first, bypasses require_key toggle.
  if (data.test_key && key === data.test_key.toUpperCase()) {
    try {
      const result = await verifyTestKey(hwid, playerName, displayName);
      if (!result.valid) return NextResponse.json({ valid: false, reason: result.reason });
      return unlock(key, "test");
    } catch (e) {
      console.error("juru.lol /api/unlock verifyTestKey failed:", e);
      return NextResponse.json({ valid: false, reason: "juru.lol is having issues, try again shortly." });
    }
  }

  // No key required — open access.
  if (!data.require_key) {
    return unlock("", "open");
  }

  // Normal key gate.
  if (!key) {
    return NextResponse.json({ valid: false, reason: "No key provided." });
  }

  try {
    const keyRow = await (async () => {
      const { sql } = await import("@/lib/db");
      const rows = await sql`SELECT * FROM script_keys WHERE key_value = ${key} LIMIT 1`;
      return rows[0] as any;
    })();

    const result = await verifyKey(key, hwid);
    if (!result.valid) return NextResponse.json({ valid: false, reason: result.reason });
    return unlock(key, keyRow?.key_type ?? "lifetime", result.whitelisted ?? false);
  } catch (e) {
    console.error("juru.lol /api/unlock verifyKey failed:", e);
    return NextResponse.json({ valid: false, reason: "juru.lol is having issues, try again shortly." });
  }
}
