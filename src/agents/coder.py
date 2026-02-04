from src.core.llm import ask_ai
from src.core.models import CodeOutput
from src.core.config import load_prompts, load_config
import os
import re
import uuid

def clean_markdown(text: str) -> str:
    clean = re.sub(r'^```[a-z]*\n?', '', text, flags=re.MULTILINE)
    clean = re.sub(r'\n```$', '', clean)
    return clean.strip()

def write_code(instruction: str, context: str) -> CodeOutput:
    prompts = load_prompts()
    config = load_config()
    result = ask_ai(
        prompt=f"Instruction: {instruction}\nContext: {context}",
        model=config['models']['coder'],
        response_model=CodeOutput,
        system_prompt=prompts.get('coder', "You are a coder.")
    )
    result.code = clean_markdown(result.code)
    
    # Filename Safety
    if not result.filename or result.filename.strip() == "" or "/" in result.filename: 
        result.filename = f"gen_{uuid.uuid4().hex[:4]}.py"
    
    os.makedirs("workspace", exist_ok=True)
    target = os.path.join("workspace", result.filename)
    if os.path.isdir(target): result.filename = f"script_{uuid.uuid4().hex[:4]}.py"
    
    with open(os.path.join("workspace", result.filename), "w", encoding="utf-8") as f:
        f.write(result.code)
    return result
