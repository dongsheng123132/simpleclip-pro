import { Command } from "commander";
import { existsSync, readdirSync, readFileSync, statSync } from "fs";
import { join } from "path";
import { LIFECLIP_DIR, EVENTS_DIR, readState } from "@lifeclip/shared";

export function statusCommand(): Command {
  const cmd = new Command("status")
    .description("Show LifeClip data statistics")
    .action(() => {
      console.log("LifeClip Status\n");

      // Check directories
      console.log(`Data directory: ${LIFECLIP_DIR}`);
      console.log(`  Exists: ${existsSync(LIFECLIP_DIR) ? "✓" : "✗ (run lifeclip collect first)"}`);

      if (!existsSync(EVENTS_DIR)) {
        console.log("\nNo events collected yet. Run `lifeclip collect` to start.");
        return;
      }

      // Count event files
      const eventFiles = readdirSync(EVENTS_DIR).filter((f) => f.endsWith(".jsonl"));
      let totalEvents = 0;
      let totalSize = 0;
      let oldestDate = "9999-99-99";
      let newestDate = "0000-00-00";

      for (const file of eventFiles) {
        const fullPath = join(EVENTS_DIR, file);
        const stat = statSync(fullPath);
        totalSize += stat.size;
        const dateStr = file.replace(".jsonl", "");
        if (dateStr < oldestDate) oldestDate = dateStr;
        if (dateStr > newestDate) newestDate = dateStr;

        const content = readFileSync(fullPath, "utf-8");
        totalEvents += content.split("\n").filter(Boolean).length;
      }

      console.log(`\nEvent files: ${eventFiles.length}`);
      console.log(`Total events: ${totalEvents}`);
      console.log(`Total size: ${(totalSize / 1024).toFixed(1)} KB`);
      if (eventFiles.length > 0) {
        console.log(`Date range: ${oldestDate} → ${newestDate}`);
      }

      // Check other files
      const graphExists = existsSync(join(LIFECLIP_DIR, "graph.json"));
      const contextExists = existsSync(join(LIFECLIP_DIR, "context.json"));
      console.log(`\nGraph: ${graphExists ? "✓ generated" : "✗ not yet (run lifeclip graph)"}`);
      console.log(`Context: ${contextExists ? "✓ generated" : "✗ not yet (run lifeclip context)"}`);

      // Last sync
      const state = readState();
      if (Object.keys(state.lastSync).length > 0) {
        console.log("\nLast sync:");
        for (const [source, time] of Object.entries(state.lastSync)) {
          console.log(`  ${source}: ${time}`);
        }
      }
    });

  return cmd;
}
