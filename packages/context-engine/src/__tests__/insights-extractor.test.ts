import { describe, it } from "node:test";
import assert from "node:assert/strict";
import { TFIDFInsightsExtractor } from "../insights-extractor.js";
import { makeEvent } from "./test-helpers.js";

const extractor = new TFIDFInsightsExtractor();

describe("TFIDFInsightsExtractor", () => {
  it("should return correct stats", () => {
    const events = [
      makeEvent({ source: "clipboard" }),
      makeEvent({ source: "clipboard" }),
      makeEvent({ source: "browser", type: "page_visit" }),
    ];
    const insights = extractor.extract(events, "2026-03-13", "daily");
    assert.equal(insights.stats.total, 3);
    assert.equal(insights.stats.bySource.clipboard, 2);
    assert.equal(insights.stats.bySource.browser, 1);
  });

  it("should sort topics by score descending", () => {
    const events = [
      makeEvent({ content: "react nextjs vercel typescript css frontend" }),
      makeEvent({ content: "react typescript vercel" }),
      makeEvent({ content: "claude prompt ai agent" }),
    ];
    const insights = extractor.extract(events, "2026-03-13", "daily");
    assert.ok(insights.topics.length > 0);
    for (let i = 1; i < insights.topics.length; i++) {
      assert.ok(insights.topics[i - 1].percentage >= insights.topics[i].percentage);
    }
  });

  it("should generate time patterns for different periods", () => {
    // Use ISO strings that resolve to morning/afternoon/evening in local time
    // getHours() returns local time, so we construct dates with explicit local hours
    const morning = new Date(2026, 2, 13, 9, 0).toISOString();
    const afternoon = new Date(2026, 2, 13, 14, 0).toISOString();
    const evening = new Date(2026, 2, 13, 20, 0).toISOString();
    const events = [
      makeEvent({ timestamp: morning, source: "clipboard" }),
      makeEvent({ timestamp: afternoon, source: "browser", type: "page_visit" }),
      makeEvent({ timestamp: evening, source: "note", type: "note_edit" }),
    ];
    const insights = extractor.extract(events, "2026-03-13", "daily");
    assert.ok(insights.timePatterns.length > 0);
    const periods = insights.timePatterns.map((p) => p.period);
    assert.ok(periods.some((p) => p.includes("上午")));
    assert.ok(periods.some((p) => p.includes("下午")));
    assert.ok(periods.some((p) => p.includes("晚间")));
  });

  it("should limit transitions to 4", () => {
    const events = [];
    const topics = ["AI Agent", "Web Development", "Blockchain", "Hardware", "Python", "Design"];
    for (let i = 0; i < 12; i++) {
      events.push(
        makeEvent({
          timestamp: `2026-03-13T${String(8 + i).padStart(2, "0")}:00:00Z`,
          topic: topics[i % topics.length],
          tags: [topics[i % topics.length].toLowerCase()],
        })
      );
    }
    const insights = extractor.extract(events, "2026-03-13", "daily");
    assert.ok(insights.transitions.length <= 4);
  });

  it("should handle empty events", () => {
    const insights = extractor.extract([], "2026-03-13", "daily");
    assert.equal(insights.stats.total, 0);
    assert.equal(insights.topics.length, 0);
    assert.equal(insights.timePatterns.length, 0);
  });

  it("should set period correctly", () => {
    const daily = extractor.extract([], "2026-03-13", "daily");
    assert.equal(daily.period, "daily");
    const weekly = extractor.extract([], "2026-03-13", "weekly");
    assert.equal(weekly.period, "weekly");
  });
});
