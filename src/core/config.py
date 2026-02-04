import yaml
import json
import os
from dotenv import load_dotenv

load_dotenv()

def load_config():
    if not os.path.exists("genome_config.json"): return {}
    with open("genome_config.json") as f: return json.load(f)
def load_prompts():
    if not os.path.exists("src/config/prompts.yaml"): return {}
    with open("src/config/prompts.yaml") as f: return yaml.safe_load(f)
