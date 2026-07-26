import { NextRequest, NextResponse } from "next/server";
import { getSiteData } from "@/lib/db";

export const revalidate = 0;

// Roblox's HttpService (and every executor's HttpGet) sends a User-Agent
// that contains "Roblox". A normal desktop/mobile browser never does, so
// this is a simple, effective gate that keeps casual visitors from being
// able to open the raw script in a tab while costing Roblox clients nothing.
function isRobloxClient(userAgent: string | null): boolean {
  if (!userAgent) return false;
  return /roblox/i.test(userAgent);
}

export async function GET(req: NextRequest, { params }: { params: { file: string } }) {
  const userAgent = req.headers.get("user-agent");

  if (!isRobloxClient(userAgent)) {
    // Don't reveal anything useful to a browser poking at the URL directly.
    return new NextResponse("Not found", { status: 404 });
  }

  if (params.file !== "juru.lua") {
    return new NextResponse("Not found", { status: 404 });
  }

  try {
    const data = await getSiteData();

    if (data.status === "down") {
      return new NextResponse(
        `error("juru.lol is currently down. status: ${data.status}")`,
        { status: 200, headers: { "Content-Type": "text/plain; charset=utf-8" } }
      );
    }

    return new NextResponse(data.script_content, {
      status: 200,
      headers: {
        "Content-Type": "text/plain; charset=utf-8",
        "Cache-Control": "no-store",
      },
    });
  } catch (e) {
    return new NextResponse('error("juru.lol failed to load the script")', {
      status: 200,
      headers: { "Content-Type": "text/plain; charset=utf-8" },
    });
  }
}
