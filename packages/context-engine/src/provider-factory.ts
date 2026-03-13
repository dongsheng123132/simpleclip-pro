import type { LifeClipConfig } from "@lifeclip/shared";
import type { SummaryProvider } from "./summary-provider.js";
import { TFIDFSummaryProvider } from "./tfidf-summary-provider.js";
import { AppleAIProvider } from "./apple-ai-provider.js";
import { ClaudeAPIProvider } from "./claude-api-provider.js";

export function createSummaryProvider(config: LifeClipConfig): SummaryProvider {
  switch (config.insights.provider) {
    case "apple-ai":
      return new AppleAIProvider(config.insights.helperPath);
    case "claude-api": {
      if (!config.insights.apiKey) {
        console.error("[provider] claude-api requires apiKey. Run: lifeclip config --set insights.apiKey=sk-...");
        console.error("[provider] Falling back to TF-IDF");
        return new TFIDFSummaryProvider();
      }
      return new ClaudeAPIProvider(config.insights.apiKey);
    }
    default:
      return new TFIDFSummaryProvider();
  }
}
