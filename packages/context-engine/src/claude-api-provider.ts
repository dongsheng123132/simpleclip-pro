import type { LifeClipEvent } from "@lifeclip/shared";
import type { SummaryProvider } from "./summary-provider.js";
import { TFIDFInsightsExtractor } from "./insights-extractor.js";
import { TFIDFSummaryProvider } from "./tfidf-summary-provider.js";

const extractor = new TFIDFInsightsExtractor();
const fallback = new TFIDFSummaryProvider();

export class ClaudeAPIProvider implements SummaryProvider {
  name = "claude-api";
  private apiKey: string;

  constructor(apiKey: string) {
    this.apiKey = apiKey;
  }

  async generateDailySummary(events: LifeClipEvent[], date: string): Promise<string> {
    if (events.length === 0) return `${date} 无记录。`;

    const insights = extractor.extract(events, date, "daily");
    const prompt = this.buildDailyPrompt(date, JSON.stringify(insights, null, 2));

    try {
      const result = await this.callClaude(prompt);
      return `# ${date} AI 智能洞察\n\n${result}`;
    } catch (err) {
      console.error(`[claude-api] API call failed: ${err instanceof Error ? err.message : err}`);
      console.error("[claude-api] Falling back to TF-IDF");
      return fallback.generateDailySummary(events, date);
    }
  }

  async generateWeeklySummary(events: LifeClipEvent[], startDate: string, endDate: string): Promise<string> {
    if (events.length === 0) return `${startDate} ~ ${endDate} 无记录。`;

    const insights = extractor.extract(events, startDate, "weekly");
    const prompt = this.buildWeeklyPrompt(startDate, endDate, JSON.stringify(insights, null, 2));

    try {
      const result = await this.callClaude(prompt);
      return `# ${startDate} ~ ${endDate} AI 周度洞察\n\n${result}`;
    } catch (err) {
      console.error(`[claude-api] API call failed: ${err instanceof Error ? err.message : err}`);
      console.error("[claude-api] Falling back to TF-IDF");
      return fallback.generateWeeklySummary(events, startDate, endDate);
    }
  }

  private buildDailyPrompt(date: string, insightsJSON: string): string {
    return `以下是我 ${date} 的行为统计数据（JSON格式）。请用中文分析我今天的行为模式，给出有洞察力的总结和建议。

要求：
1. 分析主要时间花费方向
2. 指出跨源关联（比如浏览+AI对话的主题重叠）
3. 发现主题切换的规律
4. 给出 1-2 条具体可操作的建议
5. 语气友好专业，像一个了解我的 AI 助手
6. 控制在 300 字以内

数据：
${insightsJSON}`;
  }

  private buildWeeklyPrompt(startDate: string, endDate: string, insightsJSON: string): string {
    return `以下是我 ${startDate} 至 ${endDate} 一周的行为统计数据（JSON格式）。请用中文分析我的一周行为模式，给出有洞察力的总结和建议。

要求：
1. 分析主要时间花费方向和趋势变化
2. 指出有价值的行为模式或习惯
3. 给出 2-3 条具体可操作的建议
4. 语气友好专业，像一个了解我的 AI 助手
5. 控制在 400 字以内

数据：
${insightsJSON}`;
  }

  private async callClaude(prompt: string): Promise<string> {
    const response = await fetch("https://api.anthropic.com/v1/messages", {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
        "x-api-key": this.apiKey,
        "anthropic-version": "2023-06-01",
      },
      body: JSON.stringify({
        model: "claude-sonnet-4-20250514",
        max_tokens: 600,
        messages: [{ role: "user", content: prompt }],
      }),
    });

    if (!response.ok) {
      const errorBody = await response.text();
      throw new Error(`Claude API error ${response.status}: ${errorBody}`);
    }

    const data = (await response.json()) as {
      content: Array<{ type: string; text?: string }>;
    };
    const textBlock = data.content.find((b) => b.type === "text");
    if (!textBlock?.text) throw new Error("No text in Claude API response");

    return textBlock.text;
  }
}
