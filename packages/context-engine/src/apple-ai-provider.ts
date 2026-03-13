import { execFile, execFileSync } from "child_process";
import { existsSync } from "fs";
import { join } from "path";
import type { LifeClipEvent } from "@lifeclip/shared";
import type { SummaryProvider } from "./summary-provider.js";
import { TFIDFInsightsExtractor } from "./insights-extractor.js";
import { TFIDFSummaryProvider } from "./tfidf-summary-provider.js";

const extractor = new TFIDFInsightsExtractor();
const fallback = new TFIDFSummaryProvider();

function findHelperPath(customPath?: string): string | null {
  // 1. User-specified path
  if (customPath && existsSync(customPath)) return customPath;

  // 2. Project-local build
  const projectPath = join(__dirname, "../../../tools/lifeclip-ai-helper/.build/release/lifeclip-ai-helper");
  if (existsSync(projectPath)) return projectPath;

  // 3. Check PATH via which
  try {
    const result = execFileSync("which", ["lifeclip-ai-helper"], { encoding: "utf-8" }).trim();
    if (result) return result;
  } catch {
    // not in PATH
  }

  return null;
}

function runHelper(helperPath: string, input: string): Promise<string> {
  return new Promise((resolve, reject) => {
    const child = execFile(helperPath, [], { timeout: 30000 }, (error, stdout, stderr) => {
      if (error) {
        reject(new Error(stderr || error.message));
      } else {
        resolve(stdout.trim());
      }
    });
    child.stdin?.write(input);
    child.stdin?.end();
  });
}

export class AppleAIProvider implements SummaryProvider {
  name = "apple-ai";
  private helperPath?: string;

  constructor(customHelperPath?: string) {
    this.helperPath = customHelperPath;
  }

  async generateDailySummary(events: LifeClipEvent[], date: string): Promise<string> {
    if (events.length === 0) return `${date} 无记录。`;

    const insights = extractor.extract(events, date, "daily");
    const helper = findHelperPath(this.helperPath);

    if (!helper) {
      console.error("[apple-ai] Helper binary not found, falling back to TF-IDF");
      return fallback.generateDailySummary(events, date);
    }

    try {
      const result = await runHelper(helper, JSON.stringify(insights));
      return `# ${date} AI 智能洞察\n\n${result}`;
    } catch (err) {
      console.error(`[apple-ai] Generation failed: ${err instanceof Error ? err.message : err}`);
      console.error("[apple-ai] Falling back to TF-IDF");
      return fallback.generateDailySummary(events, date);
    }
  }

  async generateWeeklySummary(events: LifeClipEvent[], startDate: string, endDate: string): Promise<string> {
    if (events.length === 0) return `${startDate} ~ ${endDate} 无记录。`;

    const insights = extractor.extract(events, startDate, "weekly");
    const helper = findHelperPath(this.helperPath);

    if (!helper) {
      console.error("[apple-ai] Helper binary not found, falling back to TF-IDF");
      return fallback.generateWeeklySummary(events, startDate, endDate);
    }

    try {
      const result = await runHelper(helper, JSON.stringify(insights));
      return `# ${startDate} ~ ${endDate} AI 周度洞察\n\n${result}`;
    } catch (err) {
      console.error(`[apple-ai] Generation failed: ${err instanceof Error ? err.message : err}`);
      console.error("[apple-ai] Falling back to TF-IDF");
      return fallback.generateWeeklySummary(events, startDate, endDate);
    }
  }
}
