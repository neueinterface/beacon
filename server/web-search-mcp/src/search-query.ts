import type { RawSearchResult } from "./url-safety";

const STOP_WORDS = new Set([
  "a", "an", "and", "are", "did", "do", "does", "for", "from", "how", "i", "in", "is", "it", "most",
  "of", "on", "recent", "the", "to", "was", "were", "what", "when", "where", "which", "who", "why", "won"
]);

export function hasRelevantResults(query: string, results: RawSearchResult[]): boolean {
	return filterRelevantResults(query, results).length > 0;
}

export function filterRelevantResults(query: string, results: RawSearchResult[]): RawSearchResult[] {
  const terms = words(query).filter(term => term.length >= 3 && !STOP_WORDS.has(term));
	if (terms.length === 0) return results;

	const requiredMatches = Math.min(2, terms.length);
	return results.filter(result => {
		const resultTerms = new Set(words(`${result.title} ${result.description}`));
		return terms.filter(term => matchesTerm(term, resultTerms)).length >= requiredMatches;
  });
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

function matchesTerm(term: string, resultTerms: Set<string>): boolean {
	if (resultTerms.has(term)) return true;
	if (term.endsWith("s") && term.length > 3) return resultTerms.has(term.slice(0, -1));
	return resultTerms.has(`${term}s`);
}
