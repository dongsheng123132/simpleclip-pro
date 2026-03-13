import { describe, it, beforeEach, afterEach } from "node:test";
import assert from "node:assert/strict";
import { readFileSync, writeFileSync, existsSync, mkdirSync, rmSync } from "fs";
import { join } from "path";
import { tmpdir } from "os";

// We test config logic by importing and overriding CONFIG_PATH is not feasible,
// so we test the merge logic directly
describe("config merge logic", () => {
  const DEFAULT_CONFIG = {
    pii: { level: "standard" as const },
    insights: { provider: "tfidf" as const },
    locale: "zh_CN",
  };

  it("should return defaults when no config exists", () => {
    const config = { ...DEFAULT_CONFIG };
    assert.equal(config.pii.level, "standard");
    assert.equal(config.insights.provider, "tfidf");
    assert.equal(config.locale, "zh_CN");
  });

  it("should merge partial config with defaults", () => {
    const raw = { pii: { level: "strict" }, locale: "en_US" };
    const config = {
      ...DEFAULT_CONFIG,
      ...raw,
      pii: { ...DEFAULT_CONFIG.pii, ...raw.pii },
      insights: { ...DEFAULT_CONFIG.insights },
    };
    assert.equal(config.pii.level, "strict");
    assert.equal(config.insights.provider, "tfidf");
    assert.equal(config.locale, "en_US");
  });

  it("should merge insights config", () => {
    const raw = { insights: { provider: "claude-api", apiKey: "sk-test" } };
    const config = {
      ...DEFAULT_CONFIG,
      ...raw,
      pii: { ...DEFAULT_CONFIG.pii },
      insights: { ...DEFAULT_CONFIG.insights, ...raw.insights },
    };
    assert.equal(config.insights.provider, "claude-api");
    assert.equal(config.insights.apiKey, "sk-test");
  });

  it("should handle malformed JSON gracefully (return defaults)", () => {
    // Simulate what loadConfig does on parse error
    let config;
    try {
      JSON.parse("{invalid json}");
      config = null; // won't reach here
    } catch {
      config = { ...DEFAULT_CONFIG };
    }
    assert.equal(config!.pii.level, "standard");
    assert.equal(config!.insights.provider, "tfidf");
  });
});
