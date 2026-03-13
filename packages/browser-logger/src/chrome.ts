import { existsSync, copyFileSync, mkdirSync } from "fs";
import { join } from "path";
import { homedir, tmpdir } from "os";
import Database from "better-sqlite3";
import type { LifeClipEvent } from "@lifeclip/shared";
import { createEvent, sha256, redactURL } from "@lifeclip/shared";
import { categorizeURL } from "./categorizer.js";

const CHROME_HISTORY_PATH = join(
  homedir(),
  "Library/Application Support/Google/Chrome/Default/History"
);

/** Chrome stores timestamps as microseconds since 1601-01-01 */
function chromeTimeToISO(chromeTime: number): string {
  const unixMs = chromeTime / 1000 - 11644473600000;
  return new Date(unixMs).toISOString();
}

export interface CollectOptions {
  since?: string; // ISO date string
  dryRun?: boolean;
}

export function collectChromeHistory(options: CollectOptions = {}): LifeClipEvent[] {
  if (!existsSync(CHROME_HISTORY_PATH)) {
    console.warn("Chrome History DB not found at", CHROME_HISTORY_PATH);
    return [];
  }

  // Copy DB to avoid lock conflicts with running Chrome
  const tmpDir = join(tmpdir(), "lifeclip");
  mkdirSync(tmpDir, { recursive: true });
  const tmpPath = join(tmpDir, "chrome-history-copy");
  copyFileSync(CHROME_HISTORY_PATH, tmpPath);

  const db = new Database(tmpPath, { readonly: true });
  const sinceChrome = options.since
    ? (new Date(options.since).getTime() + 11644473600000) * 1000
    : 0;

  const rows = db.prepare(`
    SELECT v.visit_time, u.url, u.title
    FROM visits v
    JOIN urls u ON v.url = u.id
    WHERE v.visit_time > ?
    ORDER BY v.visit_time ASC
    LIMIT 10000
  `).all(sinceChrome) as Array<{ visit_time: number; url: string; title: string }>;

  db.close();

  const events: LifeClipEvent[] = [];
  for (const row of rows) {
    const url = row.url;
    // Skip internal chrome URLs
    if (url.startsWith("chrome://") || url.startsWith("chrome-extension://")) continue;

    const category = categorizeURL(url);
    const title = row.title || url;
    const cleanURL = redactURL(url);
    const content = `${title} — ${cleanURL}`;

    events.push(
      createEvent({
        source: "browser",
        type: "page_visit",
        timestamp: chromeTimeToISO(row.visit_time),
        content: content.slice(0, 500),
        metadata: {
          url: cleanURL,
          title: row.title,
          category,
          browser: "chrome",
        },
        tags: category ? [category] : [],
      })
    );
  }

  return events;
}
