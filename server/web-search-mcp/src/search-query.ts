import { sourceForURL, type RawSearchResult } from "./url-safety";

const STOP_WORDS = new Set([
  "a", "an", "and", "are", "did", "do", "does", "for", "from", "how", "i", "in", "is", "it", "most",
  "latest", "of", "on", "recent", "the", "to", "was", "were", "what", "when", "where", "which", "who", "why", "won"
]);

const OFFICIAL_DOMAINS = ["fifa.com", "swift.org", "apple.com", "openai.com", "who.int", "un.org"];
const RECOGNIZED_DOMAINS = [
	"apnews.com", "bbc.com", "bloomberg.com", "britannica.com", "nature.com", "nytimes.com", "people.com", "reuters.com",
  "theguardian.com", "wikipedia.org"
];

export function hasRelevantResults(query: string, results: RawSearchResult[]): boolean {
	return filterRelevantResults(query, results).length > 0;
}

export function filterRelevantResults(query: string, results: RawSearchResult[]): RawSearchResult[] {
  return results.filter(result => relevanceScore(query, result) > 0);
}

export function selectBestResults(query: string, results: RawSearchResult[], limit: number): RawSearchResult[] {
  const ranked = results
    .map((result, index) => ({ result, index, relevance: relevanceScore(query, result) }))
    .filter(candidate => candidate.relevance > 0)
    .map(candidate => ({ ...candidate, score: candidate.relevance + trustScore(candidate.result.url) }))
    .sort((left, right) => right.score - left.score
      || (left.result.providerRank ?? Number.MAX_SAFE_INTEGER) - (right.result.providerRank ?? Number.MAX_SAFE_INTEGER)
      || left.index - right.index);

  const selected: RawSearchResult[] = [];
  for (const candidate of ranked) {
    if (selected.some(result => areNearDuplicates(result, candidate.result))) continue;
    selected.push(candidate.result);
    if (selected.length >= limit) break;
  }
  return selected;
}

export function refinedSearchQuery(query: string, year = new Date().getUTCFullYear()): string {
  const normalized = query
    .replace(/\bwon\b/gi, "winner")
    .replace(/\b(who|what|when|where|which|how)\b/gi, " ")
    .replace(/\b(the )?(most recent|latest|current)\b/gi, " ")
    .replace(/\s+/g, " ")
    .trim();

  if (/\bworld cup\b/i.test(normalized) && !/\b(fifa|cricket|rugby|basketball|hockey)\b/i.test(normalized)) {
    return `FIFA ${normalized} ${year}`.trim();
  }

  return `${normalized || query} ${year}`.trim();
}

function words(value: string): string[] {
  return value.toLowerCase().match(/[a-z0-9]+/g) ?? [];
}

function relevanceScore(query: string, result: RawSearchResult): number {
  const terms = [...new Set(words(query).filter(term => term.length >= 3 && !STOP_WORDS.has(term)))];
  if (terms.length === 0) return 1;

  const titleTerms = new Set(words(result.title));
  const snippetTerms = new Set(words(result.description));
  const sourceTerms = new Set(words(sourceForURL(result.url)));
  const matches = terms.filter(term => matchesTerm(term, titleTerms) || matchesTerm(term, snippetTerms) || matchesTerm(term, sourceTerms));
  const requiredMatches = Math.min(2, terms.length);
  if (matches.length < requiredMatches) return 0;

  const titleMatches = terms.filter(term => matchesTerm(term, titleTerms)).length;
  const snippetMatches = terms.filter(term => matchesTerm(term, snippetTerms)).length;
  const coverage = matches.length / terms.length;
  return titleMatches * 4 + snippetMatches * 1.5 + coverage * 8;
}

function trustScore(value: string): number {
  const source = sourceForURL(value);
  if (matchesDomain(source, OFFICIAL_DOMAINS) || source.endsWith(".gov") || source.endsWith(".edu")) return 12;
  if (matchesDomain(source, RECOGNIZED_DOMAINS)) return 6;
  return 0;
}

function matchesDomain(source: string, domains: string[]): boolean {
  return domains.some(domain => source === domain || source.endsWith(`.${domain}`));
}

function areNearDuplicates(left: RawSearchResult, right: RawSearchResult): boolean {
  if (left.url === right.url) return true;
  const leftWords = new Set(words(left.title));
  const rightWords = new Set(words(right.title));
  if (leftWords.size === 0 || rightWords.size === 0) return false;
  const intersection = [...leftWords].filter(word => rightWords.has(word)).length;
  const union = new Set([...leftWords, ...rightWords]).size;
  return intersection / union >= 0.8;
}

function matchesTerm(term: string, resultTerms: Set<string>): boolean {
	if (resultTerms.has(term)) return true;
	if (term.endsWith("s") && term.length > 3) return resultTerms.has(term.slice(0, -1));
	return resultTerms.has(`${term}s`);
}
