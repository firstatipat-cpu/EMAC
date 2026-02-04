import os
import requests
import urllib.parse
from src.core.sandbox import DockerSandbox

_sandbox_instance = None

def get_sandbox():
    global _sandbox_instance
    if _sandbox_instance is None:
        _sandbox_instance = DockerSandbox()
    return _sandbox_instance

def web_search(query: str) -> str:
    try:
        url = f"http://localhost:8081/search?q={urllib.parse.quote(query)}&format=json"
        res = requests.get(url, timeout=5)
        if res.status_code == 200:
            results = res.json().get('results', [])[:3]
            return "\n".join([f"- {r['title']}: {r['url']}" for r in results])
    except: pass
    return "Search failed."

def read_file(filename: str) -> str:
    path = os.path.join("workspace", filename)
    if os.path.exists(path):
        with open(path, 'r') as f: return f.read()
    return "File not found."

def run_shell(command: str) -> str:
    sb = get_sandbox()
    forbidden = ["docker", "sudo", "rm -rf /"] 
    if any(f in command for f in forbidden): return "Command blocked."
    return sb.run_shell(command)
    
def list_files(dummy: str="") -> str:
    return run_shell("ls -la")
