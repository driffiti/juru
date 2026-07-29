import { NextRequest, NextResponse } from "next/server";
import { verifySessionToken, SESSION_COOKIE_NAME } from "@/lib/auth";
import { requestKick } from "@/lib/stats";

export async function POST(req: NextRequest) {
  const token = req.cookies.get(SESSION_COOKIE_NAME)?.value;
  if (!(await verifySessionToken(token))) {
    return NextResponse.json({ error: "Unauthorized" }, { status: 401 });
  }

  const body = await req.json().catch(() => ({}));
  const jobId = typeof body.jobId === "string" ? body.jobId : null;
  const userId = typeof body.userId === "number" ? body.userId : null;

  if (!jobId || userId === null) {
    return NextResponse.json({ error: "missing jobId/userId" }, { status: 400 });
  }

  await requestKick(jobId, userId);
  return NextResponse.json({ ok: true });
}
