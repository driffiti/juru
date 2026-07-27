import { sql } from "@/lib/db";

export type ScriptKey = {
  id: number;
  key_value: string;
  hwid: string | null;
  label: string;
  created_at: string;
  last_used_at: string | null;
  revoked: boolean;
};

// Excludes visually-ambiguous characters (0/O, 1/I) so keys are easy to
// read and type out by hand if needed.
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

export async function createKey(label: string): Promise<ScriptKey> {
  // Extremely unlikely to collide, but retry once just in case.
  for (let attempt = 0; attempt < 3; attempt++) {
    const value = generateKeyValue();
    try {
      const rows = await sql`
        INSERT INTO script_keys (key_value, label)
        VALUES (${value}, ${label})
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
  if (rows.length === 0) {
    return { valid: false, reason: "Invalid key." };
  }
  const key = rows[0] as ScriptKey;

  if (key.revoked) {
    return { valid: false, reason: "This key has been revoked." };
  }

  if (!key.hwid) {
    // First use — lock the key to this device.
    await sql`UPDATE script_keys SET hwid = ${hwid}, last_used_at = now() WHERE id = ${key.id}`;
    return { valid: true };
  }

  if (key.hwid !== hwid) {
    return { valid: false, reason: "This key is locked to a different device." };
  }

  await sql`UPDATE script_keys SET last_used_at = now() WHERE id = ${key.id}`;
  return { valid: true };
}
