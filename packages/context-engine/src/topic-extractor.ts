import type { LifeClipEvent } from "@lifeclip/shared";

/** Domain keyword → topic mapping */
const TOPIC_KEYWORDS: Record<string, string[]> = {
  "AI Agent": ["agent", "llm", "gpt", "claude", "prompt", "langchain", "openai", "anthropic", "ai", "模型", "智能体", "mcp", "skill"],
  "LifeClip": ["lifeclip", "clipboard", "剪贴板", "剪切", "simpleclip", "context graph", "timeline"],
  "AirKey": ["airkey", "wireless keyboard", "无线键盘"],
  "Smart Ring": ["ring.glass", "smart ring", "智能戒指"],
  "Web Development": ["react", "next.js", "nextjs", "vercel", "typescript", "css", "html", "frontend", "后端", "前端"],
  "Blockchain": ["solidity", "ethereum", "monad", "starknet", "web3", "crypto", "defi", "nft", "区块链", "x402"],
  "Hardware": ["esp32", "arduino", "ble", "bluetooth", "firmware", "gpio", "sensor", "硬件", "tuya"],
  "Startup": ["product", "launch", "growth", "marketing", "revenue", "用户", "增长", "融资", "创业"],
  "DevOps": ["docker", "ci/cd", "deploy", "kubernetes", "nginx", "server", "运维", "homebrew", "brew"],
  "iOS/macOS": ["swift", "swiftui", "xcode", "macos", "ios", "apple", "appstore", "swiftdata"],
  "Python": ["python", "pip", "django", "flask", "pandas", "numpy"],
  "Design": ["figma", "ui", "ux", "design", "设计", "原型"],
  "OpenClaw": ["openclaw", "u-claw", "uclaw", "claw"],
  "Social Media": ["推广", "文案", "小红书", "twitter", "linkedin", "社交媒体"],
};

/** Strip URLs from text before tokenization */
export function stripURLs(text: string): string {
  return text.replace(/https?:\/\/[^\s"'<>]+/g, " ");
}

/** Common stop words that pollute topic extraction */
const STOP_WORDS = new Set([
  // English
  "the", "and", "for", "are", "but", "not", "you", "all", "can", "had", "her", "was", "one",
  "our", "out", "has", "have", "been", "from", "this", "that", "with", "they", "will", "each",
  "make", "like", "just", "over", "such", "take", "than", "them", "very", "some", "into",
  "could", "would", "should", "about", "which", "their", "what", "there", "when", "your",
  "also", "more", "other", "then", "these", "only", "after", "before", "between", "being",
  // URL fragments & noise
  "com", "org", "www", "https", "http", "html", "htm", "php", "asp", "jsx", "tsx", "json",
  "png", "jpg", "svg", "gif", "pdf", "undefined", "null", "true", "false",
  "google", "github", "stackoverflow", "microsoft", "amazonaws", "cloudfront",
  "localhost", "index", "query", "param", "page", "content", "data", "type",
  "search", "docs", "link", "title", "name", "item", "list", "view", "text",
  // Chinese stop words
  "的", "了", "在", "是", "我", "有", "和", "就", "不", "人", "都", "一", "个", "上", "也",
  "很", "到", "说", "要", "去", "你", "会", "着", "没有", "看", "好", "自己", "这",
]);

/** Check if a token is valid (not noise) */
export function isValidToken(token: string): boolean {
  if (token.length < 2) return false;
  // Reject pure numbers
  if (/^\d+$/.test(token)) return false;
  // Reject hex fragments (e.g. "3fi", "a2b", "ff00")
  if (/^[0-9a-f]+$/i.test(token) && /\d/.test(token)) return false;
  // Reject very short tokens (for auto-discovered topics, stricter)
  return true;
}

/** Tokenize text into clean lowercase words */
export function tokenize(text: string): string[] {
  return stripURLs(text)
    .toLowerCase()
    .replace(/[^\w\u4e00-\u9fff\s-]/g, " ")
    .split(/\s+/)
    .filter((w) => isValidToken(w) && !STOP_WORDS.has(w));
}

/** Calculate TF-IDF for a corpus of texts */
function calculateTFIDF(documents: string[]): Map<string, number> {
  const df = new Map<string, number>(); // document frequency
  const allTokens = new Map<string, number>(); // global term frequency
  const N = documents.length;

  // Calculate DF and global TF
  for (const doc of documents) {
    const tokens = tokenize(doc);
    const seen = new Set<string>();
    for (const token of tokens) {
      allTokens.set(token, (allTokens.get(token) ?? 0) + 1);
      if (!seen.has(token)) {
        df.set(token, (df.get(token) ?? 0) + 1);
        seen.add(token);
      }
    }
  }

  // Calculate TF-IDF scores
  const tfidf = new Map<string, number>();
  for (const [token, tf] of allTokens) {
    const docFreq = df.get(token) ?? 1;
    const idf = Math.log(N / docFreq);
    tfidf.set(token, tf * idf);
  }

  return tfidf;
}

/** Extract topics from events using TF-IDF + domain mapping */
export function extractTopics(events: LifeClipEvent[]): Map<string, number> {
  const topicScores = new Map<string, number>();

  // 1. Domain-based topic matching from event content and tags
  for (const event of events) {
    const text = `${event.content} ${(event.tags ?? []).join(" ")}`.toLowerCase();

    for (const [topic, keywords] of Object.entries(TOPIC_KEYWORDS)) {
      let matches = 0;
      for (const kw of keywords) {
        if (text.includes(kw)) matches++;
      }
      if (matches > 0) {
        topicScores.set(topic, (topicScores.get(topic) ?? 0) + matches);
      }
    }

    // URL category → topic
    if (event.metadata.category) {
      const cat = event.metadata.category as string;
      const catTopicMap: Record<string, string> = {
        dev: "Web Development",
        ai: "AI Agent",
        social: "Social Media",
        news: "News & Reading",
        video: "Entertainment",
        shopping: "Shopping",
        docs: "Documentation",
      };
      if (catTopicMap[cat]) {
        topicScores.set(catTopicMap[cat], (topicScores.get(catTopicMap[cat]) ?? 0) + 1);
      }
    }
  }

  // 2. TF-IDF for unlabeled high-frequency keywords → create new topics
  const documents = events.map((e) => e.content);
  if (documents.length > 0) {
    const tfidf = calculateTFIDF(documents);
    // Get top keywords not already covered by topic mapping
    const coveredWords = new Set(
      Object.values(TOPIC_KEYWORDS).flat()
    );
    const topKeywords = [...tfidf.entries()]
      .filter(([word]) => !coveredWords.has(word) && word.length > 3)
      .sort((a, b) => b[1] - a[1])
      .slice(0, 10);

    for (const [keyword, score] of topKeywords) {
      if (score > 5 && !topicScores.has(keyword)) {
        // Only add as topic if it appears frequently enough
        topicScores.set(keyword, score);
      }
    }
  }

  return topicScores;
}

/** Assign a topic to an event based on its content */
export function assignTopic(event: LifeClipEvent): string | undefined {
  const text = `${event.content} ${(event.tags ?? []).join(" ")}`.toLowerCase();

  let bestTopic: string | undefined;
  let bestScore = 0;

  for (const [topic, keywords] of Object.entries(TOPIC_KEYWORDS)) {
    let score = 0;
    for (const kw of keywords) {
      if (text.includes(kw)) score++;
    }
    if (score > bestScore) {
      bestScore = score;
      bestTopic = topic;
    }
  }

  return bestTopic;
}
