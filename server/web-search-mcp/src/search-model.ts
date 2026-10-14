import { selectBestResults } from "./search-query";
import type { RawSearchResult } from "./url-safety";

export type SearchResult = {
  title: string;
  url: string;
  source: string;
  snippet: string;
  publishedDate?: string;
  imageURL?: string;
  // Kept while older Beacon releases still decode this field.
  description: string;
  content?: string;
};

export function normalizeSearchQueries(query: string | undefined, queries: string[] | undefined): string[] {
  const values = [...(query ? [query] : []), ...(queries ?? [])]
    .map(value => value.trim())
    .filter(Boolean);
  return [...new Set(values)].slice(0, 3);
}

export function mergeSearchResults(results: SearchResult[], queries: string[], limit: number): SearchResult[] {
  const candidates: RawSearchResult[] = results.map((result, providerRank) => ({
    title: result.title,
    url: result.url,
    description: result.description || result.snippet,
    providerRank
  }));
  const selected = selectBestResults(queries.join(" "), candidates, limit);
  const byURL = new Map<string, SearchResult>();
  for (const result of results) {
    const existing = byURL.get(result.url);
    if (!existing || (!existing.content && result.content)) byURL.set(result.url, result);
  }
  const ranked = selected
    .map(result => byURL.get(result.url))
    .filter((result): result is SearchResult => result !== undefined);

  if (ranked.length > 0) return ranked;
  return [...byURL.values()].slice(0, limit);
}
