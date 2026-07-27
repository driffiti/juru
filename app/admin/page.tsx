"use client";

import { useEffect, useRef, useState } from "react";
import { useRouter } from "next/navigation";

type SiteData = {
  script_content: string;
  version: string;
  status: "up" | "down" | "maintenance";
  info: string;
  executors: string[];
  video_url: string;
  require_key: boolean;
  updated_at: string;
};

type ActiveSession = {
  job_id: string;
  place_id: string;
  user_id: number;
  player_name: string;
  display_name: string;
  player_count: number;
  executor: string;
  first_seen: string;
  last_seen: string;
};

type Stats = {
  total_loads: number;
  loads_last_24h: number;
  active_servers: number;
  active_scripters: number;
  sessions: ActiveSession[];
};

type ServerGroup = {
  job_id: string;
  place_id: string;
  player_count: number;
  last_seen: string;
  users: ActiveSession[];
};

function groupByServer(sessions: ActiveSession[]): ServerGroup[] {
  const map = new Map<string, ServerGroup>();
  for (const s of sessions) {
    const existing = map.get(s.job_id);
    if (!existing) {
      map.set(s.job_id, {
        job_id: s.job_id,
        place_id: s.place_id,
        player_count: s.player_count,
        last_seen: s.last_seen,
        users: [s],
      });
      continue;
    }
    existing.users.push(s);
    existing.player_count = Math.max(existing.player_count, s.player_count);
    if (new Date(s.last_seen) > new Date(existing.last_seen)) existing.last_seen = s.last_seen;
  }
  return Array.from(map.values()).sort(
    (a, b) => new Date(b.last_seen).getTime() - new Date(a.last_seen).getTime()
  );
}

function profileUrl(userId: number): string {
  return `https://www.roblox.com/users/${userId}/profile`;
}

function timeAgo(iso: string): string {
  const seconds = Math.max(0, Math.floor((Date.now() - new Date(iso).getTime()) / 1000));
  if (seconds < 60) return `${seconds}s ago`;
  const minutes = Math.floor(seconds / 60);
  if (minutes < 60) return `${minutes}m ago`;
  const hours = Math.floor(minutes / 60);
  return `${hours}h ago`;
}

function joinUrl(server: { place_id: string; job_id: string }): string {
  return `https://www.roblox.com/games/start?placeId=${server.place_id}&gameInstanceId=${server.job_id}`;
}

const STATUS_OPTIONS: { value: SiteData["status"]; label: string; dot: string }[] = [
  { value: "up", label: "Up", dot: "bg-emerald-400" },
  { value: "down", label: "Down", dot: "bg-red-400" },
  { value: "maintenance", label: "Maintenance", dot: "bg-amber-400" },
];

function StatusDropdown({
  value,
  onChange,
}: {
  value: SiteData["status"];
  onChange: (v: SiteData["status"]) => void;
}) {
  const [open, setOpen] = useState(false);
  const ref = useRef<HTMLDivElement>(null);
  const current = STATUS_OPTIONS.find((o) => o.value === value) ?? STATUS_OPTIONS[0];

  useEffect(() => {
    function onClickOutside(e: MouseEvent) {
      if (ref.current && !ref.current.contains(e.target as Node)) setOpen(false);
    }
    document.addEventListener("mousedown", onClickOutside);
    return () => document.removeEventListener("mousedown", onClickOutside);
  }, []);

  return (
    <div ref={ref} className="relative">
      <button
        type="button"
        onClick={() => setOpen((o) => !o)}
        className="flex w-full items-center justify-between rounded-lg border border-white/10 bg-black/40 px-3 py-2 text-sm text-white outline-none transition focus:border-violet-core/60"
      >
        <span className="flex items-center gap-2">
          <span className={`h-1.5 w-1.5 rounded-full ${current.dot}`} />
          {current.label}
        </span>
        <svg
          width="12"
          height="12"
          viewBox="0 0 12 12"
          fill="none"
          className={`text-mist/40 transition-transform ${open ? "rotate-180" : ""}`}
        >
          <path d="M2.5 4.5L6 8l3.5-3.5" stroke="currentColor" strokeWidth="1.4" strokeLinecap="round" strokeLinejoin="round" />
        </svg>
      </button>

      {open && (
        <div className="absolute z-20 mt-1.5 w-full overflow-hidden rounded-lg border border-white/10 bg-void-card shadow-glow">
          {STATUS_OPTIONS.map((o) => (
            <button
              key={o.value}
              type="button"
              onClick={() => {
                onChange(o.value);
                setOpen(false);
              }}
              className={`flex w-full items-center gap-2 px-3 py-2 text-left text-sm transition hover:bg-white/[0.06] ${
                o.value === value ? "bg-white/[0.04] text-white" : "text-mist/70"
              }`}
            >
              <span className={`h-1.5 w-1.5 rounded-full ${o.dot}`} />
              {o.label}
            </button>
          ))}
        </div>
      )}
    </div>
  );
}

