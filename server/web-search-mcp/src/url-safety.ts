export type RawSearchResult = {
  title: string;
  url: string;
  description: string;
};

export function sanitizeResults(results: RawSearchResult[], limit: number): RawSearchResult[] {
  const seen = new Set<string>();
  const sanitized: RawSearchResult[] = [];

  for (const result of results) {
    const title = result.title.trim().slice(0, 300);
    const description = result.description.trim().slice(0, 1_000);
    if (!title || !isSafeExternalURL(result.url) || seen.has(result.url)) continue;
    seen.add(result.url);
    sanitized.push({ title, url: result.url, description });
    if (sanitized.length >= limit) break;
  }

  return sanitized;
}

export function isSafeExternalURL(value: string): boolean {
  try {
    const url = new URL(value);
    if (url.protocol !== "https:") return false;

    const hostname = url.hostname.toLowerCase().replace(/^\[|\]$/g, "");
    if (!hostname || hostname === "localhost" || hostname.endsWith(".local") || hostname.endsWith(".internal")) return false;
    if (hostname.includes(":")) return false;

    const octets = hostname.split(".").map(Number);
    if (octets.length === 4 && octets.every(octet => Number.isInteger(octet) && octet >= 0 && octet <= 255)) {
      return false;
    }

    return true;
  } catch {
    return false;
  }
}

export function unwrapBingURL(value: string): string {
  try {
    const url = new URL(value);
    const encoded = url.hostname.endsWith("bing.com") ? url.searchParams.get("u") : null;
    if (!encoded?.startsWith("a1")) return value;

    const base64 = encoded.slice(2).replace(/-/g, "+").replace(/_/g, "/");
    return atob(base64.padEnd(Math.ceil(base64.length / 4) * 4, "="));
  } catch {
    return value;
  }
}
