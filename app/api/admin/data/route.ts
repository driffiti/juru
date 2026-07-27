import { NextRequest, NextResponse } from "next/server";
import { verifySessionToken, SESSION_COOKIE_NAME } from "@/lib/auth";
import { getSiteData, updateSiteData } from "@/lib/db";

async function requireAuth(req: NextRequest) {
  const token = req.cookies.get(SESSION_COOKIE_NAME)?.value;
  return verifySessionToken(token);
}

export async function GET(req: NextRequest) {
  if (!(await requireAuth(req))) {
    return NextResponse.json({ error: "Unauthorized" }, { status: 401 });
  }
  const data = await getSiteData();
  return NextResponse.json(data);
}

export async function POST(req: NextRequest) {
  if (!(await requireAuth(req))) {
    return NextResponse.json({ error: "Unauthorized" }, { status: 401 });
  }
  const body = await req.json();

  const patch: Record<string, unknown> = {};
  if (typeof body.script_content === "string") patch.script_content = body.script_content;
  if (typeof body.version === "string") patch.version = body.version;
  if (["up", "down", "maintenance"].includes(body.status)) patch.status = body.status;
  if (typeof body.info === "string") patch.info = body.info;
  if (Array.isArray(body.executors)) patch.executors = body.executors.filter((e: unknown) => typeof e === "string");
  if (typeof body.video_url === "string") patch.video_url = body.video_url;
  if (typeof body.require_key === "boolean") patch.require_key = body.require_key;

  const updated = await updateSiteData(patch as any);
  return NextResponse.json(updated);
}
