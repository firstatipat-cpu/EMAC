import instructor
from openai import OpenAI
from pydantic import BaseModel
from typing import Type, TypeVar

# Timeout 300s (5 mins) to prevent hanging on CPU/Slow GPU
client = instructor.patch(
    OpenAI(base_url="http://localhost:11434/v1", api_key="ollama", timeout=300.0), 
    mode=instructor.Mode.JSON
)
T = TypeVar("T", bound=BaseModel)
def ask_ai(prompt: str, model: str, response_model: Type[T], system_prompt: str) -> T:
    try:
        return client.chat.completions.create(
            model=model,
            messages=[{"role": "system", "content": system_prompt}, {"role": "user", "content": prompt}],
            response_model=response_model,
            max_retries=3
        )
    except Exception as e:
        print(f"❌ LLM Error: {e}")
        raise e
