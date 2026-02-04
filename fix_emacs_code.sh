#!/bin/bash

echo "🔧 Applying Logic Fixes to EMACS v4.3..."

# 1. แก้ไข Registry ให้รับ Single Argument แบบตรงไปตรงมา
cat <<'EOF' > src/tools/registry.py
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
        
        # Schema generation
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

    def execute(self, tool_name: str, argument: str) -> str:
        """
        Executes a tool with a single argument string.
        Automatically maps 'argument' to the first parameter of the tool function.
        """
        if tool_name not in self._tools: 
            return f"Error: Tool '{tool_name}' not found."
        
        func = self._tools[tool_name]
        try:
            sig = inspect.signature(func)
            
            # Case 0: Function takes no arguments (e.g. list_files without args)
            if len(sig.parameters) == 0:
                return str(func())
            
            # Case 1: Function takes 1 or more arguments
            # We assume the 'argument' string is meant for the FIRST parameter.
            # This solves the mismatch between 'query', 'filename', 'command', etc.
            return str(func(argument))
            
        except Exception as e:
            return f"Error executing tool '{tool_name}': {e}"
EOF

# 2. แก้ไข Orchestrator ให้เรียก Registry แบบง่ายๆ
cat <<'EOF' > src/core/orchestrator.py
from src.agents import planner, coder, critic, analyst
from src.memory.librarian import Librarian
from src.core.config import load_config
from src.tools.registry import ToolRegistry
from src.tools.custom_tools import web_search, run_shell, list_files, get_sandbox
from src.tools.mcp_adapter import MCPConnector
import os
import re

def run_mission(objective: str):
    lib = Librarian()
    sandbox = get_sandbox()
    config = load_config()
    
    registry = ToolRegistry()
    
    # Register Internal Tools
    registry.register(web_search, "Search internet. Input: query string.")
    registry.register(run_shell, "Run shell command. Input: command string.")
    registry.register(list_files, "List workspace files. Input: (ignored).")
    
    # Auto-Connect MCP (Optional)
    try:
        mcp = MCPConnector(registry)
        ws_path = os.path.abspath("workspace")
        # Uncomment below to use MCP if Node.js is ready
        # mcp.connect("npx", ["-y", "@modelcontextprotocol/server-filesystem", ws_path])
    except: pass
    
    print(f"🚀 Mission: {objective}")
    
    knowledge = lib.recall(objective)
    current_context = knowledge
    plan = None
    
    # --- ReAct Loop (Thinking Phase) ---
    for i in range(3):
        print(f"🧠 Planning (Iter {i+1})...")
        plan = planner.create_plan_with_tools(objective, current_context, registry)
        
        first_step = plan.steps[0]
        # Check if tool is needed (and not null/None)
        if first_step.tool_needed and first_step.tool_needed.lower() != "none":
            t_name = first_step.tool_needed
            t_args = first_step.description
            
            print(f"🔎 Tool [{t_name}]: {t_args}")
            
            # CLEAN CALL: Pass only the single argument string
            res = registry.execute(t_name, argument=t_args)
            
            print(f"   Result: {res[:100]}...")
            current_context += f"\n[Tool {t_name} Result]: {res}\n"
        else:
            print("✅ Ready to Code")
            break
            
    # --- Coding Loop (Action Phase) ---
    print(f"📋 Steps: {len(plan.steps)}")
    accumulated_deps = []
    
    for step in plan.steps:
        print(f"▶️ Step {step.id}: {step.description}")
        attempts = 0
        success = False
        context = ""
        
        while attempts < 3 and not success:
            code_obj = coder.write_code(step.description, context)
            
            # Install Deps logic
            new_deps = [d for d in code_obj.dependencies if d not in accumulated_deps]
            if new_deps:
                print(f"   📦 Installing: {new_deps}")
                sandbox.run_code("dummy.py", dependencies=new_deps)
                accumulated_deps.extend(new_deps)
                
            print(f"   📄 File: {code_obj.filename}")
            exec_log = sandbox.run_code(code_obj.filename)
            review = critic.review_code(code_obj.filename, exec_log)
            
            if review.is_passing:
                print("   ✅ Passed")
                success = True
                lib.memorize(step.description, code_obj.code, code_obj.filename)
            else:
                # Auto-fix missing modules
                match = re.search(r"No module named '(\w+)'", exec_log)
                if match:
                    lib_name = match.group(1)
                    print(f"   📦 Auto-Install Missing: {lib_name}")
                    sandbox.run_code("dummy.py", dependencies=[lib_name])
                    accumulated_deps.append(lib_name)
                
                attempts += 1
                print(f"   ❌ Failed ({attempts}/3)")
                context += f"\nLog:\n{exec_log}\nFix: {review.suggested_fix}"
        
        if not success:
            return f"Failed: {step.description}"
            
    return "Mission Complete"
EOF

# 3. แก้ไข Prompts ให้ชัดเจนขึ้น
cat <<'EOF' > src/config/prompts.yaml
planner: |
  You are an Autonomous AI Engineer.
  You have access to tools: 'web_search', 'run_shell', 'list_files'.
  
  RULES FOR TOOLS:
  - If you need info, set tool_needed="tool_name".
  - 'description' MUST be the RAW argument string.
  - Example: tool_needed="web_search", description="python qrcode library"
  - Example: tool_needed="run_shell", description="pip list"
  
  If you are ready to code, set tool_needed=null.
  Break down the objective into actionable coding steps.

coder: |
  You are an Expert Python Developer.
  Return ONLY raw code or JSON.
  Ensure 'dependencies' lists required packages.
  The environment is PERSISTENT.
  Filename MUST be a valid file name (e.g., script.py), NOT a directory path.
  ALWAYS include 'if __name__ == "__main__":' and print() the output.

critic: |
  You are a QA Engineer. Check for silent errors and logic issues.
  If the code produces no output, fail it.

analyst: |
  Analyze failure logs and provide root cause.
EOF

echo "✅ Logic Fixed! Try running 'streamlit run app.py' again."
