import { launch, type Browser, type BrowserContext, type BrowserWorker, type Page } from "@cloudflare/playwright";
import { searchDuckDuckGoDirect } from "./direct-search";
import { refinedSearchQuery, selectBestResults } from "./search-query";
import { isSafeExternalURL, sanitizeResults, sourceForURL, unwrapBingURL, type RawSearchResult } from "./url-safety";

export type SearchResult = {
  title: string;
  url: string;
  source: string;
  snippet: string;
  publishedDate?: string;
  // Kept while older Beacon releases still decode this field.
  description: string;
  content?: string;
};

export type SearchOptions = {
  query: string;
  limit: number;
  includeContent: boolean;
  maxContentLength: number;
};

const SEARCH_TIMEOUT_MS = 12_000;
const PAGE_TIMEOUT_MS = 8_000;
const USER_AGENT = "Mozilla/5.0 (iPhone; CPU iPhone OS 18_0 like Mac OS X) AppleWebKit/605.1.15 Version/18.0 Mobile/15E148 Safari/604.1";

export async function searchWeb(browserBinding: BrowserWorker, options: SearchOptions): Promise<SearchResult[]> {
  const candidateLimit = Math.min(15, Math.max(10, options.limit * 3));
  const minimumResults = Math.min(3, options.limit);
  const candidates: RawSearchResult[] = [];
  const refinedQuery = refinedSearchQuery(options.query);

	try {
		candidates.push(...await searchDuckDuckGoDirect(options.query, candidateLimit, USER_AGENT, SEARCH_TIMEOUT_MS));
	} catch {
		// Browser search remains a fallback when direct HTML search is unavailable.
	}

  let selected = selectBestResults(options.query, candidates, options.limit);
  if (selected.length < minimumResults && refinedQuery !== options.query) {
    try {
      candidates.push(...await searchDuckDuckGoDirect(refinedQuery, candidateLimit, USER_AGENT, SEARCH_TIMEOUT_MS));
      selected = selectBestResults(options.query, candidates, options.limit);
    } catch {
      // Continue to rendered providers below.
    }
  }

  if (selected.length >= minimumResults && !options.includeContent) {
    return selected.map(normalizeResult);
  }

  let browser: Browser | undefined;

  try {
    browser = await launch(browserBinding);
    const context = await browser.newContext({ userAgent: USER_AGENT, javaScriptEnabled: false });
    await installNetworkGuard(context);

    const page = await context.newPage();
    if (selected.length < minimumResults) {
      candidates.push(...await runSearchCandidates(page, options.query, candidateLimit, minimumResults));
      selected = selectBestResults(options.query, candidates, options.limit);
    }
    if (selected.length < minimumResults && refinedQuery !== options.query) {
      candidates.push(...await runSearchCandidates(page, refinedQuery, candidateLimit, minimumResults));
      selected = selectBestResults(options.query, candidates, options.limit);
    }
    if (selected.length === 0) throw new Error("Web search returned no relevant results");

    if (!options.includeContent) {
      return selected.map(normalizeResult);
    }

    const enhanced: SearchResult[] = [];
    for (const result of selected) {
      enhanced.push({
        ...normalizeResult(result),
        content: await extractPageText(page, result.url, options.maxContentLength).catch(() => "")
      });
    }

    return enhanced;
  } finally {
    await browser?.close();
  }
}

async function runSearchCandidates(page: Page, query: string, limit: number, minimumResults: number): Promise<RawSearchResult[]> {
  const providers = [searchGoogle, searchBing, searchDuckDuckGo];
  const candidates: RawSearchResult[] = [];
  for (const provider of providers) {
    try {
      candidates.push(...await provider(page, query, limit));
      if (selectBestResults(query, candidates, minimumResults).length >= minimumResults) break;
    } catch {
      continue;
    }
  }

  return candidates;
}

function normalizeResult(result: RawSearchResult): SearchResult {
  return {
    title: result.title,
    url: result.url,
    source: sourceForURL(result.url),
    snippet: result.description,
    ...(result.publishedDate ? { publishedDate: result.publishedDate } : {}),
    description: result.description
  };
}

async function installNetworkGuard(context: BrowserContext): Promise<void> {
  await context.route("**/*", async route => {
    if (isSafeExternalURL(route.request().url())) {
      await route.continue();
    } else {
      await route.abort("blockedbyclient");
    }
  });
}

