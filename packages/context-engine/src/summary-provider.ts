import type { LifeClipEvent } from "@lifeclip/shared";

export interface StructuredInsights {
  date: string;
  period: "daily" | "weekly";
  stats: { total: number; bySource: Record<string, number> };
  topics: Array<{ name: string; percentage: number; eventCount: number }>;
  timePatterns: Array<{ period: string; count: number; primaryActivity: string }>;
  correlations: string[];
  transitions: Array<{ time: string; from: string; to: string }>;
  topKeywords: string[];
}

export interface SummaryProvider {
  name: string;
  generateDailySummary(events: LifeClipEvent[], date: string): Promise<string>;
  generateWeeklySummary(events: LifeClipEvent[], startDate: string, endDate: string): Promise<string>;
}