function Toggle({ checked, onChange }: { checked: boolean; onChange: (v: boolean) => void }) {
  return (
    <button
      type="button"
      role="switch"
      aria-checked={checked}
      onClick={() => onChange(!checked)}
      className={`relative h-6 w-11 shrink-0 rounded-full border transition-colors ${
        checked ? "border-violet-core/60 bg-violet-core/60" : "border-white/10 bg-white/[0.06]"
      }`}
    >
      <span
        className={`absolute left-0.5 top-0.5 h-5 w-5 rounded-full bg-white transition-transform ${
          checked ? "translate-x-5" : "translate-x-0"
        }`}
      />
    </button>
  );
}

export default function AdminPage() {
  const router = useRouter();
  const [data, setData] = useState<SiteData | null>(null);
  const [executorsText, setExecutorsText] = useState("");
  const [saving, setSaving] = useState(false);
  const [saved, setSaved] = useState(false);
  const [error, setError] = useState("");
  const [stats, setStats] = useState<Stats | null>(null);

  useEffect(() => {
    fetch("/api/admin/data")
      .then((r) => {
        if (r.status === 401) {
          router.push("/login");
          return null;
        }
        return r.json();
      })
      .then((d: SiteData | null) => {
        if (!d) return;
        setData(d);
        setExecutorsText(d.executors.join(", "));
      });
  }, [router]);

  useEffect(() => {
    function loadStats() {
      fetch("/api/admin/stats")
        .then((r) => (r.ok ? r.json() : null))
        .then((s: Stats | null) => {
          if (s) setStats(s);
        })
        .catch(() => {});
    }
    loadStats();
    const interval = setInterval(loadStats, 10000);
    return () => clearInterval(interval);
  }, []);

  async function save() {
    if (!data) return;
    setSaving(true);
    setError("");
    const patch = {
      ...data,
      executors: executorsText
        .split(",")
        .map((s) => s.trim())
        .filter(Boolean),
    };
    const res = await fetch("/api/admin/data", {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify(patch),
    });
    setSaving(false);
    if (res.ok) {
      const updated = await res.json();
      setData(updated);
      setSaved(true);
      setTimeout(() => setSaved(false), 1800);
    } else {
      setError("Save failed. Try again.");
    }
  }

  async function logout() {
    await fetch("/api/admin/login", { method: "DELETE" });
    router.push("/login");
  }

  if (!data) {
    return (
      <main className="flex min-h-screen items-center justify-center">
        <p className="text-sm text-mist/40">Loading…</p>
      </main>
    );
  }

  return (
    <main className="mx-auto min-h-screen max-w-6xl px-6 py-8">
      <div className="mb-6 flex items-center justify-between">
        <span className="font-display text-lg font-semibold text-white">
          juru<span className="text-violet-glow">.lol</span>{" "}
          <span className="text-mist/40">/ admin</span>
        </span>
        <button
          onClick={logout}
          className="rounded-full border border-white/10 bg-white/[0.03] px-4 py-1.5 text-xs text-mist/60 transition hover:border-red-400/40 hover:text-red-400"
        >
          Log out
        </button>
      </div>

      <div className="grid gap-5 lg:grid-cols-[1fr_320px]">
        {/* Main editing column */}
        <div className="space-y-4">
          <section className="rounded-2xl border border-white/10 bg-void-card p-4">
            <div className="mb-2 flex items-center justify-between">
              <label className="text-xs font-medium text-mist/60">
                Script contents — served at /script/loader/juru.lua
              </label>
              <span className="text-[10px] text-mist/35">
                heartbeat ping is auto-injected, no need to paste it
              </span>
            </div>
            <textarea
              value={data.script_content}
              onChange={(e) => setData({ ...data, script_content: e.target.value })}
              rows={11}
              spellCheck={false}
              className="w-full resize-none rounded-lg border border-white/10 bg-black/40 p-3.5 font-mono text-xs leading-relaxed text-mist/90 outline-none focus:border-violet-core/60"
            />
          </section>

          <section className="grid grid-cols-2 gap-4 rounded-2xl border border-white/10 bg-void-card p-4 sm:grid-cols-4">
            <div>
              <label className="mb-1.5 block text-xs font-medium text-mist/60">Version</label>
              <input
                value={data.version}
                onChange={(e) => setData({ ...data, version: e.target.value })}
                className="w-full rounded-lg border border-white/10 bg-black/40 px-3 py-2 font-mono text-sm text-white outline-none focus:border-violet-core/60"
              />
            </div>
            <div>
              <label className="mb-1.5 block text-xs font-medium text-mist/60">Status</label>
              <StatusDropdown
                value={data.status}
                onChange={(v) => setData({ ...data, status: v })}
              />
            </div>
            <div className="col-span-2">
              <label className="mb-1.5 block text-xs font-medium text-mist/60">
                Executors (comma-separated)
              </label>
              <input
                value={executorsText}
                onChange={(e) => setExecutorsText(e.target.value)}
                placeholder="Synapse X, Script-Ware, Krnl, Fluxus"
                className="w-full rounded-lg border border-white/10 bg-black/40 px-3 py-2 text-sm text-white outline-none focus:border-violet-core/60"
              />
            </div>
          </section>

          <section className="grid grid-cols-1 gap-4 rounded-2xl border border-white/10 bg-void-card p-4 sm:grid-cols-2">
            <div>
              <label className="mb-1.5 block text-xs font-medium text-mist/60">Info / description</label>
              <textarea
                value={data.info}
                onChange={(e) => setData({ ...data, info: e.target.value })}
                rows={3}
                className="w-full resize-none rounded-lg border border-white/10 bg-black/40 p-3 text-sm text-white outline-none focus:border-violet-core/60"
              />
            </div>
            <div>
              <label className="mb-1.5 block text-xs font-medium text-mist/60">Video URL</label>
              <input
                value={data.video_url}
                onChange={(e) => setData({ ...data, video_url: e.target.value })}
                placeholder="https://your-storage.example.com/showcase.mp4"
                className="w-full rounded-lg border border-white/10 bg-black/40 px-3 py-2 font-mono text-xs text-white outline-none focus:border-violet-core/60"
              />
              <p className="mt-2 text-[11px] text-mist/40">
                Direct .mp4 link (Bunny Stream, Cloudflare R2/Stream) — not an iframe embed — so
                fullscreen shows juru.lol.
              </p>
            </div>
          </section>

          <section className="flex items-center justify-between gap-4 rounded-2xl border border-white/10 bg-void-card p-4">
            <div>
              <p className="text-xs font-medium text-white">Require a key to run</p>
              <p className="mt-0.5 text-[11px] text-mist/40">
                Off — anyone with the loadstring can run the script. On — needs a valid,
                HWID-locked key set as <code className="text-mist/60">SCRIPT_KEY</code> before the
                loadstring.
              </p>
            </div>
            <div className="flex shrink-0 items-center gap-3">
              <Toggle
                checked={data.require_key}
                onChange={(v) => setData({ ...data, require_key: v })}
              />
              <a
                href="/admin/keys"
                className="rounded-lg border border-violet-core/40 bg-violet-core/20 px-3 py-1.5 text-xs font-medium text-white transition hover:bg-violet-core/35"
              >
                Manage keys →
              </a>
            </div>
          </section>

          {error && <p className="text-xs text-red-400">{error}</p>}

          <button
            onClick={save}
            disabled={saving}
            className="w-full rounded-lg border border-violet-core/40 bg-violet-core/25 py-2.5 text-sm font-medium text-white transition hover:bg-violet-core/40 disabled:opacity-40"
          >
            {saving ? "Saving…" : saved ? "Saved ✓" : "Save changes"}
          </button>
        </div>

        {/* Sidebar: stats + live sessions */}
        <aside className="space-y-4">
          <div className="grid grid-cols-2 gap-3">
            <div className="rounded-2xl border border-white/10 bg-void-card p-3.5">
              <p className="text-[10px] text-mist/40">Total loads</p>
              <p className="mt-0.5 font-display text-xl font-semibold text-white">
                {stats ? stats.total_loads.toLocaleString() : "—"}
              </p>
            </div>
            <div className="rounded-2xl border border-white/10 bg-void-card p-3.5">
              <p className="text-[10px] text-mist/40">Loads (24h)</p>
              <p className="mt-0.5 font-display text-xl font-semibold text-white">
                {stats ? stats.loads_last_24h.toLocaleString() : "—"}
              </p>
            </div>
            <div className="rounded-2xl border border-white/10 bg-void-card p-3.5">
              <p className="text-[10px] text-mist/40">Active servers</p>
              <p className="mt-0.5 font-display text-xl font-semibold text-violet-glow">
                {stats ? stats.active_servers.toLocaleString() : "—"}
              </p>
            </div>
            <div className="rounded-2xl border border-white/10 bg-void-card p-3.5">
              <p className="text-[10px] text-mist/40">Running script</p>
              <p className="mt-0.5 font-display text-xl font-semibold text-white">
                {stats ? stats.active_scripters.toLocaleString() : "—"}
              </p>
            </div>
          </div>

          <div className="rounded-2xl border border-white/10 bg-void-card p-4">
            <div className="mb-2.5 flex items-center justify-between">
              <h2 className="font-display text-xs font-medium text-white">Live servers</h2>
              <span className="flex items-center gap-1.5 text-[10px] text-mist/40">
                <span className="status-dot h-1.5 w-1.5 rounded-full bg-violet-glow" />
                every 10s
              </span>
            </div>

            {!stats || stats.sessions.length === 0 ? (
              <p className="py-3 text-center text-[11px] leading-relaxed text-mist/40">
                Nothing active yet — this fills in as players load the script.
              </p>
            ) : (
              <div className="max-h-[420px] space-y-2 overflow-y-auto pr-1">
                {groupByServer(stats.sessions).map((g) => (
                  <div
                    key={g.job_id}
                    className="rounded-lg border border-white/10 bg-black/30 px-3 py-2.5"
                  >
                    <div className="flex items-center justify-between gap-2">
                      <p className="truncate font-mono text-[11px] text-mist/80">
                        place {g.place_id} <span className="text-mist/30">·</span> {g.player_count}p
                        <span className="text-mist/30"> · </span>
                        {timeAgo(g.last_seen)}
                      </p>
                      <a
                        href={joinUrl(g)}
                        className="shrink-0 rounded-md border border-violet-core/40 bg-violet-core/20 px-2.5 py-1 text-[10px] font-medium text-white transition hover:bg-violet-core/35"
                      >
                        Join
                      </a>
                    </div>

                    <div className="mt-2 flex flex-wrap gap-1.5">
                      {g.users.map((u) => (
                        <a
                          key={u.user_id}
                          href={profileUrl(u.user_id)}
                          target="_blank"
                          rel="noreferrer"
                          title={`${u.display_name} (@${u.player_name}) · ${u.executor} · ${timeAgo(u.last_seen)}`}
                          className="flex items-center gap-1.5 rounded-full border border-white/10 bg-white/[0.04] px-2 py-0.5 text-[10px] text-mist/70 transition hover:border-violet-core/50 hover:text-white"
                        >
                          <span>
                            {u.display_name && u.display_name !== u.player_name
                              ? `${u.display_name} (@${u.player_name})`
                              : `@${u.player_name}`}
                          </span>
                          <span className="text-mist/30">·</span>
                          <span className="text-violet-glow/80">{u.executor}</span>
                        </a>
                      ))}
                    </div>
                  </div>
                ))}
              </div>
            )}
          </div>
        </aside>
      </div>
    </main>
  );
}
