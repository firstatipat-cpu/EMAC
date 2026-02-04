from src.core.llm import ask_ai
from src.core.models import AnalystResult
from src.core.config import load_prompts, load_config
def analyze_failure(objective: str, context: str) -> AnalystResult:
    config = load_config()
    prompts = load_prompts()
    return ask_ai(
        prompt=f"Objective: {objective}\nContext: {context}",
        model=config['models']['analyst'],
        response_model=AnalystResult,
        system_prompt=prompts.get('analyst', "You are an analyst.")
    )
