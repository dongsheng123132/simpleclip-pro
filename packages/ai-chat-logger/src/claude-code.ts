import { readdirSync, readFileSync, existsSync, statSync } from "fs";
import { join } from "path";
import { homedir } from "os";
import type { LifeClipEvent } from "@lifeclip/shared";
import { createEvent, sha256, truncate, redactPII } from "@lifeclip/shared";

const CLAUDE_DIR = join(homedir(), ".claude");
const PROJECTS_DIR = join(CLAUDE_DIR, "projects");

interface ClaudeMessage {
  type: string;
  message?: {
    role: string;
    content: string | Array<{ type: string; text?: string }>;
  };
  timestamp?: string;
  uuid?: string;
}

/** Parse a single JSONL session file into events */
function parseSessionFile(filePath: string): LifeClipEvent[] {
  const events: LifeClipEvent[] = [];
  let content: string;
  try {
    content = readFileSync(filePath, "utf-8");
  } catch {
    return [];
  }

  const lines = content.split("\n").filter(Boolean);
  let sessionStart: string | undefined;
  let userPrompts: string[] = [];
  let assistantResponses = 0;
  let toolCalls = 0;

  for (const line of lines) {
    let msg: ClaudeMessage;
    try {
      msg = JSON.parse(line);
    } catch {
      continue;
    }

    if (!msg.timestamp) continue;
    if (!sessionStart) sessionStart = msg.timestamp;

    if ((msg.type === "human" || msg.type === "user") && msg.message?.role === "user") {
      const text = extractText(msg.message.content);
      if (text) userPrompts.push(text);
    } else if (msg.type === "assistant") {
      assistantResponses++;
      const text = extractText(msg.message?.content);
      // Count tool_use blocks
      if (Array.isArray(msg.message?.content)) {
        toolCalls += msg.message.content.filter(
          (b: any) => b.type === "tool_use"
        ).length;
      }
    }
  }

  if (!sessionStart || userPrompts.length === 0) return [];

  // Create one ai_conversation event per session
  const firstPrompt = userPrompts[0];
  const summary = redactPII(truncate(firstPrompt, 200));
  const sessionId = filePath.split("/").pop()?.replace(".jsonl", "") ?? "unknown";

  events.push(
    createEvent({
      source: "ai_chat",
      type: "ai_conversation",
      timestamp: sessionStart,
      content: `Claude Code: ${summary}`,
      metadata: {
        sessionId,
        filePath,
        promptCount: userPrompts.length,
        responseCount: assistantResponses,
        toolCalls,
        platform: "claude-code",
      },
      tags: ["claude-code"],
    })
  );

  return events;
}

/** Extract text from Claude message content (string or content blocks) */
function extractText(content: string | Array<{ type: string; text?: string }> | undefined): string {
  if (!content) return "";
  if (typeof content === "string") return content;
  if (Array.isArray(content)) {
    return content
      .filter((b) => b.type === "text" && b.text)
      .map((b) => b.text!)
      .join("\n");
  }
  return "";
}

export interface CollectOptions {
  since?: string; // ISO date
}

/** Collect all Claude Code sessions */
export function collectClaudeCodeSessions(options: CollectOptions = {}): LifeClipEvent[] {
  const events: LifeClipEvent[] = [];

  if (!existsSync(PROJECTS_DIR)) {
    console.warn("Claude projects dir not found:", PROJECTS_DIR);
    return [];
  }

  const sinceMs = options.since ? new Date(options.since).getTime() : 0;

  // Scan all project directories
  let projectDirs: string[];
  try {
    projectDirs = readdirSync(PROJECTS_DIR, { withFileTypes: true })
      .filter((d) => d.isDirectory())
      .map((d) => join(PROJECTS_DIR, d.name));
  } catch {
    return [];
  }

  for (const projDir of projectDirs) {
    let files: string[];
    try {
      files = readdirSync(projDir).filter((f) => f.endsWith(".jsonl"));
    } catch {
      continue;
    }

    for (const file of files) {
      const fullPath = join(projDir, file);
      try {
        const stat = statSync(fullPath);
        if (stat.mtimeMs < sinceMs) continue;
      } catch {
        continue;
      }
      events.push(...parseSessionFile(fullPath));
    }
  }

  // Also check global history
  const globalHistory = join(CLAUDE_DIR, "history.jsonl");
  if (existsSync(globalHistory)) {
    // Global history has different format: {display, timestamp, project, sessionId}
    try {
      const content = readFileSync(globalHistory, "utf-8");
      // We don't parse global history into events — it's an index
      // Session files in projects/ have the actual content
    } catch {
      // ignore
    }
  }

  return events;
}
