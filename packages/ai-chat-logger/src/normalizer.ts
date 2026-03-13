import type { LifeClipEvent } from "@lifeclip/shared";

/** Normalize events from different AI platforms to consistent format */
export function normalizeAIChatEvents(events: LifeClipEvent[]): LifeClipEvent[] {
  return events.map((event) => ({
    ...event,
    // Ensure consistent source
    source: "ai_chat" as const,
    // Ensure tags include platform
    tags: [
      ...new Set([
        ...(event.tags ?? []),
        (event.metadata.platform as string) ?? "unknown",
      ]),
    ],
  }));
}
