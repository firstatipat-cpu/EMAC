from src.core.llm import ask_ai
from src.core.models import Critique
from src.core.config import load_prompts, load_config
import re

def review_code(filename: str, logs: str) -> Critique:
    prompts = load_prompts()
    config = load_config()
    
    if not logs or logs.strip() == "" or logs.strip() == "(No Output)":
        return Critique(is_passing=False, feedback="Silent Error (No Output)", suggested_fix="Add print()")

    line_hint = ""
    match = re.search(r'line (\d+)', logs)
    if match: line_hint = f" (Line {match.group(1)})"

    return ask_ai(
        prompt=f"Logs{line_hint}:\n{logs}",
        model=config['models']['critic'],
        response_model=Critique,
        system_prompt=prompts.get('critic', "You are a QA.")
    )
