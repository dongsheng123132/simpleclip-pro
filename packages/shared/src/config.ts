import { readFileSync, writeFileSync, existsSync } from "fs";
import { join } from "path";
import { homedir } from "os";

export interface LifeClipConfig {
  pii: { level: "strict" | "standard" | "off" };
  insights: {
    provider: "tfidf" | "apple-ai" | "claude-api";
    apiKey?: string;
    helperPath?: string;
  };
  locale: string;
}

const CONFIG_PATH = join(homedir(), ".lifeclip", "config.json");

const DEFAULT_CONFIG: LifeClipConfig = {
  pii: { level: "standard" },
  insights: { provider: "tfidf" },
  locale: "zh_CN",
};

export function loadConfig(): LifeClipConfig {
  if (!existsSync(CONFIG_PATH)) return { ...DEFAULT_CONFIG };
  try {
    const raw = JSON.parse(readFileSync(CONFIG_PATH, "utf-8"));
    return { ...DEFAULT_CONFIG, ...raw, pii: { ...DEFAULT_CONFIG.pii, ...raw.pii }, insights: { ...DEFAULT_CONFIG.insights, ...raw.insights } };
  } catch {
    return { ...DEFAULT_CONFIG };
  }
}

export function saveConfig(config: LifeClipConfig): void {
  writeFileSync(CONFIG_PATH, JSON.stringify(config, null, 2), "utf-8");
}

export { CONFIG_PATH };
