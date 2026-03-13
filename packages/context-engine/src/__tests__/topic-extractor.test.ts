import { describe, it } from "node:test";
import assert from "node:assert/strict";
import { stripURLs, isValidToken, tokenize, extractTopics, assignTopic } from "../topic-extractor.js";
import { makeEvent } from "./test-helpers.js";

describe("stripURLs", () => {
  it("should remove HTTP URLs", () => {
    const result = stripURLs("visit http://example.com for more");
    assert.ok(!result.includes("http://"));
    assert.ok(result.includes("visit"));
    assert.ok(result.includes("for more"));
  });

  it("should remove HTTPS URLs", () => {
    const result = stripURLs("see https://github.com/repo/issues/123");
    assert.ok(!result.includes("https://"));
    assert.ok(result.includes("see"));
  });

  it("should handle text with no URLs", () => {
    assert.equal(stripURLs("no urls here"), "no urls here");
  });

  it("should remove multiple URLs", () => {
    const result = stripURLs("a https://x.com b http://y.com c");
    assert.ok(!result.includes("https://"));
    assert.ok(!result.includes("http://"));
  });
});

describe("isValidToken", () => {
  it("should reject single-character tokens", () => {
    assert.equal(isValidToken("a"), false);
    assert.equal(isValidToken("x"), false);
  });

  it("should reject pure numbers", () => {
    assert.equal(isValidToken("123"), false);
    assert.equal(isValidToken("42"), false);
  });

  it("should reject hex fragments", () => {
    assert.equal(isValidToken("a2b"), false);
    assert.equal(isValidToken("ff00"), false);
    assert.equal(isValidToken("3def"), false);
    // "3fi" contains 'i' which is not hex, so it passes
    assert.equal(isValidToken("3fi"), true);
  });

  it("should accept valid words", () => {
    assert.equal(isValidToken("react"), true);
    assert.equal(isValidToken("typescript"), true);
    assert.equal(isValidToken("claude"), true);
  });

  it("should accept Chinese words", () => {
    assert.equal(isValidToken("剪贴板"), true);
    assert.equal(isValidToken("智能体"), true);
  });
});

describe("tokenize", () => {
  it("should lowercase and split text", () => {
    const tokens = tokenize("React TypeScript NextJS");
    assert.ok(tokens.includes("react"));
    assert.ok(tokens.includes("typescript"));
    assert.ok(tokens.includes("nextjs"));
  });

  it("should filter out stop words", () => {
    const tokens = tokenize("the quick brown fox and the lazy dog");
    assert.ok(!tokens.includes("the"));
    assert.ok(!tokens.includes("and"));
  });

  it("should filter out URL noise words", () => {
    const tokens = tokenize("google com stackoverflow github");
    assert.ok(!tokens.includes("google"));
    assert.ok(!tokens.includes("com"));
    assert.ok(!tokens.includes("stackoverflow"));
    assert.ok(!tokens.includes("github"));
  });

  it("should strip URLs before tokenizing", () => {
    const tokens = tokenize("check https://example.com/path?q=1 for details");
    assert.ok(!tokens.some((t) => t.includes("example")));
    assert.ok(!tokens.some((t) => t.includes("http")));
  });

  it("should handle Chinese text", () => {
    const tokens = tokenize("使用 Claude 进行 AI 对话");
    assert.ok(tokens.includes("claude"));
  });
});

describe("extractTopics", () => {
  it("should extract domain-mapped topics", () => {
    const events = [
      makeEvent({ content: "using react and nextjs for frontend" }),
      makeEvent({ content: "deploying with vercel typescript" }),
    ];
    const topics = extractTopics(events);
    assert.ok(topics.has("Web Development"));
  });

  it("should extract AI Agent topic", () => {
    const events = [
      makeEvent({ content: "working with claude and prompt engineering" }),
      makeEvent({ content: "building an AI agent with langchain" }),
    ];
    const topics = extractTopics(events);
    assert.ok(topics.has("AI Agent"));
  });

  it("should handle empty events", () => {
    const topics = extractTopics([]);
    assert.equal(topics.size, 0);
  });

  it("should not contain google or com as topic names", () => {
    const events = [
      makeEvent({ content: "searching on google.com for information" }),
      makeEvent({ content: "visiting stackoverflow.com for answers" }),
    ];
    const topics = extractTopics(events);
    assert.ok(!topics.has("google"));
    assert.ok(!topics.has("com"));
  });

  it("should use tags for topic matching", () => {
    const events = [makeEvent({ content: "some code", tags: ["swift", "xcode"] })];
    const topics = extractTopics(events);
    assert.ok(topics.has("iOS/macOS"));
  });
});

describe("assignTopic", () => {
  it("should assign topic based on content", () => {
    const event = makeEvent({ content: "writing swift code in xcode for macos app" });
    assert.equal(assignTopic(event), "iOS/macOS");
  });

  it("should assign AI Agent topic", () => {
    const event = makeEvent({ content: "using claude for prompt engineering" });
    assert.equal(assignTopic(event), "AI Agent");
  });

  it("should return undefined for unmatched content", () => {
    const event = makeEvent({ content: "random unrelated text about cooking" });
    assert.equal(assignTopic(event), undefined);
  });

  it("should use tags for matching", () => {
    const event = makeEvent({ content: "some code", tags: ["solidity", "ethereum"] });
    assert.equal(assignTopic(event), "Blockchain");
  });
});
