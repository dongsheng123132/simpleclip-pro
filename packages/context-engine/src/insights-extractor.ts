import type { LifeClipEvent } from "@lifeclip/shared";
import type { StructuredInsights } from "./summary-provider.js";
import { extractTopics } from "./topic-extractor.js";

const SOURCE_LABELS: Record<string, string> = {
  clipboard: "复制", browser: "浏览", note: "笔记", ai_chat: "AI 对话",
};

export class TFIDFInsightsExtractor {
  extract(events: LifeClipEvent[], date: string, period: "daily" | "weekly"): StructuredInsights {
    // Stats
    const bySource: Record<string, number> = {};
    for (const e of events) {
      bySource[e.source] = (bySource[e.source] ?? 0) + 1;
    }

    // Topics
    const topicScores = extractTopics(events);
    const totalScore = [...topicScores.values()].reduce((a, b) => a + b, 0);
    const topics = [...topicScores.entries()]
      .sort((a, b) => b[1] - a[1])
      .slice(0, 8)
      .map(([name, score]) => ({
        name,
        percentage: totalScore > 0 ? Math.round((score / totalScore) * 100) : 0,
        eventCount: score,
      }));

    // Top keywords (from topic names)
    const topKeywords = topics.map((t) => t.name);

    // Time patterns
    const hourCounts = new Map<number, { count: number; sources: Map<string, number> }>();
    for (const e of events) {
      const hour = new Date(e.timestamp).getHours();
      const entry = hourCounts.get(hour) ?? { count: 0, sources: new Map() };
      entry.count++;
      entry.sources.set(e.source, (entry.sources.get(e.source) ?? 0) + 1);
      hourCounts.set(hour, entry);
    }
    const timePatterns = this.categorizePeriods(hourCounts);

    // Correlations
    const correlations = this.findCorrelations(events);

    // Transitions
    const transitions = this.findTransitions(events);

    return {
      date,
      period,
      stats: { total: events.length, bySource },
      topics,
      timePatterns,
      correlations,
      transitions,
      topKeywords,
    };
  }

  private categorizePeriods(
    hourCounts: Map<number, { count: number; sources: Map<string, number> }>
  ): StructuredInsights["timePatterns"] {
    const patterns: StructuredInsights["timePatterns"] = [];
    const ranges: Array<{ label: string; start: number; end: number }> = [
      { label: "上午 (6-12)", start: 6, end: 12 },
      { label: "下午 (12-18)", start: 12, end: 18 },
      { label: "晚间 (18-24)", start: 18, end: 24 },
    ];

    for (const { label, start, end } of ranges) {
      let count = 0;
      const sources = new Map<string, number>();
      for (let h = start; h < end; h++) {
        const entry = hourCounts.get(h);
        if (entry) {
          count += entry.count;
          for (const [s, c] of entry.sources) {
            sources.set(s, (sources.get(s) ?? 0) + c);
          }
        }
      }
      if (count > 0) {
        const topSource = [...sources.entries()].sort((a, b) => b[1] - a[1])[0];
        const primaryActivity = SOURCE_LABELS[topSource?.[0] ?? ""] ?? topSource?.[0] ?? "";
        patterns.push({ period: label, count, primaryActivity });
      }
    }
    return patterns;
  }

  private findCorrelations(events: LifeClipEvent[]): string[] {
    const correlations: string[] = [];
    const sourceEvents: Record<string, LifeClipEvent[]> = {};
    for (const e of events) {
      if (!sourceEvents[e.source]) sourceEvents[e.source] = [];
      sourceEvents[e.source].push(e);
    }

    const browserCount = sourceEvents.browser?.length ?? 0;
    const aiCount = sourceEvents.ai_chat?.length ?? 0;
    if (browserCount > 5 && aiCount > 0) {
      const browserTopics = extractTopics(sourceEvents.browser!);
      const aiTopics = extractTopics(sourceEvents.ai_chat!);
      const commonTopics = [...browserTopics.keys()].filter((t) => aiTopics.has(t));
      if (commonTopics.length > 0) {
        correlations.push(
          `浏览了 ${browserCount} 个页面，随后进行了 ${aiCount} 次 AI 对话，共同主题：${commonTopics.slice(0, 3).join("、")}`
        );
      }
    }

    const noteCount = sourceEvents.note?.length ?? 0;
    const clipCount = sourceEvents.clipboard?.length ?? 0;
    if (noteCount > 0 && clipCount > 5) {
      correlations.push(`编辑了 ${noteCount} 篇笔记，期间复制了 ${clipCount} 条内容`);
    }

    return correlations;
  }

  private findTransitions(events: LifeClipEvent[]): StructuredInsights["transitions"] {
    const transitions: StructuredInsights["transitions"] = [];
    const sorted = [...events].sort((a, b) => a.timestamp.localeCompare(b.timestamp));

    let prevTopic: string | undefined;
    let prevHour = -1;

    for (const e of sorted) {
      const topic = e.topic ?? e.tags?.[0];
      const hour = new Date(e.timestamp).getHours();
      if (topic && prevTopic && topic !== prevTopic && hour !== prevHour) {
        transitions.push({
          time: `${String(hour).padStart(2, "0")}:00`,
          from: prevTopic,
          to: topic,
        });
        if (transitions.length >= 4) break;
      }
      if (topic) {
        prevTopic = topic;
        prevHour = hour;
      }
    }

    return transitions;
  }
}
