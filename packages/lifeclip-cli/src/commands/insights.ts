import { Command } from "commander";
import dayjs from "dayjs";
import { readEvents, readEventsRange, loadConfig } from "@lifeclip/shared";
import { assignTopic, createSummaryProvider } from "@lifeclip/context-engine";

export function insightsCommand(): Command {
  const cmd = new Command("insights")
    .description("Generate AI-powered insights from your data")
    .option("--date <date>", "Specific date (YYYY-MM-DD)")
    .option("--week", "Generate weekly insights")
    .action(async (opts) => {
      const config = loadConfig();
      const provider = createSummaryProvider(config);

      if (opts.week) {
        const end = dayjs();
        const start = end.subtract(6, "day");
        const startStr = start.format("YYYY-MM-DD");
        const endStr = end.format("YYYY-MM-DD");
        const events = readEventsRange(startStr, endStr);
        for (const e of events) {
          if (!e.topic) e.topic = assignTopic(e);
        }
        console.log(await provider.generateWeeklySummary(events, startStr, endStr));
      } else {
        const dateStr = opts.date ?? dayjs().format("YYYY-MM-DD");
        const events = readEvents(dateStr);
        for (const e of events) {
          if (!e.topic) e.topic = assignTopic(e);
        }
        console.log(await provider.generateDailySummary(events, dateStr));
      }
    });

  return cmd;
}
