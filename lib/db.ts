import { neon } from "@neondatabase/serverless";

// Reuses the same connection string across invocations.
// Set DATABASE_URL in your Vercel project settings (Neon gives you this
// connection string when you create a database).
const sql = neon(process.env.DATABASE_URL!);

export type SiteData = {
  id: number;
  script_content: string;
  version: string;
  status: "up" | "down" | "maintenance";
  info: string;
  executors: string[]; // e.g. ["Synapse X", "Script-Ware", "Krnl"]
  video_url: string;
  require_key: boolean;
  updated_at: string;
};

const ROW_ID = 1;

export async function getSiteData(): Promise<SiteData> {
  const rows = await sql`SELECT * FROM site_data WHERE id = ${ROW_ID}`;
  if (rows.length === 0) {
    throw new Error(
      "No site_data row found. Run the seed script (npm run seed) after creating the schema."
    );
  }
  const row = rows[0] as any;
  return {
    ...row,
    executors: row.executors ?? [],
    require_key: !!row.require_key,
  };
}

export async function updateSiteData(
  patch: Partial<
    Pick<
      SiteData,
      | "script_content"
      | "version"
      | "status"
      | "info"
      | "executors"
      | "video_url"
      | "require_key"
    >
  >
): Promise<SiteData> {
  const current = await getSiteData();
  const next = { ...current, ...patch };

  const rows = await sql`
    UPDATE site_data
    SET
      script_content = ${next.script_content},
      version = ${next.version},
      status = ${next.status},
      info = ${next.info},
      executors = ${JSON.stringify(next.executors)}::jsonb,
      video_url = ${next.video_url},
      require_key = ${next.require_key},
      updated_at = now()
    WHERE id = ${ROW_ID}
    RETURNING *
  `;
  const row = rows[0] as any;
  return { ...row, executors: row.executors ?? [], require_key: !!row.require_key };
}

export { sql };
