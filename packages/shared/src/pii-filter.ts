/** PII filter — redacts sensitive information from text and metadata */

export type PIILevel = "strict" | "standard" | "off";

/** Redact PII from text based on the given level */
export function redactPII(text: string, level: PIILevel = "standard"): string {
  if (level === "off") return text;

  let result = text;

  // === standard level ===

  // Email addresses
  result = result.replace(
    /[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}/g,
    "[email]"
  );
  // Phone numbers (international and Chinese formats)
  result = result.replace(
    /(\+?\d{1,3}[-.\s]?)?\(?\d{3}\)?[-.\s]?\d{3,4}[-.\s]?\d{4}/g,
    "[phone]"
  );
  // Chinese phone numbers
  result = result.replace(/1[3-9]\d{9}/g, "[phone]");
  // Credit card numbers
  result = result.replace(/\b\d{4}[-\s]?\d{4}[-\s]?\d{4}[-\s]?\d{4}\b/g, "[card]");
  // IP addresses
  result = result.replace(/\b\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3}\b/g, "[ip]");
  // API keys and tokens
  result = result.replace(/\bsk-[A-Za-z0-9]{20,}\b/g, "[api_key]");
  result = result.replace(/\bghp_[A-Za-z0-9]{36,}\b/g, "[api_key]");
  result = result.replace(/\bgho_[A-Za-z0-9]{36,}\b/g, "[api_key]");
  result = result.replace(/\bglpat-[A-Za-z0-9_-]{20,}\b/g, "[api_key]");
  result = result.replace(/Bearer\s+[A-Za-z0-9._\-]{20,}/g, "Bearer [token]");
  result = result.replace(/token=[A-Za-z0-9._\-]{10,}/gi, "token=[redacted]");
  result = result.replace(/API_KEY=[^\s&"']{5,}/gi, "API_KEY=[redacted]");
  result = result.replace(/api[_-]?key["']?\s*[:=]\s*["']?[A-Za-z0-9._\-]{10,}/gi, "api_key=[redacted]");
  // Chinese ID card (18 digits, last may be X)
  result = result.replace(/\b\d{6}(19|20)\d{2}(0[1-9]|1[0-2])(0[1-9]|[12]\d|3[01])\d{3}[\dXx]\b/g, "[id_card]");

  // === strict level ===
  if (level === "strict") {
    // URL query parameters and fragments
    result = redactURLParams(result);
    // File path usernames: /Users/xxx/ → /Users/[user]/
    result = result.replace(/\/Users\/[A-Za-z0-9._-]+\//g, "/Users/[user]/");
    result = result.replace(/\/home\/[A-Za-z0-9._-]+\//g, "/home/[user]/");
    result = result.replace(/C:\\Users\\[A-Za-z0-9._-]+\\/gi, "C:\\Users\\[user]\\");
  }

  return result;
}

/** Redact URL query parameters and fragments — preserves domain + path */
export function redactURL(url: string): string {
  try {
    const parsed = new URL(url);
    return `${parsed.origin}${parsed.pathname}`;
  } catch {
    // Not a valid URL, try regex fallback
    return url.replace(/[?#].*$/, "");
  }
}

/** Apply redactURLParams within text — finds URLs and strips query/fragment */
function redactURLParams(text: string): string {
  return text.replace(/https?:\/\/[^\s"'<>]+/g, (match) => redactURL(match));
}

/** Recursively redact string values in metadata objects */
export function redactMetadata(
  obj: Record<string, unknown>,
  level: PIILevel = "standard"
): Record<string, unknown> {
  if (level === "off") return obj;
  const result: Record<string, unknown> = {};
  for (const [key, value] of Object.entries(obj)) {
    if (typeof value === "string") {
      // Special handling for URL fields
      if (key === "url" || key === "href") {
        result[key] = level === "strict" ? redactURL(value) : redactPII(value, level);
      } else if (key === "filePath" || key === "path") {
        result[key] = level === "strict"
          ? value.replace(/\/Users\/[A-Za-z0-9._-]+\//g, "/Users/[user]/")
              .replace(/\/home\/[A-Za-z0-9._-]+\//g, "/home/[user]/")
          : value;
      } else {
        result[key] = redactPII(value, level);
      }
    } else if (value !== null && typeof value === "object" && !Array.isArray(value)) {
      result[key] = redactMetadata(value as Record<string, unknown>, level);
    } else {
      result[key] = value;
    }
  }
  return result;
}

/** Truncate content to max length, preserving word boundaries */
export function truncate(text: string, maxLen: number = 200): string {
  if (text.length <= maxLen) return text;
  const truncated = text.slice(0, maxLen);
  const lastSpace = truncated.lastIndexOf(" ");
  return (lastSpace > maxLen * 0.8 ? truncated.slice(0, lastSpace) : truncated) + "\u2026";
}
