"use client";

import { useEffect, useState } from "react";
import { useRouter } from "next/navigation";

type ScriptKey = {
  id: number;
  key_value: string;
  hwid: string | null;
  label: string;
  created_at: string;
  last_used_at: string | null;
  revoked: boolean;
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

export default function KeysPage() {
  const router = useRouter();
  const [keys, setKeys] = useState<ScriptKey[] | null>(null);
  const [label, setLabel] = useState("");
  const [generating, setGenerating] = useState(false);
  const [copiedId, setCopiedId] = useState<number | null>(null);
  const [busyId, setBusyId] = useState<number | null>(null);

  function load() {
    fetch("/api/admin/keys")
      .then((r) => {
        if (r.status === 401) {
          router.push("/login");
          return null;
        }
        return r.json();
      })
      .then((d: ScriptKey[] | null) => {
        if (d) setKeys(d);
      });
  }

  useEffect(load, [router]);

  async function generate() {
    setGenerating(true);
    await fetch("/api/admin/keys", {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({ label }),
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
    if (!confirm("Delete this key permanently? This can't be undone.")) return;
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
          ← Back to dashboard
        </a>
      </div>

      {/* Generate */}
      <section className="mb-5 flex items-center gap-3 rounded-2xl border border-white/10 bg-void-card p-4">
        <input
          value={label}
          onChange={(e) => setLabel(e.target.value)}
          placeholder="Optional label (e.g. a buyer's name or order id)"
          className="flex-1 rounded-lg border border-white/10 bg-black/40 px-3 py-2 text-sm text-white outline-none focus:border-violet-core/60"
        />
        <button
          onClick={generate}
          disabled={generating}
          className="shrink-0 rounded-lg border border-violet-core/40 bg-violet-core/25 px-4 py-2 text-sm font-medium text-white transition hover:bg-violet-core/40 disabled:opacity-40"
        >
          {generating ? "Generating…" : "Generate key"}
        </button>
      </section>

      {/* List */}
      <section className="rounded-2xl border border-white/10 bg-void-card p-4">
        {!keys ? (
          <p className="py-6 text-center text-sm text-mist/40">Loading…</p>
        ) : keys.length === 0 ? (
          <p className="py-6 text-center text-sm text-mist/40">
            No keys yet — generate one above.
          </p>
        ) : (
          <div className="space-y-2">
            {keys.map((k) => (
              <div
                key={k.id}
                className={`rounded-lg border px-4 py-3 ${
                  k.revoked ? "border-red-400/20 bg-red-400/[0.03]" : "border-white/10 bg-black/30"
                }`}
              >
                <div className="flex flex-wrap items-center justify-between gap-2">
                  <div className="flex items-center gap-2">
                    <code className="font-mono text-sm text-white">{k.key_value}</code>
                    <button
                      onClick={() => copy(k)}
                      className="rounded-md border border-white/10 bg-white/[0.03] px-2 py-0.5 text-[10px] text-mist/60 transition hover:border-violet-core/50 hover:text-white"
                    >
                      {copiedId === k.id ? "Copied ✓" : "Copy"}
                    </button>
                    {k.revoked && (
                      <span className="rounded-full border border-red-400/30 bg-red-400/10 px-2 py-0.5 text-[10px] text-red-400">
                        Revoked
                      </span>
                    )}
                    {k.label && (
                      <span className="rounded-full border border-white/10 bg-white/[0.03] px-2 py-0.5 text-[10px] text-mist/60">
                        {k.label}
                      </span>
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
                      <span className="font-mono text-mist/60">
                        {k.hwid.length > 16 ? `${k.hwid.slice(0, 16)}…` : k.hwid}
                      </span>
                    ) : (
                      <span className="text-emerald-400/70">unlocked (next use locks it)</span>
                    )}
                  </span>
                  <span>Created {timeAgo(k.created_at)}</span>
                  <span>Last used {timeAgo(k.last_used_at)}</span>
                </div>
              </div>
            ))}
          </div>
        )}
      </section>
    </main>
  );
}
