import { readdirSync, statSync } from "fs";
import { join, extname } from "path";

const SKIP_DIRS = new Set([".obsidian", ".trash", ".git", "node_modules", ".DS_Store"]);

export interface ScannedFile {
  path: string;
  mtime: number; // ms since epoch
  size: number;
}

/** Recursively scan a vault directory for markdown files */
export function scanVault(vaultPath: string): ScannedFile[] {
  const files: ScannedFile[] = [];

  function walk(dir: string) {
    let entries;
    try {
      entries = readdirSync(dir, { withFileTypes: true });
    } catch {
      return;
    }
    for (const entry of entries) {
      if (SKIP_DIRS.has(entry.name)) continue;
      const fullPath = join(dir, entry.name);
      if (entry.isDirectory()) {
        walk(fullPath);
      } else if (extname(entry.name) === ".md") {
        try {
          const stat = statSync(fullPath);
          files.push({ path: fullPath, mtime: stat.mtimeMs, size: stat.size });
        } catch {
          // skip inaccessible files
        }
      }
    }
  }

  walk(vaultPath);
  return files;
}
