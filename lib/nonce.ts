// Stateless time-bound nonce using SESSION_SECRET + HMAC.
// Rotates every 5 seconds; accepts current and previous bucket (~10s window).
// IP-binding was removed because game:HttpGet and http_request in Roblox
// often route through different infrastructure IPs, causing false rejections.

function getSecret(): string {
  const s = process.env.SESSION_SECRET;
  if (!s) throw new Error("SESSION_SECRET is not set");
  return s;
}

async function sign(message: string): Promise<string> {
  const key = await crypto.subtle.importKey(
    "raw", new TextEncoder().encode(getSecret()),
    { name: "HMAC", hash: "SHA-256" }, false, ["sign"]
  );
  const sig = await crypto.subtle.sign("HMAC", key, new TextEncoder().encode(message));
  return Buffer.from(sig).toString("hex").slice(0, 8);
}

export async function generateNonce(): Promise<string> {
  const bucket = Math.floor(Date.now() / 5000);
  const sig = await sign(`nonce:${bucket}`);
  return `${bucket}.${sig}`;
}

export async function verifyNonce(nonce: string | undefined | null): Promise<boolean> {
  if (!nonce || typeof nonce !== "string") return false;
  const parts = nonce.split(".");
  if (parts.length !== 2) return false;
  const [bucketStr, sig] = parts;
  const bucket = Number(bucketStr);
  if (!Number.isFinite(bucket)) return false;
  const currentBucket = Math.floor(Date.now() / 5000);
  if (bucket !== currentBucket && bucket !== currentBucket - 1) return false;
  const expectedSig = await sign(`nonce:${bucket}`);
  return sig === expectedSig;
}
