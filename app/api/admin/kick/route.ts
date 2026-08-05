import { NextResponse } from "next/server";

// Kick system removed — execution is now tracked via Discord webhook.
export async function POST() {
  return NextResponse.json({ error: "Kick system removed." }, { status: 410 });
}
