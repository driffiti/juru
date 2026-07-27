import { sql } from "@/lib/db";

const TEST_KEY_WINDOW_MS = 60 * 60 * 1000; // 1 hour

export type TestKeyUsage = {
  hwid: string;
  first_seen: string;
  expired: boolean;
};

export async function verifyTestKey(
  hwid: string
): Promise<{ valid: boolean; reason?: string }> {
  // Check if this HWID has ever used the test key before.
  const rows = await sql`SELECT * FROM test_key_hwids WHERE hwid = ${hwid} LIMIT 1`;

  if (rows.length === 0) {
    // First time — record them and grant access.
    await sql`INSERT INTO test_key_hwids (hwid, first_seen) VALUES (${hwid}, now())`;
    return { valid: true };
  }

  const firstSeen = new Date(rows[0].first_seen as string);
  const elapsed = Date.now() - firstSeen.getTime();

  if (elapsed > TEST_KEY_WINDOW_MS) {
    // Hour is up — permanently blocked, even if the test key value changes.
    return { valid: false, reason: "Your test access has expired." };
  }

  return { valid: true };
}

export async function generateTestKey(): Promise<string> {
  // Generates a new key value and stores it. Does NOT clear the HWID table
  // because we still want expired testers to stay blocked.
  const charset = "ABCDEFGHJKLMNPQRSTUVWXYZ23456789";
  function seg(n: number) {
    let s = "";
    for (let i = 0; i < n; i++) s += charset[Math.floor(Math.random() * charset.length)];
    return s;
  }
  return `JURU-TEST-${seg(4)}-${seg(4)}`;
}

export async function listTestKeyUsages(): Promise<TestKeyUsage[]> {
  const rows = await sql`SELECT * FROM test_key_hwids ORDER BY first_seen DESC`;
  return (rows as any[]).map((r) => ({
    hwid: r.hwid,
    first_seen: r.first_seen,
    expired: Date.now() - new Date(r.first_seen).getTime() > TEST_KEY_WINDOW_MS,
  }));
}

export async function clearTestKeyHwids() {
  await sql`DELETE FROM test_key_hwids`;
}

export async function removeTestKeyHwid(hwid: string) {
  await sql`DELETE FROM test_key_hwids WHERE hwid = ${hwid}`;
}
