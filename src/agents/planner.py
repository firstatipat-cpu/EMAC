from src.core.llm import ask_ai
from src.core.models import Plan
from src.core.config import load_prompts, load_config
from src.tools.registry import ToolRegistry

def create_plan_with_tools(objective: str, context: str, tool_registry: ToolRegistry) -> Plan:
    prompts = load_prompts()
    config = load_config()
    available_tools = tool_registry.get_tool_definitions()
    
    system_prompt = f"""
    You are a Smart Planner.
    AVAILABLE TOOLS:
    {available_tools}
    
    To use a tool, create a step with tool_needed="tool_name" and description="argument".
    If ready to code, set tool_needed=null.
    """
    
    return ask_ai(
        prompt=f"Objective: {objective}\nContext: {context}",
        model=config['models']['planner'],
        response_model=Plan,
        system_prompt=system_prompt
    )
