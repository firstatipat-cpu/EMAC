#!/bin/bash

echo "🔧 Patching EMACS Dependencies Logic & Prompts..."

# 1. Update Orchestrator with Package Mapping
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
                print(f"   📦 Installing defined deps: {new_deps}")
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
                # Auto-fix missing modules with MAPPING
                match = re.search(r"No module named '(\w+)'", exec_log)
                if match:
                    lib_name = match.group(1)
                    
                    # --- SMART PACKAGE MAPPING ---
                    PKG_MAP = {
                        "PIL": "Pillow",
                        "sklearn": "scikit-learn",
                        "cv2": "opencv-python-headless",
                        "yaml": "PyYAML",
                        "bs4": "beautifulsoup4",
                        "dotenv": "python-dotenv"
                    }
                    
                    if lib_name in PKG_MAP:
                        print(f"   🔄 Smart Mapping: '{lib_name}' -> '{PKG_MAP[lib_name]}'")
                        lib_name = PKG_MAP[lib_name]
                    
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

# 2. Update Prompts to be more strict about Tools
cat <<'EOF' > src/config/prompts.yaml
planner: |
  You are an Autonomous AI Engineer.
  AVAILABLE TOOLS:
  - web_search: Use for finding libraries, syntax, or facts.
  - run_shell: Use for system commands (ls, pip list).
  - list_files: Check file existence.
  
  CRITICAL INSTRUCTION:
  If the user asks to "search" or "find", YOU MUST USE 'web_search' FIRST.
  Do not write code immediately if you lack information.
  
  Example Step for Search:
  - tool_needed: "web_search"
  - description: "python qr code library"

  Example Step for Coding:
  - tool_needed: null
  - description: "Write script to generate QR code using 'qrcode' library"

coder: |
  You are an Expert Python Developer.
  Return ONLY raw code or JSON.
  The environment is PERSISTENT.
  Filename MUST be a valid file name (e.g., script.py), NOT a directory path.
  ALWAYS include 'if __name__ == "__main__":' and print() the output.

critic: |
  You are a QA Engineer.
  If the code produces no output, fail it (Silent Error).
  If 'ModuleNotFoundError' occurs, suggest the correct pip package name (e.g. Pillow for PIL).

analyst: |
  Analyze failure logs and provide root cause.
EOF

echo "✅ Dependencies Logic Fixed! Try the QR Code mission again."
