import type { LifeClipEvent, TopicNode } from "@lifeclip/shared";
import { writeLifeClipFile, readLifeClipFile } from "@lifeclip/shared";
import { extractTopics, assignTopic } from "./topic-extractor.js";

const GRAPH_FILE = "graph.json";

/** Time decay factor — recent events weight more */
function timeDecay(eventTimestamp: string, now: Date): number {
  const diffMs = now.getTime() - new Date(eventTimestamp).getTime();
  const diffDays = diffMs / (1000 * 60 * 60 * 24);
  // Exponential decay: half-life of 7 days
  return Math.exp(-0.693 * diffDays / 7);
}

/** Build the Context Graph from events */
export function buildGraph(events: LifeClipEvent[]): TopicNode[] {
  const now = new Date();
  const topicMap = new Map<string, TopicNode>();

  // Assign topics to events
  for (const event of events) {
    const topic = event.topic ?? assignTopic(event);
    if (!topic) continue;

    let node = topicMap.get(topic);
    if (!node) {
      node = {
        name: topic,
        weight: 0,
        sources: { clipboard: 0, browser: 0, note: 0, ai_chat: 0 },
        recentEvents: [],
        firstSeen: event.timestamp,
        lastSeen: event.timestamp,
      };
      topicMap.set(topic, node);
    }

    // Update weight with time decay
    node.weight += timeDecay(event.timestamp, now);

    // Update source counts
    node.sources[event.source]++;

    // Track recent events (keep last 5)
    node.recentEvents.push(event.id);
    if (node.recentEvents.length > 5) {
      node.recentEvents = node.recentEvents.slice(-5);
    }

    // Update timestamps
    if (event.timestamp < node.firstSeen) node.firstSeen = event.timestamp;
    if (event.timestamp > node.lastSeen) node.lastSeen = event.timestamp;
  }

  // Sort by weight descending
  const nodes = [...topicMap.values()].sort((a, b) => b.weight - a.weight);

  // Persist
  writeLifeClipFile(GRAPH_FILE, nodes);

  return nodes;
}

/** Load the persisted graph */
export function loadGraph(): TopicNode[] {
  return readLifeClipFile<TopicNode[]>(GRAPH_FILE) ?? [];
}
