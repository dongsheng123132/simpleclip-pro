import { Command } from "commander";
import { readdirSync, readFileSync, writeFileSync } from "fs";
import { join } from "path";
import { EVENTS_DIR, ensureDirs, redactPII, redactMetadata, sha256, loadConfig } from "@lifeclip/shared";
import type { LifeClipEvent } from "@lifeclip/shared";

export function scrubCommand(): Command {
  const cmd = new Command("scrub")
    .description("Retroactively scrub PII from historical event data")
    .option("--dry-run", "Preview changes without modifying files")
    .option("--level <level>", "PII level override (strict, standard)", "")
    .action((opts) => {
      ensureDirs();
      const config = loadConfig();
      const level = (opts.level || config.pii.level) as "strict" | "standard" | "off";

      if (level === "off") {
        console.log("PII filtering is disabled (level=off). Nothing to scrub.");
        return;
      }

      let files: string[];
      try {
        files = readdirSync(EVENTS_DIR).filter((f) => f.endsWith(".jsonl")).sort();
      } catch {
        console.log("No event files found.");
        return;
      }

      let totalEvents = 0;
      let modifiedEvents = 0;
      let modifiedFiles = 0;

      for (const file of files) {
        const filePath = join(EVENTS_DIR, file);
        const content = readFileSync(filePath, "utf-8");
        const lines = content.split("\n").filter(Boolean);
        let fileModified = false;
        const newLines: string[] = [];

        for (const line of lines) {
          totalEvents++;
          let event: LifeClipEvent;
          try {
            event = JSON.parse(line);
          } catch {
            newLines.push(line);
            continue;
          }

          const newContent = redactPII(event.content, level);
          const newMetadata = redactMetadata(event.metadata, level);
          const contentChanged = newContent !== event.content;
          const metadataChanged = JSON.stringify(newMetadata) !== JSON.stringify(event.metadata);

          if (contentChanged || metadataChanged) {
            modifiedEvents++;
            fileModified = true;
            event.content = newContent;
            event.metadata = newMetadata;
            event.contentHash = sha256(newContent);
          }

          newLines.push(JSON.stringify(event));
        }

        if (fileModified) {
          modifiedFiles++;
          if (opts.dryRun) {
            console.log(`[dry-run] ${file}: ${lines.length} events, would modify`);
          } else {
            writeFileSync(filePath, newLines.join("\n") + "\n", "utf-8");
            console.log(`Scrubbed ${file}`);
          }
        }
      }

      console.log(`\n--- Scrub ${opts.dryRun ? "Preview" : "Complete"} ---`);
      console.log(`Total events:    ${totalEvents}`);
      console.log(`Modified events: ${modifiedEvents}`);
      console.log(`Modified files:  ${modifiedFiles}`);
      if (opts.dryRun) {
        console.log(`\nRun without --dry-run to apply changes.`);
      }
    });

  return cmd;
}
