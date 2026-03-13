#!/usr/bin/env node
import { Command } from "commander";
import { collectCommand } from "./commands/collect.js";
import { timelineCommand } from "./commands/timeline.js";
import { graphCommand } from "./commands/graph.js";
import { contextCommand } from "./commands/context.js";
import { reportCommand } from "./commands/report.js";
import { statusCommand } from "./commands/status.js";
import { configCommand } from "./commands/config.js";
import { insightsCommand } from "./commands/insights.js";
import { viewCommand } from "./commands/view.js";
import { scrubCommand } from "./commands/scrub.js";

const program = new Command();

program
  .name("lifeclip")
  .description("LifeClip — Personal Context Layer for the AI Era")
  .version("0.2.0");

program.addCommand(collectCommand());
program.addCommand(timelineCommand());
program.addCommand(graphCommand());
program.addCommand(contextCommand());
program.addCommand(reportCommand());
program.addCommand(statusCommand());
program.addCommand(configCommand());
program.addCommand(insightsCommand());
program.addCommand(viewCommand());
program.addCommand(scrubCommand());

program.parse();
