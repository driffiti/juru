"use client";

import { useEffect, useState } from "react";
import { useRouter } from "next/navigation";

type KeyType = "day" | "week" | "month" | "lifetime";

type ScriptKey = {
  id: number;
  key_value: string;
  key_type: KeyType;
  hwid: string | null;
  label: string;
  created_at: string;
  expires_at: string | null;
  last_used_at: string | null;
  revoked: boolean;
};

const TYPE_META: Record<KeyType, { label: string; color: string; border: string }> = {
  day:      { label: "1 Day",    color: "text-sky-400",    border: "border-sky-400/30 bg-sky-400/10" },
  week:     { label: "1 Week",   color: "text-violet-400", border: "border-violet-400/30 bg-violet-400/10" },
  month:    { label: "1 Month",  color: "text-amber-400",  border: "border-amber-400/30 bg-amber-400/10" },
  lifetime: { label: "Lifetime", color: "text-emerald-400", border: "border-emerald-400/30 bg-emerald-400/10" },
};

function timeAgo(iso: string | null): string {
  if (!iso) return "never";
  const seconds = Math.max(0, Math.floor((Date.now() - new Date(iso).getTime()) / 1000));
  if (seconds < 60) return `${seconds}s ago`;
  const minutes = Math.floor(seconds / 60);
  if (minutes < 60) return `${minutes}m ago`;
  const hours = Math.floor(minutes / 60);
  if (hours < 24) return `${hours}h ago`;
  return `${Math.floor(hours / 24)}d ago`;
}

function expiresIn(iso: string | null): string {
  if (!iso) return "Never";
  const ms = new Date(iso).getTime() - Date.now();
  if (ms <= 0) return "Expired";
  const minutes = Math.floor(ms / 60000);
  if (minutes < 60) return `${minutes}m`;
  const hours = Math.floor(minutes / 60);
  if (hours < 24) return `${hours}h`;
  return `${Math.floor(hours / 24)}d`;
}

function isExpired(iso: string | null): boolean {
  if (!iso) return false;
  return new Date(iso).getTime() < Date.now();
}

