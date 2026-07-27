import { NextRequest, NextResponse } from "next/server";
import { verifySessionToken, SESSION_COOKIE_NAME } from "@/lib/auth";
import { resetHwid, setRevoked, deleteKey } from "@/lib/keys";

async function requireAuth(req: NextRequest) {
  const token = req.cookies.get(SESSION_COOKIE_NAME)?.value;
  return verifySessionToken(token);
}

export async function PATCH(req: NextRequest, { params }: { params: { id: string } }) {
  if (!(await requireAuth(req))) {
    return NextResponse.json({ error: "Unauthorized" }, { status: 401 });
  }
  const id = Number(params.id);
  if (!Number.isFinite(id)) {
    return NextResponse.json({ error: "Invalid id" }, { status: 400 });
  }

  const body = await req.json().catch(() => ({}));

  if (body.action === "reset-hwid") {
    await resetHwid(id);
    return NextResponse.json({ ok: true });
  }
  if (body.action === "revoke") {
    await setRevoked(id, true);
    return NextResponse.json({ ok: true });
  }
  if (body.action === "unrevoke") {
    await setRevoked(id, false);
    return NextResponse.json({ ok: true });
  }

  return NextResponse.json({ error: "Unknown action" }, { status: 400 });
}

export async function DELETE(req: NextRequest, { params }: { params: { id: string } }) {
  if (!(await requireAuth(req))) {
    return NextResponse.json({ error: "Unauthorized" }, { status: 401 });
  }
  const id = Number(params.id);
  if (!Number.isFinite(id)) {
    return NextResponse.json({ error: "Invalid id" }, { status: 400 });
  }
  await deleteKey(id);
  return NextResponse.json({ ok: true });
}
