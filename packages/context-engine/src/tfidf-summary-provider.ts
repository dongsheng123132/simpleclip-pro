import type { LifeClipEvent } from "@lifeclip/shared";
import type { SummaryProvider, StructuredInsights } from "./summary-provider.js";
import { TFIDFInsightsExtractor } from "./insights-extractor.js";

const extractor = new TFIDFInsightsExtractor();

export class TFIDFSummaryProvider implements SummaryProvider {
  name = "tfidf";

  async generateDailySummary(events: LifeClipEvent[], date: string): Promise<string> {
    if (events.length === 0) return `${date} 无记录。`;

    const insights = extractor.extract(events, date, "daily");
    return formatDailyMarkdown(insights);
  }

  async generateWeeklySummary(events: LifeClipEvent[], startDate: string, endDate: string): Promise<string> {
    if (events.length === 0) return `${startDate} ~ ${endDate} 无记录。`;

    const insights = extractor.extract(events, startDate, "weekly");

    const lines: string[] = [`# ${startDate} ~ ${endDate} 周度洞察\n`];

    // Daily activity trend
    const dayMap = new Map<string, LifeClipEvent[]>();
    for (const e of events) {
      const day = e.timestamp.slice(0, 10);
      if (!dayMap.has(day)) dayMap.set(day, []);
      dayMap.get(day)!.push(e);
    }

    lines.push("## 每日活跃度");
    const sortedDays = [...dayMap.keys()].sort();
    for (const day of sortedDays) {
      const count = dayMap.get(day)!.length;
      const bar = "█".repeat(Math.max(1, Math.round(count / 10)));
      lines.push(`- ${day}: ${bar} ${count} 条`);
    }
    lines.push("");

    // Weekly topic distribution
    if (insights.topics.length > 0) {
      lines.push("## 本周主题");
      for (const t of insights.topics) {
        lines.push(`- ${t.name}: ${t.percentage}%`);
      }
      lines.push("");
    }

    // Source breakdown
    const sourceLabels: Record<string, string> = {
      clipboard: "📋 剪贴板", browser: "🌐 浏览器", note: "📝 笔记", ai_chat: "🤖 AI 对话",
    };
    lines.push("## 数据来源");
    for (const [src, count] of Object.entries(insights.stats.bySource).sort((a, b) => b[1] - a[1])) {
      lines.push(`- ${sourceLabels[src] ?? src}: ${count} 条`);
    }

    const topTopic = insights.topics[0]?.name ?? "日常活动";
    lines.push(`\n---\n本周共 ${insights.stats.total} 条记录，核心主题「${topTopic}」。`);

    return lines.join("\n");
  }
}

function formatDailyMarkdown(insights: StructuredInsights): string {
  const lines: string[] = [`# ${insights.date} 智能洞察\n`];

  // Topics
  if (insights.topics.length > 0) {
    lines.push("## 主题分布");
    for (const t of insights.topics.slice(0, 6)) {
      const bar = "█".repeat(Math.max(1, Math.round(t.percentage / 5)));
      lines.push(`- ${t.name}: ${bar} ${t.percentage}%`);
    }
    lines.push("");
  }

  // Time patterns
  if (insights.timePatterns.length > 0) {
    lines.push("## 时间模式");
    for (const p of insights.timePatterns) {
      lines.push(`- ${p.period}: ${p.count} 条活动，主要${p.primaryActivity}`);
    }
    lines.push("");
  }

  // Correlations
  if (insights.correlations.length > 0) {
    lines.push("## 跨源关联");
    for (const c of insights.correlations) {
      lines.push(`- ${c}`);
    }
    lines.push("");
  }

  // Transitions
  if (insights.transitions.length > 0) {
    lines.push("## 主题转换");
    for (const t of insights.transitions) {
      lines.push(`- ${t.time} 从「${t.from}」切换到「${t.to}」`);
    }
    lines.push("");
  }

  const topTopic = insights.topics[0]?.name ?? "日常活动";
  lines.push(`---\n今日共 ${insights.stats.total} 条记录，主要围绕「${topTopic}」展开。`);

  return lines.join("\n");
}
