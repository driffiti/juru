import { sql } from "@/lib/db";

export type KeyType = "day" | "week" | "month" | "lifetime";

export type ScriptKey = {
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

const CHARSET = "ABCDEFGHJKLMNPQRSTUVWXYZ23456789";

function randomSegment(length: number): string {
  let out = "";
  for (let i = 0; i < length; i++) {
    out += CHARSET[Math.floor(Math.random() * CHARSET.length)];
  }
  return out;
}

export function generateKeyValue(): string {
  return `JURU-${randomSegment(4)}-${randomSegment(4)}`;
}

function expiresAt(type: KeyType): Date | null {
  if (type === "lifetime") return null;
  const d = new Date();
  if (type === "day") d.setDate(d.getDate() + 1);
  if (type === "week") d.setDate(d.getDate() + 7);
  if (type === "month") d.setMonth(d.getMonth() + 1);
  return d;
}

export async function createKey(label: string, type: KeyType = "lifetime"): Promise<ScriptKey> {
  const expiry = expiresAt(type);
  for (let attempt = 0; attempt < 3; attempt++) {
    const value = generateKeyValue();
    try {
      const rows = await sql`
        INSERT INTO script_keys (key_value, key_type, label, expires_at)
        VALUES (${value}, ${type}, ${label}, ${expiry})
        RETURNING *
      `;
      return rows[0] as ScriptKey;
    } catch (e) {
      if (attempt === 2) throw e;
    }
  }
  throw new Error("Failed to generate a unique key");
}

export async function listKeys(): Promise<ScriptKey[]> {
  const rows = await sql`SELECT * FROM script_keys ORDER BY created_at DESC`;
  return rows as ScriptKey[];
}

export async function resetHwid(id: number) {
  await sql`UPDATE script_keys SET hwid = NULL WHERE id = ${id}`;
}

export async function setRevoked(id: number, revoked: boolean) {
  await sql`UPDATE script_keys SET revoked = ${revoked} WHERE id = ${id}`;
}

export async function deleteKey(id: number) {
  await sql`DELETE FROM script_keys WHERE id = ${id}`;
}

export async function verifyKey(
  keyValue: string,
  hwid: string
): Promise<{ valid: boolean; reason?: string }> {
  const rows = await sql`SELECT * FROM script_keys WHERE key_value = ${keyValue} LIMIT 1`;
  if (rows.length === 0) return { valid: false, reason: "Invalid key." };

  const key = rows[0] as ScriptKey;

  if (key.revoked) return { valid: false, reason: "This key has been revoked." };

  if (key.expires_at && new Date(key.expires_at) < new Date()) {
    return { valid: false, reason: "This key has expired." };
  }

  if (!key.hwid) {
    await sql`UPDATE script_keys SET hwid = ${hwid}, last_used_at = now() WHERE id = ${key.id}`;
    return { valid: true };
  }

  if (key.hwid !== hwid) {
    return { valid: false, reason: "This key is locked to a different device." };
  }

  await sql`UPDATE script_keys SET last_used_at = now() WHERE id = ${key.id}`;
  return { valid: true };
}
