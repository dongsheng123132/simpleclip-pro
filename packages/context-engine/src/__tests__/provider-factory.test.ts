import { describe, it } from "node:test";
import assert from "node:assert/strict";
import { createSummaryProvider } from "../provider-factory.js";
import type { LifeClipConfig } from "@lifeclip/shared";

function makeConfig(overrides: Partial<LifeClipConfig["insights"]> = {}): LifeClipConfig {
  return {
    pii: { level: "standard" },
    insights: { provider: "tfidf", ...overrides },
    locale: "zh_CN",
  };
}

describe("createSummaryProvider", () => {
  it("should create TFIDFSummaryProvider for tfidf", () => {
    const provider = createSummaryProvider(makeConfig({ provider: "tfidf" }));
    assert.equal(provider.name, "tfidf");
  });

  it("should create TFIDFSummaryProvider for default/unknown provider", () => {
    const provider = createSummaryProvider(makeConfig());
    assert.equal(provider.name, "tfidf");
  });

  it("should fallback to tfidf when claude-api has no apiKey", () => {
    const provider = createSummaryProvider(makeConfig({ provider: "claude-api" }));
    assert.equal(provider.name, "tfidf");
  });

  it("should create ClaudeAPIProvider when apiKey is provided", () => {
    const provider = createSummaryProvider(makeConfig({ provider: "claude-api", apiKey: "sk-test123" }));
    assert.equal(provider.name, "claude-api");
  });

  it("should create AppleAIProvider for apple-ai", () => {
    const provider = createSummaryProvider(makeConfig({ provider: "apple-ai" }));
    assert.equal(provider.name, "apple-ai");
  });
});
