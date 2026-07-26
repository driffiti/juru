// Applies schema.sql against DATABASE_URL. Run with: npm run seed
// (make sure DATABASE_URL is set in your shell, or in a .env file loaded some other way)
import { neon } from "@neondatabase/serverless";
import { readFileSync } from "node:fs";
import { fileURLToPath } from "node:url";
import path from "node:path";

const __dirname = path.dirname(fileURLToPath(import.meta.url));

if (!process.env.DATABASE_URL) {
  console.error("DATABASE_URL is not set. Export it first, e.g.:\n  export DATABASE_URL=postgres://...");
  process.exit(1);
}

const sql = neon(process.env.DATABASE_URL);
const schema = readFileSync(path.join(__dirname, "..", "schema.sql"), "utf8");

// naive statement split is fine here since schema.sql has no semicolons inside strings
const statements = schema
  .split(";")
  .map((s) => s.trim())
  .filter(Boolean);

for (const statement of statements) {
  await sql(statement);
}

console.log("✓ schema applied and default row seeded");
