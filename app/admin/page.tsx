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
  test_key: string;
  webhook_url: string;
  updated_at: string;
};

type Stats = { total_loads: number; loads_last_24h: number };

type KeyType = "day" | "week" | "month" | "lifetime";
type ScriptKey = {
  id: number; key_value: string; key_type: KeyType; hwid: string | null;
  label: string; created_at: string; expires_at: string | null;
  last_used_at: string | null; revoked: boolean;
};

type TestKeyUsage = { hwid: string; player_name: string; display_name: string; first_seen: string; expired: boolean };

const STATUS_OPTIONS = [
  { value: "up"          as const, label: "Up",          dot: "bg-emerald-400" },
  { value: "down"        as const, label: "Down",        dot: "bg-red-400"     },
  { value: "maintenance" as const, label: "Maintenance", dot: "bg-amber-400"   },
];

const TYPE_META: Record<KeyType, { label: string; color: string; border: string }> = {
  day:      { label: "1 Day",    color: "text-sky-400",     border: "border-sky-400/30 bg-sky-400/10"     },
  week:     { label: "1 Week",   color: "text-violet-400",  border: "border-violet-400/30 bg-violet-400/10" },
  month:    { label: "1 Month",  color: "text-amber-400",   border: "border-amber-400/30 bg-amber-400/10"  },
  lifetime: { label: "Lifetime", color: "text-emerald-400", border: "border-emerald-400/30 bg-emerald-400/10" },
};

function timeAgo(iso: string | null): string {
  if (!iso) return "never";
  const s = Math.max(0, Math.floor((Date.now() - new Date(iso).getTime()) / 1000));
  if (s < 60) return `${s}s ago`;
  const m = Math.floor(s / 60);
  if (m < 60) return `${m}m ago`;
  const h = Math.floor(m / 60);
  if (h < 24) return `${h}h ago`;
  return `${Math.floor(h / 24)}d ago`;
}

function expiresIn(iso: string | null): string {
  if (!iso) return "Never";
  const ms = new Date(iso).getTime() - Date.now();
  if (ms <= 0) return "Expired";
  const m = Math.floor(ms / 60000);
  if (m < 60) return `${m}m`;
  const h = Math.floor(m / 60);
  if (h < 24) return `${h}h`;
  return `${Math.floor(h / 24)}d`;
}

