import { NextRequest, NextResponse } from "next/server";
import { verifySessionToken, SESSION_COOKIE_NAME } from "@/lib/auth";
import { getSiteData, updateSiteData } from "@/lib/db";
import { listTestKeyUsages, clearTestKeyHwids, removeTestKeyHwid, generateTestKey } from "@/lib/testkey";

async function requireAuth(req: NextRequest) {
  const token = req.cookies.get(SESSION_COOKIE_NAME)?.value;
  return verifySessionToken(token);
}

// GET — return current test key + usage list
export async function GET(req: NextRequest) {
  if (!(await requireAuth(req))) return NextResponse.json({ error: "Unauthorized" }, { status: 401 });
  const [data, usages] = await Promise.all([getSiteData(), listTestKeyUsages()]);
  return NextResponse.json({ test_key: data.test_key, usages });
}

// POST — actions: regenerate key, clear all hwids, remove single hwid
export async function POST(req: NextRequest) {
  if (!(await requireAuth(req))) return NextResponse.json({ error: "Unauthorized" }, { status: 401 });
  const body = await req.json().catch(() => ({}));

  if (body.action === "regenerate") {
    const newKey = await generateTestKey();
    await updateSiteData({ test_key: newKey });
    return NextResponse.json({ test_key: newKey });
  }

  if (body.action === "clear-hwids") {
    await clearTestKeyHwids();
    return NextResponse.json({ ok: true });
  }

  if (body.action === "remove-hwid" && typeof body.hwid === "string") {
    await removeTestKeyHwid(body.hwid);
    return NextResponse.json({ ok: true });
  }

  return NextResponse.json({ error: "Unknown action" }, { status: 400 });
}
