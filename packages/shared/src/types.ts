/** LifeClipEvent — unified event format for all data sources */
export interface LifeClipEvent {
  id: string;
  source: "clipboard" | "browser" | "note" | "ai_chat";
  type:
    | "text"
    | "url"
    | "image"
    | "page_visit"
    | "note_edit"
    | "note_create"
    | "ai_conversation"
    | "ai_message";
  timestamp: string; // ISO 8601
  content: string; // summary, not full text
  metadata: Record<string, unknown>;
  tags?: string[];
  topic?: string;
  contentHash: string; // SHA-256
}

/** TopicNode — a node in the Context Graph */
export interface TopicNode {
  name: string;
  weight: number;
  sources: {
    clipboard: number;
    browser: number;
    note: number;
    ai_chat: number;
  };
  recentEvents: string[]; // last 5 event IDs
  firstSeen: string;
  lastSeen: string;
}

/** PersonalContext — AI-readable personal context */
export interface PersonalContext {
  generatedAt: string;
  recentTopics: Array<{
    name: string;
    weight: number;
    lastActive: string;
  }>;
  activeProjects: string[];
  interests: string[];
  recentActivity: {
    clipboard: number;
    browser: number;
    notes: number;
    aiChats: number;
  };
  summary: string;
}

/** SyncState — tracks last sync per source */
export interface SyncState {
  lastSync: Record<string, string>; // source -> ISO timestamp
  version: number;
}

export type EventSource = LifeClipEvent["source"];
export type EventType = LifeClipEvent["type"];
