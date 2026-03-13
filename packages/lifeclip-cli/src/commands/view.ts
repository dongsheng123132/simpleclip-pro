import { Command } from "commander";
import dayjs from "dayjs";
import { readEvents, redactPII, loadConfig } from "@lifeclip/shared";
import type { LifeClipEvent } from "@lifeclip/shared";

const SOURCE_ICONS: Record<string, string> = {
  clipboard: "\u{1F4CB}",
  browser: "\u{1F310}",
  note: "\u{1F4DD}",
  ai_chat: "\u{1F916}",
};

export function viewCommand(): Command {
  const cmd = new Command("view")
    .description("View events with PII protection")
    .option("--date <date>", "Specific date (YYYY-MM-DD)")
    .option("--source <source>", "Filter by source (clipboard, browser, note, ai_chat)")
    .option("--raw", "Show raw content without PII filtering")
    .option("--limit <n>", "Maximum events to show", "50")
    .action((opts) => {
      const dateStr = opts.date ?? dayjs().format("YYYY-MM-DD");
      let events = readEvents(dateStr);

      if (opts.source) {
        events = events.filter((e: LifeClipEvent) => e.source === opts.source);
      }

      if (events.length === 0) {
        console.log(`${dateStr} 暂无${opts.source ? ` ${opts.source} ` : ""}记录。`);
        return;
      }

      const config = loadConfig();
      const limit = parseInt(opts.limit, 10);
      const showRaw = opts.raw === true;

      console.log(`# ${dateStr} 事件查看${showRaw ? " (原始内容)" : " (PII 已过滤)"}\n`);
      console.log(`共 ${events.length} 条记录${events.length > limit ? `，显示前 ${limit} 条` : ""}\n`);

      for (const event of events.slice(0, limit)) {
        const time = dayjs(event.timestamp).format("HH:mm:ss");
        const icon = SOURCE_ICONS[event.source] ?? "\u{1F4CC}";
        const content = showRaw
          ? event.content.slice(0, 120)
          : redactPII(event.content, config.pii.level === "off" ? "standard" : config.pii.level).slice(0, 120);
        console.log(`${time} ${icon} [${event.source}] ${content.replace(/\n/g, " ")}`);
      }

      if (events.length > limit) {
        console.log(`\n... 还有 ${events.length - limit} 条记录，使用 --limit 查看更多`);
      }
    });

  return cmd;
}