export default function KeysPage() {
  const router = useRouter();
  const [keys, setKeys] = useState<ScriptKey[] | null>(null);
  const [label, setLabel] = useState("");
  const [type, setType] = useState<KeyType>("lifetime");
  const [generating, setGenerating] = useState(false);
  const [copiedId, setCopiedId] = useState<number | null>(null);
  const [busyId, setBusyId] = useState<number | null>(null);

  function load() {
    fetch("/api/admin/keys")
      .then((r) => {
        if (r.status === 401) { router.push("/login"); return null; }
        return r.json();
      })
      .then((d: ScriptKey[] | null) => { if (d) setKeys(d); });
  }

  useEffect(load, [router]);

  async function generate() {
    setGenerating(true);
    await fetch("/api/admin/keys", {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({ label, type }),
    });
    setLabel("");
    setGenerating(false);
    load();
  }

  async function act(id: number, action: "reset-hwid" | "revoke" | "unrevoke") {
    setBusyId(id);
    await fetch(`/api/admin/keys/${id}`, {
      method: "PATCH",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({ action }),
    });
    setBusyId(null);
    load();
  }

  async function remove(id: number) {
    if (!confirm("Delete this key permanently?")) return;
    setBusyId(id);
    await fetch(`/api/admin/keys/${id}`, { method: "DELETE" });
    setBusyId(null);
    load();
  }

  function copy(key: ScriptKey) {
    navigator.clipboard.writeText(key.key_value).then(() => {
      setCopiedId(key.id);
      setTimeout(() => setCopiedId(null), 1500);
    });
  }

  const expired = (k: ScriptKey) => isExpired(k.expires_at);

  return (
    <main className="mx-auto min-h-screen max-w-4xl px-6 py-8">
      <div className="mb-6 flex items-center justify-between">
        <span className="font-display text-lg font-semibold text-white">
          juru<span className="text-violet-glow">.lol</span>{" "}
          <span className="text-mist/40">/ admin / keys</span>
        </span>
        <a
          href="/admin"
          className="rounded-full border border-white/10 bg-white/[0.03] px-4 py-1.5 text-xs text-mist/60 transition hover:border-violet-core/50 hover:text-white"
        >
          ← Back
        </a>
      </div>

      {/* Generate */}
      <section className="mb-5 rounded-2xl border border-white/10 bg-void-card p-4">
        <div className="flex flex-wrap items-center gap-3">
          <input
            value={label}
            onChange={(e) => setLabel(e.target.value)}
            placeholder="Label (e.g. buyer name or order id)"
            className="min-w-0 flex-1 rounded-lg border border-white/10 bg-black/40 px-3 py-2 text-sm text-white outline-none focus:border-violet-core/60"
          />
          {/* Type selector */}
          <div className="flex gap-1.5">
            {(["day", "week", "month", "lifetime"] as KeyType[]).map((t) => (
              <button
                key={t}
                onClick={() => setType(t)}
                className={`rounded-lg border px-3 py-2 text-xs font-medium transition ${
                  type === t
                    ? `${TYPE_META[t].border} ${TYPE_META[t].color}`
                    : "border-white/10 bg-white/[0.03] text-mist/50 hover:text-white"
                }`}
              >
                {TYPE_META[t].label}
              </button>
            ))}
          </div>
          <button
            onClick={generate}
            disabled={generating}
            className="shrink-0 rounded-lg border border-violet-core/40 bg-violet-core/25 px-4 py-2 text-sm font-medium text-white transition hover:bg-violet-core/40 disabled:opacity-40"
          >
            {generating ? "Generating…" : "Generate"}
          </button>
        </div>
      </section>

      {/* List */}
      <section className="rounded-2xl border border-white/10 bg-void-card p-4">
        {!keys ? (
          <p className="py-6 text-center text-sm text-mist/40">Loading…</p>
        ) : keys.length === 0 ? (
          <p className="py-6 text-center text-sm text-mist/40">No keys yet — generate one above.</p>
        ) : (
          <div className="space-y-2">
            {keys.map((k) => {
              const exp = expired(k);
              return (
                <div
                  key={k.id}
                  className={`rounded-lg border px-4 py-3 ${
                    k.revoked || exp
                      ? "border-red-400/20 bg-red-400/[0.03] opacity-70"
                      : "border-white/10 bg-black/30"
                  }`}
                >
                  <div className="flex flex-wrap items-center justify-between gap-2">
                    <div className="flex flex-wrap items-center gap-2">
                      <code className="font-mono text-sm text-white">{k.key_value}</code>
                      <button
                        onClick={() => copy(k)}
                        className="rounded-md border border-white/10 bg-white/[0.03] px-2 py-0.5 text-[10px] text-mist/60 transition hover:border-violet-core/50 hover:text-white"
                      >
                        {copiedId === k.id ? "Copied ✓" : "Copy"}
                      </button>
                      {/* Type badge */}
                      <span className={`rounded-full border px-2 py-0.5 text-[10px] font-medium ${TYPE_META[k.key_type ?? "lifetime"].border} ${TYPE_META[k.key_type ?? "lifetime"].color}`}>
                        {TYPE_META[k.key_type ?? "lifetime"].label}
                      </span>
                      {k.revoked && (
                        <span className="rounded-full border border-red-400/30 bg-red-400/10 px-2 py-0.5 text-[10px] text-red-400">Revoked</span>
                      )}
                      {exp && !k.revoked && (
                        <span className="rounded-full border border-red-400/30 bg-red-400/10 px-2 py-0.5 text-[10px] text-red-400">Expired</span>
                      )}
                      {k.label && (
                        <span className="rounded-full border border-white/10 bg-white/[0.03] px-2 py-0.5 text-[10px] text-mist/60">{k.label}</span>
                      )}
                    </div>

                    <div className="flex items-center gap-1.5">
                      <button
                        onClick={() => act(k.id, "reset-hwid")}
                        disabled={busyId === k.id || !k.hwid}
                        className="rounded-md border border-white/10 bg-white/[0.03] px-2.5 py-1 text-[11px] text-mist/70 transition hover:border-violet-core/50 hover:text-white disabled:opacity-30"
                      >
                        Reset HWID
                      </button>
                      <button
                        onClick={() => act(k.id, k.revoked ? "unrevoke" : "revoke")}
                        disabled={busyId === k.id}
                        className="rounded-md border border-white/10 bg-white/[0.03] px-2.5 py-1 text-[11px] text-mist/70 transition hover:border-amber-400/50 hover:text-amber-400 disabled:opacity-30"
                      >
                        {k.revoked ? "Unrevoke" : "Revoke"}
                      </button>
                      <button
                        onClick={() => remove(k.id)}
                        disabled={busyId === k.id}
                        className="rounded-md border border-white/10 bg-white/[0.03] px-2.5 py-1 text-[11px] text-mist/70 transition hover:border-red-400/50 hover:text-red-400 disabled:opacity-30"
                      >
                        Delete
                      </button>
                    </div>
                  </div>

                  <div className="mt-2 flex flex-wrap gap-x-4 gap-y-1 text-[11px] text-mist/40">
                    <span>
                      HWID:{" "}
                      {k.hwid ? (
                        <span className="font-mono text-mist/60">{k.hwid.length > 16 ? `${k.hwid.slice(0, 16)}…` : k.hwid}</span>
                      ) : (
                        <span className="text-emerald-400/70">unlocked</span>
                      )}
                    </span>
                    <span>
                      Expires:{" "}
                      <span className={exp ? "text-red-400/70" : "text-mist/60"}>
                        {expiresIn(k.expires_at)}
                      </span>
                    </span>
                    <span>Created {timeAgo(k.created_at)}</span>
                    <span>Last used {timeAgo(k.last_used_at)}</span>
                  </div>
                </div>
              );
            })}
          </div>
        )}
      </section>
    </main>
  );
}
