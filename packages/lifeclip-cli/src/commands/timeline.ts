import { Command } from "commander";
import dayjs from "dayjs";
import { readEvents, readEventsRange, loadConfig } from "@lifeclip/shared";
import type { LifeClipEvent } from "@lifeclip/shared";
import { assignTopic, createSummaryProvider } from "@lifeclip/context-engine";

const SOURCE_ICONS: Record<string, string> = {
  clipboard: "📋",
  browser: "🌐",
  note: "📝",
  ai_chat: "🤖",
};

async function formatTimeline(events: LifeClipEvent[], dateStr: string): Promise<string> {
  if (events.length === 0) return `# ${dateStr} 人生时间线\n\n暂无记录。\n`;

  // Group by hour
  const hourGroups = new Map<number, LifeClipEvent[]>();
  for (const event of events) {
    const hour = new Date(event.timestamp).getHours();
    if (!hourGroups.has(hour)) hourGroups.set(hour, []);
    hourGroups.get(hour)!.push(event);
  }

  // Determine dominant topic per hour
  const lines: string[] = [`# ${dateStr} 人生时间线\n`];

  const sortedHours = [...hourGroups.keys()].sort((a, b) => a - b);
  for (const hour of sortedHours) {
    const hourEvents = hourGroups.get(hour)!;
    // Find dominant topic
    const topicCounts = new Map<string, number>();
    for (const e of hourEvents) {
      const topic = e.topic ?? e.tags?.[0] ?? "Other";
      topicCounts.set(topic, (topicCounts.get(topic) ?? 0) + 1);
    }
    const dominantTopic = [...topicCounts.entries()].sort((a, b) => b[1] - a[1])[0]?.[0] ?? "Activity";
    const nextHour = (hour + 1) % 24;
    lines.push(`## ${String(hour).padStart(2, "0")}:00 - ${String(nextHour).padStart(2, "0")}:00 | ${dominantTopic}`);

    for (const event of hourEvents.slice(0, 8)) {
      const time = dayjs(event.timestamp).format("HH:mm");
      const icon = SOURCE_ICONS[event.source] ?? "📌";
      const content = event.content.slice(0, 80).replace(/\n/g, " ");
      lines.push(`- ${time} ${icon} ${content}`);
    }
    if (hourEvents.length > 8) {
      lines.push(`- ... and ${hourEvents.length - 8} more`);
    }
    lines.push("");
  }

  // AI Summary
  for (const e of events) {
    if (!e.topic) e.topic = assignTopic(e);
  }
  const config = loadConfig();
  const provider = createSummaryProvider(config);
  const summary = await provider.generateDailySummary(events, dateStr);
  const summaryLines = summary.split("\n").filter((l) => !l.startsWith("# ") && l.trim());
  lines.push("## AI Summary\n");
  lines.push(...summaryLines);

  return lines.join("\n");
}

export function timelineCommand(): Command {
  const cmd = new Command("timeline")
    .description("Generate AI Life Timeline")
    .option("--date <date>", "Specific date (YYYY-MM-DD)")
    .option("--week", "Show this week's summary")
    .action(async (opts) => {
      if (opts.week) {
        const end = dayjs();
        const start = end.subtract(6, "day");
        const events = readEventsRange(
          start.format("YYYY-MM-DD"),
          end.format("YYYY-MM-DD")
        );
        // Group by day
        for (let d = start; d.isBefore(end) || d.isSame(end, "day"); d = d.add(1, "day")) {
          const dateStr = d.format("YYYY-MM-DD");
          const dayEvents = events.filter((e) => e.timestamp.startsWith(dateStr));
          if (dayEvents.length > 0) {
            console.log(await formatTimeline(dayEvents, dateStr));
            console.log("---\n");
          }
        }
      } else {
        const dateStr = opts.date ?? dayjs().format("YYYY-MM-DD");
        const events = readEvents(dateStr);
        console.log(await formatTimeline(events, dateStr));
      }
    });

  return cmd;
}
