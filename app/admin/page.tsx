"use client";

import { useEffect, useState } from "react";
import { useRouter } from "next/navigation";

type SiteData = {
  script_content: string;
  version: string;
  status: "up" | "down" | "maintenance";
  info: string;
  executors: string[];
  video_url: string;
  updated_at: string;
};

export default function AdminPage() {
  const router = useRouter();
  const [data, setData] = useState<SiteData | null>(null);
  const [executorsText, setExecutorsText] = useState("");
  const [saving, setSaving] = useState(false);
  const [saved, setSaved] = useState(false);
  const [error, setError] = useState("");

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
    <main className="mx-auto min-h-screen max-w-2xl px-6 py-14">
      <div className="mb-8 flex items-center justify-between">
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

      <div className="space-y-5">
        {/* Script content */}
        <section className="rounded-2xl border border-white/10 bg-void-card p-5">
          <label className="mb-2 block text-xs font-medium text-mist/60">
            Script contents — served at /script/loader/juru.lua
          </label>
          <textarea
            value={data.script_content}
            onChange={(e) => setData({ ...data, script_content: e.target.value })}
            rows={14}
            spellCheck={false}
            className="w-full resize-y rounded-lg border border-white/10 bg-black/40 p-3.5 font-mono text-xs leading-relaxed text-mist/90 outline-none focus:border-violet-core/60"
          />
        </section>

        <div className="grid grid-cols-2 gap-5">
          <section className="rounded-2xl border border-white/10 bg-void-card p-5">
            <label className="mb-2 block text-xs font-medium text-mist/60">Version</label>
            <input
              value={data.version}
              onChange={(e) => setData({ ...data, version: e.target.value })}
              className="w-full rounded-lg border border-white/10 bg-black/40 px-3 py-2 font-mono text-sm text-white outline-none focus:border-violet-core/60"
            />
          </section>

          <section className="rounded-2xl border border-white/10 bg-void-card p-5">
            <label className="mb-2 block text-xs font-medium text-mist/60">Status</label>
            <select
              value={data.status}
              onChange={(e) => setData({ ...data, status: e.target.value as SiteData["status"] })}
              className="w-full rounded-lg border border-white/10 bg-black/40 px-3 py-2 text-sm text-white outline-none focus:border-violet-core/60"
            >
              <option value="up">Up</option>
              <option value="down">Down</option>
              <option value="maintenance">Maintenance</option>
            </select>
          </section>
        </div>

        <section className="rounded-2xl border border-white/10 bg-void-card p-5">
          <label className="mb-2 block text-xs font-medium text-mist/60">Info / description</label>
          <textarea
            value={data.info}
            onChange={(e) => setData({ ...data, info: e.target.value })}
            rows={3}
            className="w-full resize-y rounded-lg border border-white/10 bg-black/40 p-3 text-sm text-white outline-none focus:border-violet-core/60"
          />
        </section>

        <section className="rounded-2xl border border-white/10 bg-void-card p-5">
          <label className="mb-2 block text-xs font-medium text-mist/60">
            Supported executors (comma-separated)
          </label>
          <input
            value={executorsText}
            onChange={(e) => setExecutorsText(e.target.value)}
            placeholder="Synapse X, Script-Ware, Krnl, Fluxus"
            className="w-full rounded-lg border border-white/10 bg-black/40 px-3 py-2 text-sm text-white outline-none focus:border-violet-core/60"
          />
        </section>

        <section className="rounded-2xl border border-white/10 bg-void-card p-5">
          <label className="mb-2 block text-xs font-medium text-mist/60">Video URL</label>
          <input
            value={data.video_url}
            onChange={(e) => setData({ ...data, video_url: e.target.value })}
            placeholder="https://your-storage.example.com/showcase.mp4"
            className="w-full rounded-lg border border-white/10 bg-black/40 px-3 py-2 font-mono text-xs text-white outline-none focus:border-violet-core/60"
          />
          <p className="mt-2 text-[11px] text-mist/40">
            Use a direct .mp4 link (Bunny Stream, Cloudflare R2/Stream, or your own storage) — not an
            embed iframe — so the fullscreen prompt shows juru.lol instead of a third-party domain.
          </p>
        </section>

        {error && <p className="text-xs text-red-400">{error}</p>}

        <button
          onClick={save}
          disabled={saving}
          className="w-full rounded-lg border border-violet-core/40 bg-violet-core/25 py-3 text-sm font-medium text-white transition hover:bg-violet-core/40 disabled:opacity-40"
        >
          {saving ? "Saving…" : saved ? "Saved ✓" : "Save changes"}
        </button>
      </div>
    </main>
  );
}
