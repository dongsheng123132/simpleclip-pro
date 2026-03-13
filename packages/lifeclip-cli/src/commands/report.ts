import { Command } from "commander";
import dayjs from "dayjs";
import { readEvents, loadConfig } from "@lifeclip/shared";
import { assignTopic, createSummaryProvider } from "@lifeclip/context-engine";

export function reportCommand(): Command {
  const cmd = new Command("report")
    .description("Generate daily life report (Markdown)")
    .option("--date <date>", "Specific date (YYYY-MM-DD)")
    .action(async (opts) => {
      const dateStr = opts.date ?? dayjs().format("YYYY-MM-DD");
      const events = readEvents(dateStr);

      if (events.length === 0) {
        console.log(`# ${dateStr} 人生日报\n\n暂无记录。请先运行 \`lifeclip collect\`。`);
        return;
      }

      // Assign topics
      for (const e of events) {
        if (!e.topic) e.topic = assignTopic(e);
      }

      // Count by source
      const sources: Record<string, number> = {};
      for (const e of events) {
        sources[e.source] = (sources[e.source] ?? 0) + 1;
      }

      // Count by topic
      const topics: Record<string, number> = {};
      for (const e of events) {
        const t = e.topic ?? "Other";
        topics[t] = (topics[t] ?? 0) + 1;
      }

      // Active hours
      const hours = new Set(events.map((e) => new Date(e.timestamp).getHours()));
      const activeHours = [...hours].sort((a, b) => a - b);
      const firstHour = activeHours[0];
      const lastHour = activeHours[activeHours.length - 1];

      // Build report
      const lines: string[] = [
        `# ${dateStr} 人生日报`,
        "",
        `## 概览`,
        `- 总事件: ${events.length}`,
        `- 活跃时段: ${firstHour}:00 - ${lastHour}:59 (${activeHours.length} 小时)`,
        "",
        "## 数据来源",
      ];

      if (sources.clipboard) lines.push(`- 📋 剪贴板: ${sources.clipboard} 条`);
      if (sources.browser) lines.push(`- 🌐 浏览器: ${sources.browser} 页`);
      if (sources.note) lines.push(`- 📝 笔记: ${sources.note} 篇`);
      if (sources.ai_chat) lines.push(`- 🤖 AI 对话: ${sources.ai_chat} 次`);

      lines.push("", "## 主题分布");
      const sortedTopics = Object.entries(topics).sort((a, b) => b[1] - a[1]);
      for (const [topic, count] of sortedTopics) {
        const bar = "█".repeat(Math.min(count, 20));
        lines.push(`- ${topic}: ${bar} ${count}`);
      }

      // AI-powered insights summary
      lines.push("", "## 今日摘要");
      const config = loadConfig();
      const provider = createSummaryProvider(config);
      const insightText = await provider.generateDailySummary(events, dateStr);
      const insightLines = insightText.split("\n").filter((l) => !l.startsWith("# ") && l.trim());
      lines.push(...insightLines);

      console.log(lines.join("\n"));
    });

  return cmd;
}
