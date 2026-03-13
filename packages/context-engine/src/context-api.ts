import type { TopicNode, PersonalContext } from "@lifeclip/shared";
import { writeLifeClipFile, readLifeClipFile, readEventsRange } from "@lifeclip/shared";
import { buildGraph } from "./graph-builder.js";

const CONTEXT_FILE = "context.json";

/** Generate PersonalContext from recent events */
export function generateContext(options: { days?: number } = {}): PersonalContext {
  const days = options.days ?? 30;
  const now = new Date();
  const start = new Date(now.getTime() - days * 24 * 60 * 60 * 1000);
  const startStr = start.toISOString().slice(0, 10);
  const endStr = now.toISOString().slice(0, 10);

  // Read all events in range
  const events = readEventsRange(startStr, endStr);

  // Build graph
  const graph = buildGraph(events);

  // Count activity by source
  const activity = { clipboard: 0, browser: 0, notes: 0, aiChats: 0 };
  for (const event of events) {
    switch (event.source) {
      case "clipboard": activity.clipboard++; break;
      case "browser": activity.browser++; break;
      case "note": activity.notes++; break;
      case "ai_chat": activity.aiChats++; break;
    }
  }

  // Top topics → active projects and interests
  const topTopics = graph.slice(0, 10);
  const activeProjects = topTopics
    .filter((t) => t.weight > 5)
    .slice(0, 5)
    .map((t) => t.name);
  const interests = topTopics.map((t) => t.name);

  // Generate summary
  const totalEvents = events.length;
  const topTopicNames = topTopics.slice(0, 3).map((t) => t.name);
  const summary =
    totalEvents === 0
      ? "No activity recorded recently."
      : `过去 ${days} 天共 ${totalEvents} 条记录，主要关注: ${topTopicNames.join("、")}`;

  const context: PersonalContext = {
    generatedAt: now.toISOString(),
    recentTopics: topTopics.map((t) => ({
      name: t.name,
      weight: Math.round(t.weight * 100) / 100,
      lastActive: t.lastSeen,
    })),
    activeProjects,
    interests,
    recentActivity: activity,
    summary,
  };

  // Persist
  writeLifeClipFile(CONTEXT_FILE, context);

  return context;
}

/** Load the persisted context */
export function loadContext(): PersonalContext | null {
  return readLifeClipFile<PersonalContext>(CONTEXT_FILE);
}
