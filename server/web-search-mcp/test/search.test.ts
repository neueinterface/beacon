import { describe, expect, it } from "vitest";
import { parseDuckDuckGoHTML } from "../src/direct-search";
import { filterRelevantResults, hasRelevantResults, refinedSearchQuery } from "../src/search-query";
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
