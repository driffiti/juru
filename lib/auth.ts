// Signed-cookie session helper. Works in both the Node.js and Edge runtimes
// because it only uses the Web Crypto API (no `node:crypto`).

const COOKIE_NAME = "juru_session";
const SESSION_TTL_SECONDS = 60 * 60 * 12; // 12 hours

function getSecret(): string {
  const secret = process.env.SESSION_SECRET;
  if (!secret) {
    throw new Error("SESSION_SECRET is not set");
  }
  return secret;
}

async function hmac(message: string): Promise<string> {
  const key = await crypto.subtle.importKey(
    "raw",
    new TextEncoder().encode(getSecret()),
    { name: "HMAC", hash: "SHA-256" },
    false,
    ["sign"]
  );
  const sig = await crypto.subtle.sign("HMAC", key, new TextEncoder().encode(message));
  return Buffer.from(sig).toString("hex");
}

export async function createSessionToken(): Promise<string> {
  const expires = Date.now() + SESSION_TTL_SECONDS * 1000;
  const payload = `ok.${expires}`;
  const sig = await hmac(payload);
  return `${payload}.${sig}`;
}

export async function verifySessionToken(token: string | undefined | null): Promise<boolean> {
  if (!token) return false;
  const parts = token.split(".");
  if (parts.length !== 3) return false;
  const [flag, expiresStr, sig] = parts;
  const payload = `${flag}.${expiresStr}`;
  const expectedSig = await hmac(payload);
  if (sig !== expectedSig) return false;
  const expires = Number(expiresStr);
  if (Number.isNaN(expires) || Date.now() > expires) return false;
  return flag === "ok";
}

export function checkAdminKey(candidate: string): boolean {
  const real = process.env.ADMIN_KEY;
  if (!real) throw new Error("ADMIN_KEY is not set");
  if (candidate.length !== real.length) return false;
  // constant-time-ish comparison
  let diff = 0;
  for (let i = 0; i < real.length; i++) {
    diff |= candidate.charCodeAt(i) ^ real.charCodeAt(i);
  }
  return diff === 0;
}

export const SESSION_COOKIE_NAME = COOKIE_NAME;
export const SESSION_MAX_AGE = SESSION_TTL_SECONDS;
