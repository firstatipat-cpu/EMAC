from src.core.llm import ask_ai
from src.core.config import load_prompts, load_config
from src.tools.research_engine.searcher import SearchEngine
from src.tools.research_engine.scraper import WebScraper
from pydantic import BaseModel
from typing import List

class ResearchResult(BaseModel):
    summary: str
    code_snippets: List[str]
    sources: List[str]

class Researcher:
    def __init__(self):
        self.searcher = SearchEngine()
        self.scraper = WebScraper()
        self.config = load_config()
        self.prompts = load_prompts()

    def research(self, query: str) -> ResearchResult:
        print(f"🕵️ Researcher processing: {query}")
        
        # 1. Search
        links = self.searcher.search(query, limit=3)
        if not links:
            return ResearchResult(summary="No online sources found.", code_snippets=[], sources=[])

        # 2. Scrape & Aggregate
        context = ""
        valid_sources = []
        for link in links:
            print(f"   Reading: {link['title']}")
            content = self.scraper.scrape(link['url'])
            if len(content) > 100:
                context += f"\n--- Source: {link['url']} ---\n{content[:5000]}\n"
                valid_sources.append(link['url'])

        # 3. Synthesize (LLM)
        print("   🧠 Synthesizing...")
        
        # Safe string formatting
        prompt = (
            f"Objective: {query}\n\n"
            "Research Materials:\n"
            f"{context}\n\n"
            "Task: Extract key technical facts, API usage patterns, and code examples relevant to the objective.\n"
            "Ignore marketing fluff. Focus on implementation details."
        )
        
        return ask_ai(
            prompt=prompt,
            model=self.config['models']['planner'], # Use smart model
            response_model=ResearchResult,
            system_prompt=self.prompts.get('researcher', "You are a Technical Researcher.")
        )