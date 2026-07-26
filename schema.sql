-- Run this once against your Neon database (Neon SQL editor, or `psql $DATABASE_URL -f schema.sql`)

CREATE TABLE IF NOT EXISTS site_data (
  id INTEGER PRIMARY KEY DEFAULT 1,
  script_content TEXT NOT NULL DEFAULT '-- your script goes here',
  version TEXT NOT NULL DEFAULT '1.0.0',
  status TEXT NOT NULL DEFAULT 'up' CHECK (status IN ('up', 'down', 'maintenance')),
  info TEXT NOT NULL DEFAULT '',
  executors JSONB NOT NULL DEFAULT '[]'::jsonb,
  video_url TEXT NOT NULL DEFAULT '',
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  CONSTRAINT single_row CHECK (id = 1)
);

INSERT INTO site_data (id, script_content, version, status, info, executors, video_url)
VALUES (
  1,
  '-- juru.lol loader\n-- paste your real script here from /admin\nprint("juru.lol loaded")',
  '1.0.0',
  'up',
  'Drop the loadstring into your executor. Updated regularly, monitored around the clock.',
  '["Synapse X", "Script-Ware", "Krnl", "Fluxus"]'::jsonb,
  ''
)
ON CONFLICT (id) DO NOTHING;
