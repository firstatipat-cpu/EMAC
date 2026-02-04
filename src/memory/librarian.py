import chromadb
import os
import datetime
from src.core.config import load_config
class Librarian:
    def __init__(self):
        os.makedirs("chroma_db", exist_ok=True)
        self.client = chromadb.PersistentClient(path="./chroma_db")
        self.collection = self.client.get_or_create_collection("emacs_skills")
        config = load_config()
        self.obsidian_path = config.get("obsidian_vault_path", "./memory_logs")
        os.makedirs(self.obsidian_path, exist_ok=True)
    def recall(self, query: str) -> str:
        try:
            res = self.collection.query(query_texts=[query], n_results=1)
            return res['documents'][0][0] if res['documents'] else ""
        except: return ""
    def memorize(self, objective: str, code: str, filename: str, lesson: str = ""):
        self.collection.add(
            documents=[f"Objective: {objective}\nCode:\n{code}"],
            metadatas=[{"filename": filename}],
            ids=[f"{filename}_{os.urandom(4).hex()}"]
        )
        safe_name = "".join([c for c in objective[:30] if c.isalnum()]).strip() or "skill"
        path = os.path.join(self.obsidian_path, f"{safe_name}.md")
        with open(path, "w", encoding="utf-8") as f:
            f.write(f"# {objective}\n```python\n{code}\n```\n> {lesson}")
