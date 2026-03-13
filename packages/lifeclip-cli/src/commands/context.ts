import { Command } from "commander";
import { generateContext, loadContext } from "@lifeclip/context-engine";

export function contextCommand(): Command {
  const cmd = new Command("context")
    .description("Generate or show Personal Context API")
    .option("--show", "Show current context without regenerating")
    .option("--days <n>", "Number of days to analyze", "30")
    .action((opts) => {
      if (opts.show) {
        const ctx = loadContext();
        if (!ctx) {
          console.log("No context file found. Run `lifeclip context` to generate.");
          return;
        }
        console.log(JSON.stringify(ctx, null, 2));
        return;
      }

      const days = parseInt(opts.days);
      console.log(`Generating personal context (last ${days} days)...\n`);

      const ctx = generateContext({ days });

      console.log(`Summary: ${ctx.summary}\n`);
      console.log("Recent Topics:");
      for (const topic of ctx.recentTopics.slice(0, 10)) {
        console.log(`  - ${topic.name} (weight: ${topic.weight})`);
      }
      console.log(`\nActive Projects: ${ctx.activeProjects.join(", ") || "none"}`);
      console.log(`\nActivity: 📋 ${ctx.recentActivity.clipboard}  🌐 ${ctx.recentActivity.browser}  📝 ${ctx.recentActivity.notes}  🤖 ${ctx.recentActivity.aiChats}`);
      console.log(`\nContext saved to ~/.lifeclip/context.json`);
    });

  return cmd;
}
