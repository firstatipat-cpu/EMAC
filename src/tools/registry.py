import inspect
import json
from typing import Callable, Any, Dict

class ToolRegistry:
    def __init__(self):
        self._tools: Dict[str, Callable] = {}
        self._schemas: Dict[str, Any] = {}

    def register(self, func: Callable, description: str = ""):
        name = func.__name__
        self._tools[name] = func
        sig = inspect.signature(func)
        params = {}
        for param_name, param in sig.parameters.items():
            if param_name == 'self': continue
            params[param_name] = {"type": "string", "description": f"Parameter {param_name}"}
        self._schemas[name] = {
            "name": name,
            "description": description or func.__doc__,
            "parameters": {"type": "object", "properties": params, "required": list(params.keys())}
        }

    def get_tool_definitions(self) -> str:
        return json.dumps(list(self._schemas.values()), indent=2)

    def execute(self, tool_name: str, **kwargs) -> str:
        if tool_name not in self._tools: return f"Error: Tool '{tool_name}' not found."
        func = self._tools[tool_name]
        try:
            sig = inspect.signature(func)
            # Smart Mapping: If function takes 1 arg, give it the first available value
            if len(sig.parameters) == 1 and kwargs:
                val = next(iter(kwargs.values()))
                return str(func(val))
            return str(func(**kwargs))
        except Exception as e:
            return f"Error executing tool: {e}"
