import { Command } from "commander";
import { appendEvent, isDuplicate, sha256, readState, writeState, ensureDirs } from "@lifeclip/shared";
import { collectChromeHistory, collectSafariHistory } from "@lifeclip/browser-logger";
import { scanVault, extractNote, loadNoteSyncState, saveNoteSyncState, findChangedFiles } from "@lifeclip/note-sync";
import { collectClaudeCodeSessions, normalizeAIChatEvents } from "@lifeclip/ai-chat-logger";
import { homedir } from "os";
import { join } from "path";

const DEFAULT_VAULT = join(
  homedir(),
  "Library/Mobile Documents/iCloud~md~obsidian/Documents/ObsidianVault"
);

export function collectCommand(): Command {
  const cmd = new Command("collect")
    .description("Collect events from all sources")
    .option("--source <source>", "Only collect from: browser, notes, ai-chat")
    .option("--since <date>", "Collect events since date (YYYY-MM-DD)")
    .option("--dry-run", "Show what would be collected without writing")
    .option("--vault <path>", "Obsidian vault path", DEFAULT_VAULT)
    .action(async (opts) => {
      ensureDirs();
      const state = readState();
      const source = opts.source as string | undefined;
      const since = opts.since ?? state.lastSync[source ?? "all"] ?? undefined;
      let totalNew = 0;

      // Browser
      if (!source || source === "browser") {
        console.log("🌐 Collecting browser history...");
        try {
          const chromeEvents = collectChromeHistory({ since, dryRun: opts.dryRun });
          const safariEvents = collectSafariHistory({ since });
          const allBrowser = [...chromeEvents, ...safariEvents];

          let added = 0;
          for (const event of allBrowser) {
            const date = event.timestamp.slice(0, 10);
            if (!isDuplicate(date, event.contentHash)) {
              if (!opts.dryRun) appendEvent(event);
              added++;
            }
          }
          console.log(`   Chrome: ${chromeEvents.length} visits, Safari: ${safariEvents.length} visits`);
          console.log(`   New events: ${added}`);
          totalNew += added;
        } catch (e: any) {
          console.warn(`   ⚠️  Browser collection failed: ${e.message}`);
        }
      }

      // Notes
      if (!source || source === "notes") {
        console.log("📝 Syncing Obsidian notes...");
        try {
          const noteState = loadNoteSyncState();
          const scanned = scanVault(opts.vault);
          const changed = findChangedFiles(scanned, noteState);

          let added = 0;
          for (const file of changed) {
            try {
              const event = extractNote(file.path, file.mtime);
              const date = event.timestamp.slice(0, 10);
              if (!isDuplicate(date, event.contentHash)) {
                if (!opts.dryRun) appendEvent(event);
                added++;
              }
              noteState.files[file.path] = file.mtime;
            } catch {
              // skip files that can't be parsed
            }
          }

          if (!opts.dryRun) {
            noteState.lastSync = new Date().toISOString();
            saveNoteSyncState(noteState);
          }

          console.log(`   Scanned: ${scanned.length} files, Changed: ${changed.length}`);
          console.log(`   New events: ${added}`);
          totalNew += added;
        } catch (e: any) {
          console.warn(`   ⚠️  Note sync failed: ${e.message}`);
        }
      }

      // AI Chat
      if (!source || source === "ai-chat") {
        console.log("🤖 Collecting AI conversations...");
        try {
          const rawEvents = collectClaudeCodeSessions({ since });
          const events = normalizeAIChatEvents(rawEvents);

          let added = 0;
          for (const event of events) {
            const date = event.timestamp.slice(0, 10);
            if (!isDuplicate(date, event.contentHash)) {
              if (!opts.dryRun) appendEvent(event);
              added++;
            }
          }

          console.log(`   Claude Code sessions: ${events.length}`);
          console.log(`   New events: ${added}`);
          totalNew += added;
        } catch (e: any) {
          console.warn(`   ⚠️  AI chat collection failed: ${e.message}`);
        }
      }

      // Update state
      if (!opts.dryRun) {
        const now = new Date().toISOString();
        state.lastSync[source ?? "all"] = now;
        if (!source) {
          state.lastSync.browser = now;
          state.lastSync.notes = now;
          state.lastSync["ai-chat"] = now;
        }
        writeState(state);
      }

      console.log(`\n✅ Total new events: ${totalNew}`);
    });

  return cmd;
}