async function searchBing(page: Page, query: string, limit: number): Promise<RawSearchResult[]> {
  await page.goto(`https://www.bing.com/search?q=${encodeURIComponent(query)}`, {
    timeout: SEARCH_TIMEOUT_MS,
    waitUntil: "domcontentloaded"
  });

  const results = await page.locator("li.b_algo").evaluateAll((items, maxResults) => {
    return items.slice(0, maxResults).map(item => {
      const link = item.querySelector<HTMLAnchorElement>("h2 a");
      const description = item.querySelector<HTMLElement>(".b_caption p");
      const publishedDate = item.querySelector<HTMLTimeElement>("time[datetime]")?.dateTime;
      return {
        title: link?.textContent?.trim() ?? "",
        url: link?.href ?? "",
        description: description?.textContent?.trim() ?? "",
        publishedDate
      };
    });
  }, limit);

  const valid = sanitizeResults(results.map((result, providerRank) => ({
    ...result,
    url: unwrapBingURL(result.url),
    provider: "bing" as const,
    providerRank
  })), limit);
  if (valid.length === 0) throw new Error("Bing returned no usable results");
  return valid;
}

async function searchGoogle(page: Page, query: string, limit: number): Promise<RawSearchResult[]> {
  await page.goto(`https://www.google.com/search?q=${encodeURIComponent(query)}&num=${limit}&hl=en`, {
    timeout: SEARCH_TIMEOUT_MS,
    waitUntil: "domcontentloaded"
  });

  const results = await page.locator("h3").evaluateAll((headings, maxResults) => {
    return headings.slice(0, maxResults * 2).map(heading => {
      const anchor = heading.closest("a") as HTMLAnchorElement | null;
      const title = heading.textContent?.trim() ?? "";
      const container = anchor?.closest("div.MjjYud") ?? anchor?.parentElement?.parentElement?.parentElement;
      const blockText = container?.textContent?.replace(/\s+/g, " ").trim() ?? "";
      const publishedDate = container?.querySelector<HTMLTimeElement>("time[datetime]")?.dateTime;
      return {
        title,
        url: anchor?.href ?? "",
        description: blockText.replace(title, "").trim().slice(0, 1_000),
        publishedDate
      };
    });
  }, limit);

  const valid = sanitizeResults(results.filter(result => {
    try {
      const url = new URL(result.url);
      return !url.hostname.endsWith("google.com") && !url.hostname.endsWith("googleusercontent.com");
    } catch {
      return false;
    }
  }).map((result, providerRank) => ({ ...result, provider: "google" as const, providerRank })), limit);
  if (valid.length === 0) throw new Error("Google returned no usable results");
  return valid;
}

async function searchDuckDuckGo(page: Page, query: string, limit: number): Promise<RawSearchResult[]> {
  await page.goto(`https://html.duckduckgo.com/html/?q=${encodeURIComponent(query)}`, {
    timeout: SEARCH_TIMEOUT_MS,
    waitUntil: "domcontentloaded"
  });

  const results = await page.locator(".result").evaluateAll((items, maxResults) => {
    return items.slice(0, maxResults).map(item => {
      const link = item.querySelector<HTMLAnchorElement>(".result__a");
      const description = item.querySelector<HTMLElement>(".result__snippet");
      const publishedDate = item.querySelector<HTMLTimeElement>("time[datetime]")?.dateTime;
      return {
        title: link?.textContent?.trim() ?? "",
        url: link?.href ?? "",
        description: description?.textContent?.trim() ?? "",
        publishedDate
      };
    });
  }, limit);

  const valid = sanitizeResults(results.map((result, providerRank) => ({
    ...result,
    url: unwrapDuckDuckGoURL(result.url),
    provider: "duckduckgo" as const,
    providerRank
  })), limit);
  if (valid.length === 0) throw new Error("Web search returned no usable results");
  return valid;
}

async function extractPageText(page: Page, url: string, maxLength: number): Promise<string> {
  if (!isSafeExternalURL(url)) return "";

  await page.goto(url, { timeout: PAGE_TIMEOUT_MS, waitUntil: "domcontentloaded" });
  if (!isSafeExternalURL(page.url())) return "";

  const primaryContent = page.locator("main, article").first();
  const target = await primaryContent.count() > 0 ? primaryContent : page.locator("body");
  return target.evaluate((element, length) => {
    const text = (element as HTMLElement).innerText
      .replace(/\n{3,}/g, "\n\n")
      .replace(/[ \t]{2,}/g, " ")
      .trim();
    return text.slice(0, length);
  }, maxLength);
}

function unwrapDuckDuckGoURL(value: string): string {
  try {
    const url = new URL(value);
    return url.searchParams.get("uddg") ?? value;
  } catch {
    return value;
  }
}
