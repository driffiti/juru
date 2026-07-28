// Stateless time-bound nonce using SESSION_SECRET + HMAC.
// The nonce changes every 30s (one "bucket"). We accept the current and
// the previous bucket so a nonce is valid for up to ~60s from when the
// loader was fetched — enough time for the Lua to call /api/unlock right
// after loading, but not enough for a cached curl replay later on.

function getSecret(): string {
  const s = process.env.SESSION_SECRET;
  if (!s) throw new Error("SESSION_SECRET is not set");
  return s;
}

async function bucketSig(bucket: number): Promise<string> {
  const key = await crypto.subtle.importKey(
    "raw",
    new TextEncoder().encode(getSecret()),
    { name: "HMAC", hash: "SHA-256" },
    false,
    ["sign"]
  );
  const sig = await crypto.subtle.sign(
    "HMAC",
    key,
    new TextEncoder().encode(`nonce:${bucket}`)
  );
  // 16 hex chars (64 bits) — enough for our purposes.
  return Buffer.from(sig).toString("hex").slice(0, 16);
}

export async function generateNonce(): Promise<string> {
  const bucket = Math.floor(Date.now() / 30000);
  const sig = await bucketSig(bucket);
  return `${bucket}.${sig}`;
}

export async function verifyNonce(nonce: string | undefined | null): Promise<boolean> {
  if (!nonce || typeof nonce !== "string") return false;
  const parts = nonce.split(".");
  if (parts.length !== 2) return false;
  const [bucketStr, sig] = parts;
  const bucket = Number(bucketStr);
  if (!Number.isFinite(bucket)) return false;

  const currentBucket = Math.floor(Date.now() / 30000);
  // Accept current bucket and the one before it (up to ~60s window).
  if (bucket !== currentBucket && bucket !== currentBucket - 1) return false;

  const expectedSig = await bucketSig(bucket);
  return sig === expectedSig;
}
