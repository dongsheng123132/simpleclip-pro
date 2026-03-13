import { readFileSync } from "fs";
import { basename } from "path";
import matter from "gray-matter";
import type { LifeClipEvent } from "@lifeclip/shared";
import { createEvent, truncate, redactPII } from "@lifeclip/shared";

/** Extract metadata + summary from a markdown file */
export function extractNote(filePath: string, mtime: number): LifeClipEvent {
  const raw = readFileSync(filePath, "utf-8");
  const { data: frontmatter, content } = matter(raw);

  // Extract tags from frontmatter and inline #tags
  const tags: string[] = [];
  if (Array.isArray(frontmatter.tags)) {
    tags.push(...frontmatter.tags.map(String));
  }
  const inlineTags = content.match(/#[\w\u4e00-\u9fff]+/g);
  if (inlineTags) {
    tags.push(...inlineTags.map((t) => t.slice(1)));
  }

  // Extract [[wiki-links]]
  const wikiLinks: string[] = [];
  const linkMatches = content.matchAll(/\[\[([^\]]+)\]\]/g);
  for (const m of linkMatches) {
    wikiLinks.push(m[1].split("|")[0]); // handle [[link|alias]]
  }

  const title = frontmatter.title || basename(filePath, ".md");
  const summary = redactPII(truncate(content.replace(/^#+ .+$/gm, "").trim(), 200));
  const safeFilePath = filePath.replace(/\/Users\/[A-Za-z0-9._-]+\//g, "/Users/[user]/");

  return createEvent({
    source: "note",
    type: mtime ? "note_edit" : "note_create",
    timestamp: new Date(mtime).toISOString(),
    content: `${title}: ${summary}`,
    metadata: {
      filePath: safeFilePath,
      title,
      frontmatter: Object.keys(frontmatter).length > 0 ? frontmatter : undefined,
      wikiLinks: wikiLinks.length > 0 ? wikiLinks : undefined,
    },
    tags: [...new Set(tags)],
  });
}
