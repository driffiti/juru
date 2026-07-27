import { NextResponse } from "next/server";
import { getSiteData } from "@/lib/db";

export const revalidate = 0;

export async function GET() {
  try {
    const data = await getSiteData();
    return NextResponse.json({
      version: data.version,
      status: data.status,
      info: data.info,
      executors: data.executors,
      video_url: data.video_url,
      require_key: data.require_key,
      updated_at: data.updated_at,
    });
  } catch (e) {
    return NextResponse.json(
      { version: "?", status: "down", info: "", executors: [], video_url: "", require_key: false },
      { status: 200 }
    );
  }
}