function StatusDropdown({ value, onChange }: { value: SiteData["status"]; onChange: (v: SiteData["status"]) => void }) {
  const [open, setOpen] = useState(false);
  const ref = useRef<HTMLDivElement>(null);
  const current = STATUS_OPTIONS.find((o) => o.value === value) ?? STATUS_OPTIONS[0];
  useEffect(() => {
    function out(e: MouseEvent) { if (ref.current && !ref.current.contains(e.target as Node)) setOpen(false); }
    document.addEventListener("mousedown", out);
    return () => document.removeEventListener("mousedown", out);
  }, []);
  return (
    <div ref={ref} className="relative">
      <button type="button" onClick={() => setOpen((o) => !o)}
        className="flex w-full items-center justify-between rounded-lg border border-white/10 bg-black/40 px-3 py-2 text-sm text-white outline-none transition focus:border-violet-core/60">
        <span className="flex items-center gap-2">
          <span className={`h-1.5 w-1.5 rounded-full ${current.dot}`} />
          {current.label}
        </span>
        <svg width="12" height="12" viewBox="0 0 12 12" fill="none" className={`text-mist/40 transition-transform ${open ? "rotate-180" : ""}`}>
          <path d="M2.5 4.5L6 8l3.5-3.5" stroke="currentColor" strokeWidth="1.4" strokeLinecap="round" strokeLinejoin="round" />
        </svg>
      </button>
      {open && (
        <div className="absolute z-20 mt-1.5 w-full overflow-hidden rounded-lg border border-white/10 bg-void-card shadow-glow">
          {STATUS_OPTIONS.map((o) => (
            <button key={o.value} type="button" onClick={() => { onChange(o.value); setOpen(false); }}
              className={`flex w-full items-center gap-2 px-3 py-2 text-left text-sm transition hover:bg-white/[0.06] ${o.value === value ? "bg-white/[0.04] text-white" : "text-mist/70"}`}>
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
    <button type="button" role="switch" aria-checked={checked} onClick={() => onChange(!checked)}
      className={`relative h-6 w-11 shrink-0 rounded-full border transition-colors ${checked ? "border-violet-core/60 bg-violet-core/60" : "border-white/10 bg-white/[0.06]"}`}>
      <span className={`absolute left-0.5 top-0.5 h-5 w-5 rounded-full bg-white transition-transform ${checked ? "translate-x-5" : "translate-x-0"}`} />
    </button>
  );
}

export default function AdminPage() {
  const router = useRouter();
  const [data, setData]             = useState<SiteData | null>(null);
  const [executorsText, setExecutorsText] = useState("");
  const [saving, setSaving]         = useState(false);
  const [saved, setSaved]           = useState(false);
  const [error, setError]           = useState("");
  const [stats, setStats]           = useState<Stats | null>(null);

  // Keys
  const [keys, setKeys]             = useState<ScriptKey[] | null>(null);
  const [keyFilter, setKeyFilter]   = useState<"all"|"active"|"expired"|"revoked">("all");
  const [keySearch, setKeySearch]   = useState("");
  const [keyBusyId, setKeyBusyId]   = useState<number | null>(null);
  const [copiedKeyId, setCopiedKeyId] = useState<number | null>(null);
  const [newKeyLabel, setNewKeyLabel] = useState("");
  const [newKeyType, setNewKeyType] = useState<KeyType>("lifetime");
  const [generatingKey, setGeneratingKey] = useState(false);

  // Test key
  const [testKey, setTestKey]       = useState("");
  const [testUsages, setTestUsages] = useState<TestKeyUsage[]>([]);
  const [testKeyCopied, setTestKeyCopied] = useState(false);
  const [testKeyBusy, setTestKeyBusy] = useState(false);

  useEffect(() => {
    fetch("/api/admin/data")
      .then((r) => { if (r.status === 401) { router.push("/login"); return null; } return r.json(); })
      .then((d: SiteData | null) => {
        if (!d) return;
        setData(d);
        setExecutorsText(d.executors.join(", "));
        setTestKey(d.test_key ?? "");
      });
  }, [router]);

  useEffect(() => {
    fetch("/api/admin/stats").then((r) => r.ok ? r.json() : null).then((s) => { if (s) setStats(s); });
  }, []);

  function loadKeys() {
    fetch("/api/admin/keys").then((r) => r.ok ? r.json() : null).then((k: ScriptKey[] | null) => { if (k) setKeys(k); });
  }
  useEffect(loadKeys, []);

  function loadTestKey() {
    fetch("/api/admin/testkey").then((r) => r.ok ? r.json() : null)
      .then((d: { test_key: string; usages: TestKeyUsage[] } | null) => {
        if (!d) return;
        setTestKey(d.test_key);
        setTestUsages(d.usages);
      });
  }
  useEffect(loadTestKey, []);

  async function save() {
    if (!data) return;
    setSaving(true); setError("");
    const res = await fetch("/api/admin/data", {
      method: "POST", headers: { "Content-Type": "application/json" },
      body: JSON.stringify({ ...data, executors: executorsText.split(",").map((s) => s.trim()).filter(Boolean) }),
    });
    setSaving(false);
    if (res.ok) { setData(await res.json()); setSaved(true); setTimeout(() => setSaved(false), 1800); }
    else setError("Save failed.");
  }

  async function logout() { await fetch("/api/admin/login", { method: "DELETE" }); router.push("/login"); }

  async function keyAction(id: number, action: string) {
    setKeyBusyId(id);
    await fetch(`/api/admin/keys/${id}`, { method: "PATCH", headers: { "Content-Type": "application/json" }, body: JSON.stringify({ action }) });
    setKeyBusyId(null); loadKeys();
  }
  async function deleteKey(id: number) {
    if (!confirm("Delete this key permanently?")) return;
    setKeyBusyId(id);
    await fetch(`/api/admin/keys/${id}`, { method: "DELETE" });
    setKeyBusyId(null); loadKeys();
  }
  async function generateKey() {
    setGeneratingKey(true);
    await fetch("/api/admin/keys", { method: "POST", headers: { "Content-Type": "application/json" }, body: JSON.stringify({ label: newKeyLabel, type: newKeyType }) });
    setNewKeyLabel(""); setGeneratingKey(false); loadKeys();
  }
  function copyKey(k: ScriptKey) {
    navigator.clipboard.writeText(k.key_value).then(() => { setCopiedKeyId(k.id); setTimeout(() => setCopiedKeyId(null), 1500); });
  }

  async function testKeyAction(action: string, hwid?: string) {
    setTestKeyBusy(true);
    await fetch("/api/admin/testkey", { method: "POST", headers: { "Content-Type": "application/json" }, body: JSON.stringify({ action, hwid }) });
    setTestKeyBusy(false); loadTestKey();
  }
  function copyTestKey() { navigator.clipboard.writeText(testKey).then(() => { setTestKeyCopied(true); setTimeout(() => setTestKeyCopied(false), 1500); }); }

  if (!data) return <main className="flex min-h-screen items-center justify-center"><p className="text-sm text-mist/40">Loading…</p></main>;

  const filteredKeys = (keys ?? []).filter((k) => {
    const expired = k.expires_at && new Date(k.expires_at) < new Date();
    if (keyFilter === "active"  && (k.revoked || expired)) return false;
    if (keyFilter === "expired" && !expired) return false;
    if (keyFilter === "revoked" && !k.revoked) return false;
    if (keySearch) {
      const q = keySearch.toLowerCase();
      if (!k.key_value.toLowerCase().includes(q) && !k.label.toLowerCase().includes(q)) return false;
    }
    return true;
  });

  const keyStats = {
    total:   (keys ?? []).length,
    active:  (keys ?? []).filter((k) => !k.revoked && (!k.expires_at || new Date(k.expires_at) > new Date())).length,
    expired: (keys ?? []).filter((k) => k.expires_at && new Date(k.expires_at) < new Date()).length,
    revoked: (keys ?? []).filter((k) => k.revoked).length,
  };

  return (
    <main className="mx-auto min-h-screen max-w-7xl px-6 py-8">
      <div className="mb-6 flex items-center justify-between">
        <span className="font-display text-lg font-semibold text-white">
          juru<span className="text-violet-glow">.lol</span> <span className="text-mist/40">/ admin</span>
        </span>
        <button onClick={logout} className="rounded-full border border-white/10 bg-white/[0.03] px-4 py-1.5 text-xs text-mist/60 transition hover:border-red-400/40 hover:text-red-400">
          Log out
        </button>
      </div>

      <div className="grid gap-5 xl:grid-cols-[1fr_340px]">
        {/* ── Left: settings + keys ── */}
        <div className="space-y-4">

          {/* Script content */}
          <section className="rounded-2xl border border-white/10 bg-void-card p-4">
            <div className="mb-2 flex items-center justify-between">
              <label className="text-xs font-medium text-mist/60">Script contents</label>
              <span className="text-[10px] text-mist/30">served at /script/loader/juru.lua</span>
            </div>
            <textarea value={data.script_content} onChange={(e) => setData({ ...data, script_content: e.target.value })}
              rows={10} spellCheck={false}
              className="w-full resize-none rounded-lg border border-white/10 bg-black/40 p-3.5 font-mono text-xs leading-relaxed text-mist/90 outline-none focus:border-violet-core/60" />
          </section>

          {/* Row: version / status / executors */}
          <section className="grid grid-cols-2 gap-4 rounded-2xl border border-white/10 bg-void-card p-4 sm:grid-cols-4">
            <div>
              <label className="mb-1.5 block text-xs font-medium text-mist/60">Version</label>
              <input value={data.version} onChange={(e) => setData({ ...data, version: e.target.value })}
                className="w-full rounded-lg border border-white/10 bg-black/40 px-3 py-2 font-mono text-sm text-white outline-none focus:border-violet-core/60" />
            </div>
            <div>
              <label className="mb-1.5 block text-xs font-medium text-mist/60">Status</label>
              <StatusDropdown value={data.status} onChange={(v) => setData({ ...data, status: v })} />
            </div>
            <div className="col-span-2">
              <label className="mb-1.5 block text-xs font-medium text-mist/60">Executors (comma-separated)</label>
              <input value={executorsText} onChange={(e) => setExecutorsText(e.target.value)}
                placeholder="Synapse X, Script-Ware, Krnl"
                className="w-full rounded-lg border border-white/10 bg-black/40 px-3 py-2 text-sm text-white outline-none focus:border-violet-core/60" />
            </div>
          </section>

          {/* Row: info / video */}
          <section className="grid grid-cols-1 gap-4 rounded-2xl border border-white/10 bg-void-card p-4 sm:grid-cols-2">
            <div>
              <label className="mb-1.5 block text-xs font-medium text-mist/60">Info / description</label>
              <textarea value={data.info} onChange={(e) => setData({ ...data, info: e.target.value })} rows={3}
                className="w-full resize-none rounded-lg border border-white/10 bg-black/40 p-3 text-sm text-white outline-none focus:border-violet-core/60" />
            </div>
            <div>
              <label className="mb-1.5 block text-xs font-medium text-mist/60">Video URL</label>
              <input value={data.video_url} onChange={(e) => setData({ ...data, video_url: e.target.value })}
                placeholder="https://…/showcase.mp4"
                className="w-full rounded-lg border border-white/10 bg-black/40 px-3 py-2 font-mono text-xs text-white outline-none focus:border-violet-core/60" />
              <p className="mt-2 text-[11px] text-mist/40">Direct .mp4 link — not an iframe.</p>
            </div>
          </section>

          {/* Webhook URL */}
          <section className="rounded-2xl border border-white/10 bg-void-card p-4">
            <label className="mb-1.5 block text-xs font-medium text-mist/60">Discord webhook URL</label>
            <input value={data.webhook_url} onChange={(e) => setData({ ...data, webhook_url: e.target.value })}
              placeholder="https://discord.com/api/webhooks/…"
              className="w-full rounded-lg border border-white/10 bg-black/40 px-3 py-2 font-mono text-xs text-white outline-none focus:border-violet-core/60" />
            <p className="mt-2 text-[11px] text-mist/40">
              Fires once per execution — sends username, IP, key, HWID, executor, and a join link.
            </p>
          </section>

          {/* Key toggle */}
          <section className="flex items-center justify-between gap-4 rounded-2xl border border-white/10 bg-void-card p-4">
            <div>
              <p className="text-xs font-medium text-white">Require a key to run</p>
              <p className="mt-0.5 text-[11px] text-mist/40">
                Off = anyone can run. On = needs a valid key set as <code className="text-mist/60">SCRIPT_KEY</code> before the loadstring.
              </p>
            </div>
            <Toggle checked={data.require_key} onChange={(v) => setData({ ...data, require_key: v })} />
          </section>

          {error && <p className="text-xs text-red-400">{error}</p>}
          <button onClick={save} disabled={saving}
            className="w-full rounded-lg border border-violet-core/40 bg-violet-core/25 py-2.5 text-sm font-medium text-white transition hover:bg-violet-core/40 disabled:opacity-40">
            {saving ? "Saving…" : saved ? "Saved ✓" : "Save changes"}
          </button>

          {/* ── Key management ── */}
          <section className="rounded-2xl border border-white/10 bg-void-card p-4">
            <div className="mb-3 flex items-center justify-between">
              <h2 className="font-display text-sm font-medium text-white">Keys</h2>
              <div className="flex items-center gap-3 text-[11px] text-mist/40">
                <span>{keyStats.total} total</span>
                <span className="text-emerald-400/70">{keyStats.active} active</span>
                <span className="text-red-400/70">{keyStats.expired} expired</span>
                <span className="text-amber-400/70">{keyStats.revoked} revoked</span>
              </div>
            </div>

            {/* Generate */}
            <div className="mb-3 flex flex-wrap items-center gap-2">
              <input value={newKeyLabel} onChange={(e) => setNewKeyLabel(e.target.value)}
                placeholder="Label (optional)"
                className="min-w-0 flex-1 rounded-lg border border-white/10 bg-black/40 px-3 py-1.5 text-sm text-white outline-none focus:border-violet-core/60" />
              <div className="flex gap-1">
                {(["day","week","month","lifetime"] as KeyType[]).map((t) => (
                  <button key={t} onClick={() => setNewKeyType(t)}
                    className={`rounded-lg border px-2.5 py-1.5 text-[11px] font-medium transition ${newKeyType === t ? `${TYPE_META[t].border} ${TYPE_META[t].color}` : "border-white/10 bg-white/[0.03] text-mist/50 hover:text-white"}`}>
                    {TYPE_META[t].label}
                  </button>
                ))}
              </div>
              <button onClick={generateKey} disabled={generatingKey}
                className="rounded-lg border border-violet-core/40 bg-violet-core/25 px-3 py-1.5 text-sm font-medium text-white transition hover:bg-violet-core/40 disabled:opacity-40">
                {generatingKey ? "…" : "Generate"}
              </button>
            </div>

            {/* Filter + search */}
            <div className="mb-3 flex gap-2">
              <input value={keySearch} onChange={(e) => setKeySearch(e.target.value)}
                placeholder="Search key or label…"
                className="min-w-0 flex-1 rounded-lg border border-white/10 bg-black/40 px-3 py-1.5 text-xs text-white outline-none focus:border-violet-core/60" />
              {(["all","active","expired","revoked"] as const).map((f) => (
                <button key={f} onClick={() => setKeyFilter(f)}
                  className={`rounded-lg border px-2.5 py-1.5 text-[11px] capitalize transition ${keyFilter === f ? "border-violet-core/40 bg-violet-core/20 text-white" : "border-white/10 bg-white/[0.03] text-mist/50 hover:text-white"}`}>
                  {f}
                </button>
              ))}
            </div>

            {/* Key list */}
            {!keys ? (
              <p className="py-4 text-center text-xs text-mist/40">Loading…</p>
            ) : filteredKeys.length === 0 ? (
              <p className="py-4 text-center text-xs text-mist/40">No keys match.</p>
            ) : (
              <div className="max-h-72 space-y-2 overflow-y-auto pr-1">
                {filteredKeys.map((k) => {
                  const expired = !!(k.expires_at && new Date(k.expires_at) < new Date());
                  return (
                    <div key={k.id} className={`rounded-lg border px-3 py-2.5 ${k.revoked || expired ? "border-red-400/20 bg-red-400/[0.03] opacity-70" : "border-white/10 bg-black/30"}`}>
                      <div className="flex flex-wrap items-center justify-between gap-2">
                        <div className="flex flex-wrap items-center gap-2">
                          <code className="font-mono text-xs text-white">{k.key_value}</code>
                          <button onClick={() => copyKey(k)}
                            className="rounded border border-white/10 bg-white/[0.03] px-1.5 py-0.5 text-[10px] text-mist/60 hover:text-white">
                            {copiedKeyId === k.id ? "✓" : "Copy"}
                          </button>
                          <span className={`rounded-full border px-2 py-0.5 text-[10px] font-medium ${TYPE_META[k.key_type ?? "lifetime"].border} ${TYPE_META[k.key_type ?? "lifetime"].color}`}>
                            {TYPE_META[k.key_type ?? "lifetime"].label}
                          </span>
                          {k.revoked && <span className="rounded-full border border-red-400/30 bg-red-400/10 px-2 py-0.5 text-[10px] text-red-400">Revoked</span>}
                          {expired && !k.revoked && <span className="rounded-full border border-red-400/30 bg-red-400/10 px-2 py-0.5 text-[10px] text-red-400">Expired</span>}
                          {k.label && <span className="text-[10px] text-mist/40">{k.label}</span>}
                        </div>
                        <div className="flex gap-1">
                          <button onClick={() => keyAction(k.id, "reset-hwid")} disabled={!k.hwid || keyBusyId === k.id}
                            className="rounded border border-white/10 bg-white/[0.03] px-2 py-1 text-[10px] text-mist/60 hover:border-violet-core/50 hover:text-white disabled:opacity-30">
                            Reset HWID
                          </button>
                          <button onClick={() => keyAction(k.id, k.revoked ? "unrevoke" : "revoke")} disabled={keyBusyId === k.id}
                            className="rounded border border-white/10 bg-white/[0.03] px-2 py-1 text-[10px] text-mist/60 hover:border-amber-400/50 hover:text-amber-400 disabled:opacity-30">
                            {k.revoked ? "Unrevoke" : "Revoke"}
                          </button>
                          <button onClick={() => deleteKey(k.id)} disabled={keyBusyId === k.id}
                            className="rounded border border-white/10 bg-white/[0.03] px-2 py-1 text-[10px] text-mist/60 hover:border-red-400/50 hover:text-red-400 disabled:opacity-30">
                            Delete
                          </button>
                        </div>
                      </div>
                      <div className="mt-1.5 flex flex-wrap gap-x-3 text-[10px] text-mist/40">
                        <span>HWID: {k.hwid ? <span className="font-mono text-mist/60">{k.hwid.slice(0,16)}…</span> : <span className="text-emerald-400/70">unlocked</span>}</span>
                        <span>Expires: <span className={expired ? "text-red-400/70" : "text-mist/60"}>{expiresIn(k.expires_at)}</span></span>
                        <span>Created {timeAgo(k.created_at)}</span>
                        <span>Used {timeAgo(k.last_used_at)}</span>
                      </div>
                    </div>
                  );
                })}
              </div>
            )}
          </section>
        </div>

        {/* ── Sidebar ── */}
        <aside className="space-y-4">
          {/* Load stats */}
          <div className="grid grid-cols-2 gap-3">
            <div className="rounded-2xl border border-white/10 bg-void-card p-3.5">
              <p className="text-[10px] text-mist/40">Total loads</p>
              <p className="mt-0.5 font-display text-xl font-semibold text-white">{stats ? stats.total_loads.toLocaleString() : "—"}</p>
            </div>
            <div className="rounded-2xl border border-white/10 bg-void-card p-3.5">
              <p className="text-[10px] text-mist/40">Loads (24h)</p>
              <p className="mt-0.5 font-display text-xl font-semibold text-white">{stats ? stats.loads_last_24h.toLocaleString() : "—"}</p>
            </div>
          </div>

          {/* Test key panel */}
          <div className="rounded-2xl border border-white/10 bg-void-card p-4">
            <div className="mb-3 flex items-center justify-between">
              <h2 className="font-display text-xs font-medium text-white">Test key</h2>
              <span className="rounded-full border border-amber-400/30 bg-amber-400/10 px-2 py-0.5 text-[10px] text-amber-400">1h · one device</span>
            </div>
            <div className="mb-3 flex items-center gap-2">
              <code className="flex-1 truncate rounded-lg border border-white/10 bg-black/40 px-3 py-2 font-mono text-xs text-white">{testKey || "—"}</code>
              <button onClick={copyTestKey} className="shrink-0 rounded-lg border border-violet-core/40 bg-violet-core/20 px-3 py-2 text-[11px] font-medium text-white transition hover:bg-violet-core/35">
                {testKeyCopied ? "✓" : "Copy"}
              </button>
            </div>
            <div className="mb-3 flex gap-2">
              <button onClick={() => testKeyAction("regenerate")} disabled={testKeyBusy}
                className="flex-1 rounded-lg border border-white/10 bg-white/[0.03] py-1.5 text-[11px] text-mist/70 hover:border-violet-core/50 hover:text-white disabled:opacity-40">
                Regenerate
              </button>
              <button onClick={() => { if (confirm("Clear all test key HWID records?")) testKeyAction("clear-hwids"); }} disabled={testKeyBusy}
                className="flex-1 rounded-lg border border-white/10 bg-white/[0.03] py-1.5 text-[11px] text-mist/70 hover:border-red-400/50 hover:text-red-400 disabled:opacity-40">
                Clear HWIDs
              </button>
            </div>
            {testUsages.length === 0 ? (
              <p className="py-2 text-center text-[11px] text-mist/40">No usage yet.</p>
            ) : (
              <div className="max-h-52 space-y-1.5 overflow-y-auto pr-1">
                {testUsages.map((u) => (
                  <div key={u.hwid} className={`flex items-center justify-between gap-2 rounded-lg border px-3 py-2 ${u.expired ? "border-red-400/20 bg-red-400/[0.03]" : "border-white/10 bg-black/30"}`}>
                    <div className="min-w-0">
                      <p className="truncate text-[11px] font-medium text-white">
                        {u.display_name && u.display_name !== u.player_name ? `${u.display_name} (@${u.player_name})` : `@${u.player_name}`}
                      </p>
                      <p className="text-[10px]">
                        {u.expired ? <span className="text-red-400/70">Expired</span> : <span className="text-emerald-400/70">Active</span>}
                        {" · "}{timeAgo(u.first_seen)}
                      </p>
                    </div>
                    <button onClick={() => testKeyAction("remove-hwid", u.hwid)} disabled={testKeyBusy}
                      className="shrink-0 rounded-md border border-white/10 bg-white/[0.03] px-2 py-1 text-[10px] text-mist/50 hover:border-red-400/50 hover:text-red-400 disabled:opacity-40">
                      Remove
                    </button>
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
