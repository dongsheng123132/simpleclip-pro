import type { LifeClipEvent } from "@lifeclip/shared";

let counter = 0;

export function makeEvent(overrides: Partial<LifeClipEvent> = {}): LifeClipEvent {
  counter++;
  return {
    id: `test-${counter}`,
    source: "clipboard",
    type: "text",
    timestamp: "2026-03-13T10:00:00Z",
    content: "test content",
    metadata: {},
    contentHash: `hash-${counter}`,
    ...overrides,
  };
}
