import { describe, it } from "node:test";
import assert from "node:assert/strict";
import { TFIDFSummaryProvider } from "../tfidf-summary-provider.js";
import { makeEvent } from "./test-helpers.js";

const provider = new TFIDFSummaryProvider();

describe("TFIDFSummaryProvider", () => {
  describe("generateDailySummary", () => {
    it("should return '无记录' for empty events", async () => {
      const result = await provider.generateDailySummary([], "2026-03-13");
      assert.equal(result, "2026-03-13 无记录。");
    });

    it("should return markdown for events", async () => {
      const events = [
        makeEvent({ content: "react typescript frontend", timestamp: "2026-03-13T10:00:00Z" }),
        makeEvent({ content: "claude ai prompt engineering", timestamp: "2026-03-13T14:00:00Z" }),
      ];
      const result = await provider.generateDailySummary(events, "2026-03-13");
      assert.ok(result.includes("2026-03-13"));
      assert.ok(result.includes("智能洞察") || result.includes("主题"));
    });

    it("should be async", () => {
      const result = provider.generateDailySummary([], "2026-03-13");
      assert.ok(result instanceof Promise);
    });
  });

  describe("generateWeeklySummary", () => {
    it("should return '无记录' for empty events", async () => {
      const result = await provider.generateWeeklySummary([], "2026-03-07", "2026-03-13");
      assert.equal(result, "2026-03-07 ~ 2026-03-13 无记录。");
    });

    it("should return markdown for events", async () => {
      const events = [
        makeEvent({ content: "working on react app", timestamp: "2026-03-10T10:00:00Z" }),
        makeEvent({ content: "deploying to vercel", timestamp: "2026-03-11T14:00:00Z" }),
        makeEvent({ content: "writing typescript tests", timestamp: "2026-03-12T09:00:00Z" }),
      ];
      const result = await provider.generateWeeklySummary(events, "2026-03-07", "2026-03-13");
      assert.ok(result.includes("周度洞察"));
      assert.ok(result.includes("每日活跃度"));
    });

    it("should be async", () => {
      const result = provider.generateWeeklySummary([], "2026-03-07", "2026-03-13");
      assert.ok(result instanceof Promise);
    });
  });
});
