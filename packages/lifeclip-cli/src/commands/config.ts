import { Command } from "commander";
import { loadConfig, saveConfig, CONFIG_PATH } from "@lifeclip/shared";

export function configCommand(): Command {
  const cmd = new Command("config")
    .description("View or modify LifeClip configuration")
    .option("--set <key=value>", "Set a config value (e.g. pii.level=strict)")
    .action((opts) => {
      const config = loadConfig();

      if (opts.set) {
        const [key, value] = (opts.set as string).split("=");
        if (!key || !value) {
          console.error("Usage: lifeclip config --set key=value");
          return;
        }
        const parts = key.split(".");
        if (parts[0] === "pii" && parts[1] === "level") {
          if (!["strict", "standard", "off"].includes(value)) {
            console.error("pii.level must be: strict | standard | off");
            return;
          }
          config.pii.level = value as "strict" | "standard" | "off";
        } else if (parts[0] === "insights" && parts[1] === "provider") {
          if (!["tfidf", "apple-ai", "claude-api"].includes(value)) {
            console.error("insights.provider must be: tfidf | apple-ai | claude-api");
            return;
          }
          config.insights.provider = value as "tfidf" | "apple-ai" | "claude-api";
        } else if (parts[0] === "insights" && parts[1] === "apiKey") {
          config.insights.apiKey = value;
        } else if (parts[0] === "insights" && parts[1] === "helperPath") {
          config.insights.helperPath = value;
        } else if (parts[0] === "locale") {
          config.locale = value;
        } else {
          console.error(`Unknown config key: ${key}`);
          return;
        }
        saveConfig(config);
        console.log(`Set ${key} = ${parts[0] === "insights" && parts[1] === "apiKey" ? maskKey(value) : value}`);
        console.log(`Config saved to ${CONFIG_PATH}`);
      } else {
        console.log("LifeClip Configuration\n");
        console.log(`  pii.level:            ${config.pii.level}`);
        console.log(`  insights.provider:    ${config.insights.provider}`);
        console.log(`  insights.apiKey:      ${config.insights.apiKey ? maskKey(config.insights.apiKey) : "(not set)"}`);
        console.log(`  insights.helperPath:  ${config.insights.helperPath ?? "(auto-detect)"}`);
        console.log(`  locale:               ${config.locale}`);
        console.log(`\nConfig file: ${CONFIG_PATH}`);
      }
    });

  return cmd;
}

function maskKey(key: string): string {
  if (key.length <= 8) return "***";
  return key.slice(0, 5) + "..." + key.slice(-3);
}
