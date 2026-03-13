import { createHash } from "crypto";
import { readFileSync, appendFileSync, existsSync, mkdirSync, writeFileSync } from "fs";
import { join, dirname } from "path";
import { homedir } from "os";
import { randomUUID } from "crypto";
import type { LifeClipEvent, SyncState } from "./types.js";
import { redactPII, redactMetadata } from "./pii-filter.js";
import { loadConfig } from "./config.js";

const LIFECLIP_DIR = join(homedir(), ".lifeclip");
const EVENTS_DIR = join(LIFECLIP_DIR, "events");
const STATE_FILE = join(LIFECLIP_DIR, "state.json");

export function ensureDirs(): void {
  for (const dir of [LIFECLIP_DIR, EVENTS_DIR]) {
    if (!existsSync(dir)) mkdirSync(dir, { recursive: true });
  }
}

/** Get the JSONL file path for a given date (YYYY-MM-DD) */
export function eventsFilePath(date: string): string {
  return join(EVENTS_DIR, `${date}.jsonl`);
}

/** Append one event to the day's JSONL file (applies PII filtering based on config) */
export function appendEvent(event: LifeClipEvent): void {
  ensureDirs();
  const config = loadConfig();
  const level = config.pii.level;

  if (level !== "off") {
    event = {
      ...event,
      content: redactPII(event.content, level),
      metadata: redactMetadata(event.metadata, level),
      contentHash: sha256(redactPII(event.content, level)),
    };
  }

  const date = event.timestamp.slice(0, 10); // YYYY-MM-DD
  const filePath = eventsFilePath(date);
  appendFileSync(filePath, JSON.stringify(event) + "\n", "utf-8");
}

/** Read all events from a day's JSONL file */
export function readEvents(date: string): LifeClipEvent[] {
  const filePath = eventsFilePath(date);
  if (!existsSync(filePath)) return [];
  const lines = readFileSync(filePath, "utf-8").split("\n").filter(Boolean);
  const events: LifeClipEvent[] = [];
  for (const line of lines) {
    try {
      events.push(JSON.parse(line) as LifeClipEvent);
    } catch {
      // skip malformed lines
    }
  }
  return events;
}

/** Read events for a date range (inclusive) */
export function readEventsRange(startDate: string, endDate: string): LifeClipEvent[] {
  const events: LifeClipEvent[] = [];
  const start = new Date(startDate);
  const end = new Date(endDate);
  for (let d = new Date(start); d <= end; d.setDate(d.getDate() + 1)) {
    const dateStr = d.toISOString().slice(0, 10);
    events.push(...readEvents(dateStr));
  }
  return events;
}

/** SHA-256 hash of content for deduplication */
export function sha256(content: string): string {
  return createHash("sha256").update(content, "utf-8").digest("hex");
}

/** Generate a new event with auto-filled id and hash */
export function createEvent(
  partial: Omit<LifeClipEvent, "id" | "contentHash"> & { contentHash?: string }
): LifeClipEvent {
  return {
    ...partial,
    id: randomUUID(),
    contentHash: partial.contentHash ?? sha256(partial.content),
  };
}

/** Check if an event with this hash already exists in the day file */
export function isDuplicate(date: string, contentHash: string): boolean {
  const events = readEvents(date);
  return events.some((e) => e.contentHash === contentHash);
}

/** Read sync state */
export function readState(): SyncState {
  ensureDirs();
  if (!existsSync(STATE_FILE)) {
    return { lastSync: {}, version: 1 };
  }
  try {
    return JSON.parse(readFileSync(STATE_FILE, "utf-8")) as SyncState;
  } catch {
    return { lastSync: {}, version: 1 };
  }
}

/** Write sync state */
export function writeState(state: SyncState): void {
  ensureDirs();
  writeFileSync(STATE_FILE, JSON.stringify(state, null, 2), "utf-8");
}

/** Write any JSON to ~/.lifeclip/<filename> */
export function writeLifeClipFile(filename: string, data: unknown): void {
  ensureDirs();
  const filePath = join(LIFECLIP_DIR, filename);
  writeFileSync(filePath, JSON.stringify(data, null, 2), "utf-8");
}

/** Read any JSON from ~/.lifeclip/<filename> */
export function readLifeClipFile<T>(filename: string): T | null {
  const filePath = join(LIFECLIP_DIR, filename);
  if (!existsSync(filePath)) return null;
  try {
    return JSON.parse(readFileSync(filePath, "utf-8")) as T;
  } catch {
    return null;
  }
}

export { LIFECLIP_DIR, EVENTS_DIR };
