import { isSafeExternalURL, sanitizeResults, type RawSearchResult } from "./url-safety";

export async function searchDuckDuckGoDirect(query: string, limit: number, userAgent: string, timeout: number): Promise<RawSearchResult[]> {
  const response = await fetch(`https://html.duckduckgo.com/html/?q=${encodeURIComponent(query)}`, {
    headers: { "User-Agent": userAgent },
    signal: AbortSignal.timeout(timeout)
  });
  if (!response.ok) throw new Error(`DuckDuckGo returned HTTP ${response.status}`);

  return parseDuckDuckGoHTML(await boundedResponseText(response, 512_000), limit).map((result, providerRank) => ({
    ...result,
    provider: "duckduckgo",
    providerRank
  }));
}

export function parseDuckDuckGoHTML(html: string, limit: number): RawSearchResult[] {
  const results: RawSearchResult[] = [];
  const blocks = html.match(/<div class="result results_links[\s\S]*?<div class="clear"><\/div>[\s\S]*?<\/div>\s*<\/div>/gi) ?? [];

  for (const block of blocks) {
    const link = block.match(/<a[^>]*class="result__a"[^>]*href="([^"]+)"[^>]*>([\s\S]*?)<\/a>/i);
    if (!link) continue;
    const snippet = block.match(/<a[^>]*class="result__snippet"[^>]*>([\s\S]*?)<\/a>/i);
    const href = decodeHTMLEntities(link[1]);
    const absoluteURL = new URL(href, "https://duckduckgo.com").href;
    results.push({
      title: plainText(link[2]),
      url: unwrapDuckDuckGoURL(absoluteURL),
      description: plainText(snippet?.[1] ?? "")
    });
  }

  return sanitizeResults(results, limit);
}

export function extractDirectPageData(html: string, url: string, maxLength: number): { content: string; imageURL?: string } {
  const meta = html.match(/<meta\b[^>]*\b(?:property|name)=["'](?:og:image|twitter:image)["'][^>]*>/i)?.[0];
  const rawImage = meta?.match(/\bcontent=["']([^"']+)["']/i)?.[1];
  let imageURL: string | undefined;
  if (rawImage) {
    try {
      const candidate = new URL(rawImage.replace(/&amp;/g, "&"), url).href;
      if (isSafeExternalURL(candidate)) imageURL = candidate;
    } catch {
      // An invalid image URL does not prevent the page text from being used.
    }
  }

  const body = html.match(/<main\b[^>]*>([\s\S]*?)(?:<\/main>|$)/i)?.[1]
    ?? html.match(/<article\b[^>]*>([\s\S]*?)(?:<\/article>|$)/i)?.[1]
    ?? html.match(/<body\b[^>]*>([\s\S]*)/i)?.[1]
    ?? "";
  const content = plainText(body.replace(/<(script|style|nav|header|footer|form)\b[^>]*>[\s\S]*?<\/\1>/gi, " ")).slice(0, maxLength);
  return { content, ...(imageURL ? { imageURL } : {}) };
}

export async function boundedResponseText(response: Response, maxBytes: number, truncate = false): Promise<string> {
  if (!response.body) return "";
  const reader = response.body.getReader();
  const decoder = new TextDecoder();
  let output = "";
  let bytesRead = 0;

  while (true) {
    const { done, value } = await reader.read();
    if (done) break;
    bytesRead += value.byteLength;
    if (bytesRead > maxBytes) {
      await reader.cancel();
      if (!truncate) throw new Error("Search response exceeded the size limit");
      output += decoder.decode(value.subarray(0, value.byteLength - (bytesRead - maxBytes)), { stream: true });
      break;
    }
    output += decoder.decode(value, { stream: true });
  }

  return output + decoder.decode();
}

export function plainText(value: string): string {
  return decodeHTMLEntities(value.replace(/<[^>]+>/g, " ")).replace(/\s+/g, " ").trim();
}

function decodeHTMLEntities(value: string): string {
  const named = { amp: "&", apos: "'", gt: ">", lt: "<", quot: '"' } as const;
  return value.replace(/&(#x?[0-9a-f]+|amp|apos|gt|lt|quot);/gi, (_, entity: string) => {
    if (entity[0] === "#") {
      const isHex = entity[1]?.toLowerCase() === "x";
      const codePoint = Number.parseInt(entity.slice(isHex ? 2 : 1), isHex ? 16 : 10);
      return Number.isFinite(codePoint) ? String.fromCodePoint(codePoint) : "";
    }
    return named[entity.toLowerCase() as keyof typeof named] ?? "";
  });
}

function unwrapDuckDuckGoURL(value: string): string {
  try {
    const url = new URL(value);
    return url.searchParams.get("uddg") ?? value;
  } catch {
    return value;
  }
}
