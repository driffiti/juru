"use client";

import { useEffect, useRef, useState } from "react";

type StatusPayload = {
  version: string;
  status: "up" | "down" | "maintenance";
  info: string;
  executors: string[];
  video_url: string;
  updated_at: string;
};

const LOADSTRING = `loadstring(game:HttpGet("https://juru.lol/script/loader/juru.lua"))()`;

const STATUS_META: Record<StatusPayload["status"], { label: string; color: string; dot: string }> = {
  up: { label: "Operational", color: "text-emerald-400", dot: "bg-emerald-400" },
  down: { label: "Down", color: "text-red-400", dot: "bg-red-400" },
  maintenance: { label: "Maintenance", color: "text-amber-400", dot: "bg-amber-400" },
};

export default function Home() {
  const [data, setData] = useState<StatusPayload | null>(null);
  const [copied, setCopied] = useState(false);
  const videoRef = useRef<HTMLVideoElement>(null);

  useEffect(() => {
    fetch("/api/status")
      .then((r) => r.json())
      .then(setData)
      .catch(() => setData(null));
  }, []);

  function copyLoadstring() {
    navigator.clipboard.writeText(LOADSTRING).then(() => {
      setCopied(true);
      setTimeout(() => setCopied(false), 1800);
    });
  }

  function goFullscreen() {
    videoRef.current?.requestFullscreen?.();
  }

  const meta = data ? STATUS_META[data.status] : null;

  return (
    <main className="relative mx-auto flex min-h-screen max-w-3xl flex-col items-center px-6 py-20">
      {/* Nav */}
      <div className="mb-16 flex w-full items-center justify-between rise">
        <span className="font-display text-lg font-semibold tracking-tight text-white">
          juru<span className="text-violet-glow">.lol</span>
        </span>
        <a
          href="/login"
          className="rounded-full border border-white/10 bg-white/[0.03] px-4 py-1.5 text-xs font-medium text-mist/70 transition hover:border-violet-core/50 hover:text-white"
        >
          Admin
        </a>
      </div>

      {/* Hero */}
      <div className="mb-10 flex flex-col items-center text-center rise rise-1">
        <div className="mb-5 flex items-center gap-2 rounded-full border border-violet-dim bg-violet-dim/20 px-3 py-1">
          <span className={`status-dot h-2 w-2 rounded-full ${meta?.dot ?? "bg-white/20"}`} />
          <span className={`text-xs font-medium ${meta?.color ?? "text-mist/50"}`}>
            {data ? meta!.label : "Checking status…"}
          </span>
          {data && (
            <>
              <span className="text-white/10">•</span>
              <span className="font-mono text-xs text-mist/60">v{data.version}</span>
            </>
          )}
        </div>
        <h1 className="font-display text-4xl font-semibold leading-tight text-white sm:text-5xl">
          One script.<br />One line.
        </h1>
        <p className="mt-4 max-w-md text-sm leading-relaxed text-mist/60">
          {data?.info || "Drop the loadstring into your executor and you're in. Updated, monitored, and gated to Roblox clients only."}
        </p>
      </div>

      {/* Terminal / loadstring card */}
      <div className="w-full rise rise-2">
        <div className="overflow-hidden rounded-2xl border border-white/10 bg-void-card shadow-glow">
          <div className="flex items-center justify-between border-b border-white/5 bg-white/[0.02] px-4 py-3">
            <div className="flex items-center gap-1.5">
              <span className="h-2.5 w-2.5 rounded-full bg-white/15" />
              <span className="h-2.5 w-2.5 rounded-full bg-white/15" />
              <span className="h-2.5 w-2.5 rounded-full bg-white/15" />
            </div>
            <span className="font-mono text-[11px] text-mist/40">loader.lua</span>
          </div>
          <div className="flex items-center justify-between gap-3 px-5 py-5">
            <code className="overflow-hidden whitespace-pre font-mono text-[13px] leading-relaxed text-mist/90 sm:text-sm">
              <span className="text-violet-glow">loadstring</span>
              <span className="text-white/70">(</span>
              <span className="text-white/70">game:</span>
              <span className="text-violet-glow">HttpGet</span>
              <span className="text-white/70">(</span>
              <span className="text-emerald-300/90">&quot;https://juru.lol/script/loader/juru.lua&quot;</span>
              <span className="text-white/70">))()</span>
            </code>
            <button
              onClick={copyLoadstring}
              className="shrink-0 rounded-lg border border-violet-core/40 bg-violet-core/20 px-4 py-2 text-xs font-medium text-white transition hover:bg-violet-core/35 active:scale-[0.97]"
            >
              {copied ? "Copied ✓" : "Copy"}
            </button>
          </div>
        </div>
      </div>

      {/* Info grid: executors + status */}
      <div className="mt-6 grid w-full grid-cols-1 gap-4 rise rise-3 sm:grid-cols-2">
        <div className="rounded-2xl border border-white/10 bg-void-card/70 p-5">
          <h2 className="mb-3 font-display text-sm font-medium text-white">Supported executors</h2>
          <div className="flex flex-wrap gap-2">
            {(data?.executors && data.executors.length > 0
              ? data.executors
              : ["—"]
            ).map((ex) => (
              <span
                key={ex}
                className="rounded-full border border-white/10 bg-white/[0.03] px-3 py-1 text-xs text-mist/70"
              >
                {ex}
              </span>
            ))}
          </div>
        </div>

        <div className="rounded-2xl border border-white/10 bg-void-card/70 p-5">
          <h2 className="mb-3 font-display text-sm font-medium text-white">Status</h2>
          <dl className="space-y-2 text-xs">
            <div className="flex items-center justify-between">
              <dt className="text-mist/50">State</dt>
              <dd className={meta?.color ?? "text-mist/50"}>{data ? meta!.label : "—"}</dd>
            </div>
            <div className="flex items-center justify-between">
              <dt className="text-mist/50">Version</dt>
              <dd className="font-mono text-mist/80">{data ? `v${data.version}` : "—"}</dd>
            </div>
            <div className="flex items-center justify-between">
              <dt className="text-mist/50">Last updated</dt>
              <dd className="text-mist/80">
                {data?.updated_at ? new Date(data.updated_at).toLocaleString() : "—"}
              </dd>
            </div>
          </dl>
        </div>
      </div>

      {/* Video */}
      {data?.video_url && (
        <div className="mt-6 w-full rise rise-4">
          <div className="overflow-hidden rounded-2xl border border-white/10 bg-void-card">
            <div className="flex items-center justify-between border-b border-white/5 px-4 py-3">
              <span className="font-display text-sm font-medium text-white">Showcase</span>
              <button
                onClick={goFullscreen}
                className="rounded-full border border-white/10 bg-white/[0.03] px-3 py-1 text-[11px] text-mist/60 transition hover:border-violet-core/50 hover:text-white"
              >
                Fullscreen
              </button>
            </div>
            <video
              ref={videoRef}
              src={data.video_url}
              controls
              playsInline
              className="aspect-video w-full bg-black"
            />
          </div>
        </div>
      )}

      <footer className="mt-16 text-center text-[11px] text-mist/30">
        juru.lol — hosted independently, served straight to Roblox.
      </footer>
    </main>
  );
}
