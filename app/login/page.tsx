"use client";

import { useState } from "react";
import { useRouter } from "next/navigation";

export default function LoginPage() {
  const router = useRouter();
  const [key, setKey] = useState("");
  const [error, setError] = useState("");
  const [loading, setLoading] = useState(false);

  async function handleSubmit(e: React.FormEvent) {
    e.preventDefault();
    setError("");
    setLoading(true);
    const res = await fetch("/api/admin/login", {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({ key }),
    });
    setLoading(false);
    if (res.ok) {
      router.push("/admin");
    } else {
      setError("That key isn't right.");
    }
  }

  return (
    <main className="flex min-h-screen items-center justify-center px-6">
      <form
        onSubmit={handleSubmit}
        className="w-full max-w-sm rounded-2xl border border-white/10 bg-void-card p-7 shadow-glow"
      >
        <div className="mb-6 text-center">
          <span className="font-display text-lg font-semibold text-white">
            juru<span className="text-violet-glow">.lol</span>
          </span>
          <p className="mt-1 text-xs text-mist/50">Admin access</p>
        </div>

        <label className="mb-2 block text-xs font-medium text-mist/60">Access key</label>
        <input
          type="password"
          value={key}
          onChange={(e) => setKey(e.target.value)}
          maxLength={16}
          autoFocus
          placeholder="16-character key"
          className="mb-4 w-full rounded-lg border border-white/10 bg-white/[0.03] px-3.5 py-2.5 font-mono text-sm text-white placeholder:text-mist/30 outline-none focus:border-violet-core/60"
        />

        {error && <p className="mb-4 text-xs text-red-400">{error}</p>}

        <button
          type="submit"
          disabled={loading || key.length === 0}
          className="w-full rounded-lg border border-violet-core/40 bg-violet-core/25 py-2.5 text-sm font-medium text-white transition hover:bg-violet-core/40 disabled:cursor-not-allowed disabled:opacity-40"
        >
          {loading ? "Checking…" : "Sign in"}
        </button>

        <a
          href="/"
          className="mt-4 block text-center text-xs text-mist/40 transition hover:text-mist/70"
        >
          ← Back to site
        </a>
      </form>
    </main>
  );
}
