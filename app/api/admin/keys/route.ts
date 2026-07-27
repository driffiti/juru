import { NextRequest, NextResponse } from "next/server";
import { verifySessionToken, SESSION_COOKIE_NAME } from "@/lib/auth";
import { listKeys, createKey } from "@/lib/keys";

async function requireAuth(req: NextRequest) {
  const token = req.cookies.get(SESSION_COOKIE_NAME)?.value;
  return verifySessionToken(token);
}

export async function GET(req: NextRequest) {
  if (!(await requireAuth(req))) {
    return NextResponse.json({ error: "Unauthorized" }, { status: 401 });
  }
  const keys = await listKeys();
  return NextResponse.json(keys);
}

export async function POST(req: NextRequest) {
  if (!(await requireAuth(req))) {
    return NextResponse.json({ error: "Unauthorized" }, { status: 401 });
  }
  const body = await req.json().catch(() => ({}));
  const label = typeof body.label === "string" ? body.label.slice(0, 60) : "";
  const key = await createKey(label);
  return NextResponse.json(key);
}
