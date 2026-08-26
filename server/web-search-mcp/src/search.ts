import { launch, type Browser, type BrowserContext, type BrowserWorker, type Page } from "@cloudflare/playwright";
import { searchDuckDuckGoDirect } from "./direct-search";
import { hasRelevantResults, refinedSearchQuery } from "./search-query";
import { isSafeExternalURL, sanitizeResults, unwrapBingURL, type RawSearchResult } from "./url-safety";

export type SearchResult = {
  title: string;
  url: string;
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
	try {
		const results = await searchDuckDuckGoDirect(options.query, options.limit, USER_AGENT, SEARCH_TIMEOUT_MS);
		return results.map(result => ({ ...result, content: "" }));
	} catch {
		const refinedQuery = refinedSearchQuery(options.query);
		if (refinedQuery !== options.query) {
			try {
				const results = await searchDuckDuckGoDirect(refinedQuery, options.limit, USER_AGENT, SEARCH_TIMEOUT_MS);
				return results.map(result => ({ ...result, content: "" }));
			} catch {
				// Browser search remains a fallback for providers that require rendered markup.
			}
		}
	}

  let browser: Browser | undefined;

  try {
    browser = await launch(browserBinding);
    const context = await browser.newContext({ userAgent: USER_AGENT, javaScriptEnabled: false });
    await installNetworkGuard(context);

    const page = await context.newPage();
    let results: RawSearchResult[];
    try {
      results = await runRelevantSearch(page, options.query, options.limit);
    } catch {
      const refinedQuery = refinedSearchQuery(options.query);
      if (refinedQuery === options.query) throw new Error("Web search returned no relevant results");
      results = await runRelevantSearch(page, refinedQuery, options.limit);
    }

    if (!options.includeContent) {
      return results;
    }

    const enhanced: SearchResult[] = [];
    for (const result of results) {
      enhanced.push({
        ...result,
        content: await extractPageText(page, result.url, options.maxContentLength).catch(() => "")
      });
    }

    return enhanced;
  } finally {
    await browser?.close();
  }
}

async function runRelevantSearch(page: Page, query: string, limit: number): Promise<RawSearchResult[]> {
  const providers = [searchGoogle, searchBing, searchDuckDuckGo];
  for (const provider of providers) {
    try {
      const results = await provider(page, query, limit);
      if (hasRelevantResults(query, results)) return results;
    } catch {
      continue;
    }
  }

  throw new Error("Web search returned no relevant results");
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
      return {
        title: link?.textContent?.trim() ?? "",
        url: link?.href ?? "",
        description: description?.textContent?.trim() ?? ""
      };
    });
  }, limit);

  const valid = sanitizeResults(results.map(result => ({
    ...result,
    url: unwrapBingURL(result.url)
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
      return {
        title,
        url: anchor?.href ?? "",
        description: blockText.replace(title, "").trim().slice(0, 1_000)
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
  }), limit);
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
      return {
        title: link?.textContent?.trim() ?? "",
        url: link?.href ?? "",
        description: description?.textContent?.trim() ?? ""
      };
    });
  }, limit);

  const valid = sanitizeResults(results.map(result => ({
    ...result,
    url: unwrapDuckDuckGoURL(result.url)
  })), limit);
  if (valid.length === 0) throw new Error("Web search returned no usable results");
  return valid;
}

async function extractPageText(page: Page, url: string, maxLength: number): Promise<string> {
  if (!isSafeExternalURL(url)) return "";

  await page.goto(url, { timeout: PAGE_TIMEOUT_MS, waitUntil: "domcontentloaded" });
  if (!isSafeExternalURL(page.url())) return "";

  return page.locator("body").evaluate((body, length) => {
    const text = (body as HTMLElement).innerText
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
