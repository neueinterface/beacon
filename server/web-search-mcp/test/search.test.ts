import { describe, expect, it } from "vitest";
import { parseDuckDuckGoHTML } from "../src/direct-search";
import { filterRelevantResults, hasRelevantResults, refinedSearchQuery, selectBestResults } from "../src/search-query";
import { isSafeExternalURL, sanitizeResults, unwrapBingURL } from "../src/url-safety";

describe("search result safety", () => {
  it("accepts public HTTPS URLs", () => {
    expect(isSafeExternalURL("https://example.com/article")).toBe(true);
  });

  it("rejects local and private destinations", () => {
    expect(isSafeExternalURL("http://example.com")).toBe(false);
    expect(isSafeExternalURL("https://localhost/admin")).toBe(false);
    expect(isSafeExternalURL("https://127.0.0.1/admin")).toBe(false);
    expect(isSafeExternalURL("https://8.8.8.8/")).toBe(false);
    expect(isSafeExternalURL("https://10.0.0.1/admin")).toBe(false);
    expect(isSafeExternalURL("https://192.168.1.2/admin")).toBe(false);
    expect(isSafeExternalURL("https://[::1]/admin")).toBe(false);
  });

  it("removes duplicate and invalid search results", () => {
    const results = sanitizeResults([
      { title: "One", url: "https://example.com/one", description: "First" },
      { title: "Duplicate", url: "https://example.com/one", description: "Again" },
      { title: "Private", url: "https://127.0.0.1/", description: "No" }
    ], 5);

    expect(results).toEqual([
      { title: "One", url: "https://example.com/one", description: "First" }
    ]);
  });

  it("canonicalizes tracking URLs before removing duplicates", () => {
    const results = sanitizeResults([
      { title: "Tracked", url: "https://example.com/story?utm_source=test&id=1#section", description: "First" },
      { title: "Duplicate", url: "https://example.com/story?id=1", description: "Again" }
    ], 5);

    expect(results).toEqual([
      { title: "Tracked", url: "https://example.com/story?id=1", description: "First" }
    ]);
  });

  it("normalizes explicit publication dates and omits invalid dates", () => {
    const results = sanitizeResults([
      { title: "Dated", url: "https://example.com/dated", description: "News", publishedDate: "2026-08-28T12:00:00Z" },
      { title: "Undated", url: "https://example.com/undated", description: "News", publishedDate: "not-a-date" }
    ], 5);

    expect(results[0].publishedDate).toBe("2026-08-28");
    expect(results[1].publishedDate).toBeUndefined();
  });

  it("unwraps Bing redirect links", () => {
    const redirect = "https://www.bing.com/ck/a?u=a1aHR0cHM6Ly9kZXZlbG9wZXJzLmNsb3VkZmxhcmUuY29tL3dvcmtlcnMv&ntb=1";

    expect(unwrapBingURL(redirect)).toBe("https://developers.cloudflare.com/workers/");
  });

  it("detects irrelevant search results and refines ambiguous recency queries", () => {
    const dictionaryResults = [{
      title: "WON Definition & Meaning",
      url: "https://example.com/won",
      description: "Past tense of win"
    }];

    expect(hasRelevantResults("who won the most recent World Cup", dictionaryResults)).toBe(false);
    expect(refinedSearchQuery("who won the most recent World Cup", 2026)).toBe("FIFA winner World Cup 2026");
  });

	it("removes individually irrelevant results from a mixed provider response", () => {
		const results = [
			{ title: "MANY Definition & Meaning", url: "https://example.com/many", description: "English dictionary entry" },
			{ title: "Spain at the FIFA World Cup", url: "https://example.com/spain", description: "Spain World Cup titles and appearances" },
			{ title: "Chat Marketing", url: "https://example.com/chat", description: "Automate social messages" }
		];

		expect(filterRelevantResults("how many world cups do spaing have", results)).toEqual([results[1]]);
	});

	it("ranks a relevant FIFA source above an equivalent SEO result", () => {
		const results = [
			{ title: "Spain FIFA World Cup winner 2010", url: "https://football-example.com/spain", description: "Spain won the tournament in 2010." },
			{ title: "Spain FIFA World Cup winner 2010", url: "https://inside.fifa.com/tournaments/spain", description: "Spain won the tournament in 2010." }
		];

		expect(selectBestResults("Spain FIFA World Cup winning year", results, 3)).toEqual([results[1]]);
	});

	it("does not keep a trusted but irrelevant result", () => {
		const relevant = { title: "Spain FIFA World Cup winner", url: "https://example.com/spain", description: "Spain won in 2010." };
		const irrelevant = { title: "FIFA ticket information", url: "https://fifa.com/tickets", description: "Buy tickets for upcoming matches." };

		expect(selectBestResults("Spain FIFA World Cup winning year", [irrelevant, relevant], 3)).toEqual([relevant]);
	});

	it("parses direct DuckDuckGo results without a browser session", () => {
		const html = `
			<div class="result results_links web-result"><div class="result__body">
				<a class="result__a" href="//duckduckgo.com/l/?uddg=https%3A%2F%2Finside.fifa.com%2Fchampions&amp;rut=test">Spain &amp; the World Cup</a>
				<a class="result__snippet"><b>Spain</b> won 1&#x2D;0.</a>
				<div class="clear"></div>
			</div></div>`;

		expect(parseDuckDuckGoHTML(html, 3)).toEqual([{
			title: "Spain & the World Cup",
			url: "https://inside.fifa.com/champions",
			description: "Spain won 1-0."
		}]);
	});
});
