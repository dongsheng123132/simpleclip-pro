import { existsSync, copyFileSync, mkdirSync } from "fs";
import { join } from "path";
import { homedir, tmpdir } from "os";
import Database from "better-sqlite3";
import type { LifeClipEvent } from "@lifeclip/shared";
import { createEvent, redactURL } from "@lifeclip/shared";
import { categorizeURL } from "./categorizer.js";

const SAFARI_HISTORY_PATH = join(
  homedir(),
  "Library/Safari/History.db"
);

/** Safari stores timestamps as seconds since 2001-01-01 (Core Data epoch) */
function safariTimeToISO(safariTime: number): string {
  const unixMs = (safariTime + 978307200) * 1000;
  return new Date(unixMs).toISOString();
}

export function collectSafariHistory(options: { since?: string } = {}): LifeClipEvent[] {
  if (!existsSync(SAFARI_HISTORY_PATH)) {
    console.warn("Safari History DB not found. Full Disk Access may be required.");
    return [];
  }

  const tmpDir = join(tmpdir(), "lifeclip");
  mkdirSync(tmpDir, { recursive: true });
  const tmpPath = join(tmpDir, "safari-history-copy");

  try {
    copyFileSync(SAFARI_HISTORY_PATH, tmpPath);
  } catch {
    console.warn("Cannot copy Safari History DB. Grant Full Disk Access to Terminal.");
    return [];
  }

  const db = new Database(tmpPath, { readonly: true });
  const sinceCore = options.since
    ? (new Date(options.since).getTime() / 1000 - 978307200)
    : 0;

  const rows = db.prepare(`
    SELECT hv.visit_time, hi.url, hv.title
    FROM history_visits hv
    JOIN history_items hi ON hv.history_item = hi.id
    WHERE hv.visit_time > ?
    ORDER BY hv.visit_time ASC
    LIMIT 10000
  `).all(sinceCore) as Array<{ visit_time: number; url: string; title: string }>;

  db.close();

  const events: LifeClipEvent[] = [];
  for (const row of rows) {
    const url = row.url;
    if (url.startsWith("x-apple") || url.startsWith("about:")) continue;

    const category = categorizeURL(url);
    const title = row.title || url;
    const cleanURL = redactURL(url);
    const content = `${title} — ${cleanURL}`;

    events.push(
      createEvent({
        source: "browser",
        type: "page_visit",
        timestamp: safariTimeToISO(row.visit_time),
        content: content.slice(0, 500),
        metadata: {
          url: cleanURL,
          title: row.title,
          category,
          browser: "safari",
        },
        tags: category ? [category] : [],
      })
    );
  }

  return events;
}
