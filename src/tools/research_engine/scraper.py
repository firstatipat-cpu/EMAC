import trafilatura
import requests
from bs4 import BeautifulSoup

class WebScraper:
    def scrape(self, url: str) -> str:
        """Download and extract clean text from URL"""
        try:
            downloaded = trafilatura.fetch_url(url)
            if downloaded:
                # Try Trafilatura extraction (Best for articles/blogs)
                text = trafilatura.extract(downloaded, include_comments=False, include_tables=True)
                if text:
                    return self._post_process(text)
            
            # Fallback: BeautifulSoup (Better for some doc sites)
            return self._fallback_scrape(url)
        except Exception as e:
            return f"Error scraping {url}: {e}"

    def _fallback_scrape(self, url):
        try:
            res = requests.get(url, timeout=10, headers={"User-Agent": "EMACS-RESEARCHER/1.0"})
            soup = BeautifulSoup(res.text, 'html.parser')
            
            # Kill script and style elements
            for script in soup(["script", "style", "nav", "footer"]):
                script.extract()    

            text = soup.get_text()
            # Break into lines and remove leading and trailing space on each
            lines = (line.strip() for line in text.splitlines())
            # Break multi-headlines into a line each
            chunks = (phrase.strip() for line in lines for phrase in line.split("  "))
            # Drop blank lines
            text = '\n'.join(chunk for chunk in chunks if chunk)
            return text[:10000] # Limit length
        except:
            return "Failed to scrape."

    def _post_process(self, text):
        """Limit tokens and remove noise"""
        return text[:15000] # Cap at ~3-4k tokens
