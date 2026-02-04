import requests
import json
import urllib.parse
from duckduckgo_search import DDGS

class SearchEngine:
    def __init__(self):
        self.searx_url = "http://localhost:8081/search"
    
    def search(self, query: str, limit: int = 5):
        """Try SearXNG first, fallback to DuckDuckGo"""
        print(f"🔎 Searching: {query}")
        results = self._search_searxng(query, limit)
        if not results:
            print("⚠️ SearXNG failed/empty. Switching to DuckDuckGo...")
            results = self._search_ddg(query, limit)
        return results

    def _search_searxng(self, query: str, limit: int):
        try:
            params = {
                "q": query,
                "format": "json",
                "categories": "it,dev,science",  # Focus on tech
                "language": "en-US"
            }
            res = requests.get(self.searx_url, params=params, timeout=3)
            if res.status_code == 200:
                data = res.json()
                return self._normalize_results(data.get('results', []), limit)
        except:
            return []
        return []

    def _search_ddg(self, query: str, limit: int):
        try:
            results = list(DDGS().text(query, max_results=limit))
            return [
                {"title": r['title'], "url": r['href'], "snippet": r['body']}
                for r in results
            ]
        except Exception as e:
            print(f"❌ DDG Error: {e}")
            return []

    def _normalize_results(self, raw_results, limit):
        clean = []
        for r in raw_results:
            clean.append({
                "title": r.get('title', ''),
                "url": r.get('url', ''),
                "snippet": r.get('content', '') or r.get('snippet', '')
            })
        return clean[:limit]
