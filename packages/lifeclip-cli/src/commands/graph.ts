import { Command } from "commander";
import dayjs from "dayjs";
import { readEventsRange } from "@lifeclip/shared";
import { buildGraph } from "@lifeclip/context-engine";
import type { TopicNode } from "@lifeclip/shared";

function renderGraph(nodes: TopicNode[], maxBars: number = 20): string {
  if (nodes.length === 0) return "No topics found. Run `lifeclip collect` first.\n";

  const maxWeight = nodes[0]?.weight ?? 1;
  const lines: string[] = ["Your Life Context Graph\n"];

  for (const node of nodes.slice(0, 15)) {
    const barLen = Math.max(1, Math.round((node.weight / maxWeight) * maxBars));
    const bar = "█".repeat(barLen);
    const totalEvents = node.sources.clipboard + node.sources.browser + node.sources.note + node.sources.ai_chat;
    const name = node.name.padEnd(20);
    lines.push(`${name}${bar}  ${totalEvents} events`);
    lines.push(
      `  📋 ${node.sources.clipboard}  🌐 ${node.sources.browser}  📝 ${node.sources.note}  🤖 ${node.sources.ai_chat}  last: ${dayjs(node.lastSeen).format("MM-DD HH:mm")}`
    );
    lines.push("");
  }

  return lines.join("\n");
}

export function graphCommand(): Command {
  const cmd = new Command("graph")
    .description("Show Context Graph (topic weights)")
    .option("--period <period>", "Time period (e.g., 7d, 30d)", "30d")
    .option("--topic <name>", "Expand a specific topic")
    .action((opts) => {
      const periodMatch = opts.period.match(/^(\d+)d$/);
      const days = periodMatch ? parseInt(periodMatch[1]) : 30;

      const end = dayjs();
      const start = end.subtract(days, "day");
      const events = readEventsRange(
        start.format("YYYY-MM-DD"),
        end.format("YYYY-MM-DD")
      );

      const graph = buildGraph(events);

      if (opts.topic) {
        const node = graph.find(
          (n) => n.name.toLowerCase() === opts.topic.toLowerCase()
        );
        if (node) {
          console.log(`\nTopic: ${node.name}`);
          console.log(`Weight: ${node.weight.toFixed(2)}`);
          console.log(`Sources: 📋 ${node.sources.clipboard}  🌐 ${node.sources.browser}  📝 ${node.sources.note}  🤖 ${node.sources.ai_chat}`);
          console.log(`First seen: ${node.firstSeen}`);
          console.log(`Last seen: ${node.lastSeen}`);
          console.log(`Recent events: ${node.recentEvents.length}`);
        } else {
          console.log(`Topic "${opts.topic}" not found.`);
        }
      } else {
        console.log(renderGraph(graph));
      }
    });

  return cmd;
}
