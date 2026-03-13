const DOMAIN_CATEGORIES: Record<string, string> = {
  // Social
  "twitter.com": "social", "x.com": "social",
  "facebook.com": "social", "instagram.com": "social",
  "linkedin.com": "social", "weibo.com": "social",
  "xiaohongshu.com": "social", "okjike.com": "social",
  // Dev
  "github.com": "dev", "gitlab.com": "dev",
  "stackoverflow.com": "dev", "npmjs.com": "dev",
  "docs.rs": "dev", "crates.io": "dev",
  "developer.apple.com": "dev",
  // AI
  "chat.openai.com": "ai", "chatgpt.com": "ai",
  "claude.ai": "ai", "anthropic.com": "ai",
  "huggingface.co": "ai", "arxiv.org": "ai",
  // News
  "news.ycombinator.com": "news", "reddit.com": "news",
  "techcrunch.com": "news", "theverge.com": "news",
  "36kr.com": "news", "sspai.com": "news",
  // Video
  "youtube.com": "video", "bilibili.com": "video",
  "youku.com": "video",
  // Shopping
  "amazon.com": "shopping", "taobao.com": "shopping",
  "jd.com": "shopping", "pinduoduo.com": "shopping",
  // Docs
  "notion.so": "docs", "docs.google.com": "docs",
  "obsidian.md": "docs",
  // Search
  "google.com": "search", "bing.com": "search",
  "baidu.com": "search",
};

/** Map a URL to a category based on its domain */
export function categorizeURL(url: string): string | undefined {
  try {
    const hostname = new URL(url).hostname.replace(/^www\./, "");
    // Direct match
    if (DOMAIN_CATEGORIES[hostname]) return DOMAIN_CATEGORIES[hostname];
    // Try parent domain (e.g. m.weibo.com -> weibo.com)
    const parts = hostname.split(".");
    if (parts.length > 2) {
      const parent = parts.slice(-2).join(".");
      if (DOMAIN_CATEGORIES[parent]) return DOMAIN_CATEGORIES[parent];
    }
    return undefined;
  } catch {
    return undefined;
  }
}
