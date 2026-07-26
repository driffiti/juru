import { NextRequest, NextResponse } from "next/server";
import { getSiteData } from "@/lib/db";
import { isRobloxClient } from "@/lib/roblox";
import { recordLoad } from "@/lib/stats";
import { buildServedScript } from "@/lib/heartbeat";

export const revalidate = 0;

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

    // Fire-and-forget: log the load for stats without slowing the response.
    // If this fails (e.g. DB hiccup) it should never block the script.
    recordLoad().catch(() => {});

    if (data.status === "down") {
      return new NextResponse(
        `error("juru.lol is currently down. status: ${data.status}")`,
        { status: 200, headers: { "Content-Type": "text/plain; charset=utf-8" } }
      );
    }

    // The heartbeat (place/job id + player count ping, used to power the
    // "servers running the script" list in /admin) is baked in here, so
    // the admin never has to remember to include it in the script content.
    const served = buildServedScript(data.script_content);

    return new NextResponse(served, {
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
