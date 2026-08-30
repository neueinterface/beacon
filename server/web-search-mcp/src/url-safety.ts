export type RawSearchResult = {
  title: string;
  url: string;
  description: string;
  publishedDate?: string;
  provider?: "duckduckgo" | "google" | "bing";
  providerRank?: number;
};

export function sanitizeResults(results: RawSearchResult[], limit: number): RawSearchResult[] {
  const seen = new Set<string>();
  const sanitized: RawSearchResult[] = [];

  for (const result of results) {
    const { publishedDate: rawPublishedDate, ...rest } = result;
    const title = normalizeText(result.title, 300);
    const description = normalizeText(result.description, 1_000);
    const url = canonicalExternalURL(result.url);
    if (!title || !url || seen.has(url)) continue;
    seen.add(url);
    const publishedDate = normalizePublishedDate(rawPublishedDate);
    sanitized.push({ ...rest, title, url, description, ...(publishedDate ? { publishedDate } : {}) });
    if (sanitized.length >= limit) break;
  }

  return sanitized;
}

export function sourceForURL(value: string): string {
  try {
    return new URL(value).hostname.toLowerCase().replace(/^www\./, "");
  } catch {
    return "";
  }
}

function canonicalExternalURL(value: string): string | undefined {
  if (!isSafeExternalURL(value)) return undefined;

  const url = new URL(value);
  if (url.username || url.password) return undefined;
  url.hash = "";
  for (const key of [...url.searchParams.keys()]) {
    if (/^utm_/i.test(key) || ["fbclid", "gclid", "msclkid"].includes(key.toLowerCase())) {
      url.searchParams.delete(key);
    }
  }
  url.searchParams.sort();
  return url.href;
}

function normalizeText(value: string, maxLength: number): string {
  return value.replace(/[\u0000-\u001f\u007f]/g, " ").replace(/\s+/g, " ").trim().slice(0, maxLength);
}

function normalizePublishedDate(value: string | undefined): string | undefined {
  if (!value) return undefined;
  const date = new Date(value);
  return Number.isNaN(date.valueOf()) ? undefined : date.toISOString().slice(0, 10);
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
