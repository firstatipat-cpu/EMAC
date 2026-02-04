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
    registry.register(web_search, "Search internet. Input: query")
    registry.register(run_shell, "Run shell command. Input: command")
    registry.register(list_files, "List files. Input: (ignored)")
    
    try:
        mcp = MCPConnector(registry)
        ws_path = os.path.abspath("workspace")
        # mcp.connect("npx", ["-y", "@modelcontextprotocol/server-filesystem", ws_path])
    except: pass
    
    print(f"🚀 Mission: {objective}")
    
    knowledge = lib.recall(objective)
    current_context = knowledge
    plan = None
    
    # --- Phase 1: Initial Planning ---
    # We do one pass of planning. If the first step is a tool, we might loop here,
    # but now we can also handle tools inside the main loop.
    print(f"🧠 Planning...")
    plan = planner.create_plan_with_tools(objective, current_context, registry)
            
    print(f"📋 Steps: {len(plan.steps)}")
    accumulated_deps = []
    
    # --- Phase 2: Hybrid Execution Loop (Tools + Coding) ---
    for step in plan.steps:
        print(f"▶️ Step {step.id}: {step.description}")
        
        # [FIX] Check if this step requires a Tool instead of Coding
        if step.tool_needed and step.tool_needed.lower() != "none":
            t_name = step.tool_needed
            t_args = step.description
            
            print(f"🔎 Using Tool [{t_name}]: {t_args}")
            
            # Execute Tool
            res = registry.execute(t_name, argument=t_args)
            
            # Show summary
            summary = res[:200] + "..." if len(res) > 200 else res
            print(f"   Result: {summary}")
            
            # Update Context for next steps
            current_context += f"\n[Result from Step {step.id} ({t_name})]:\n{res}\n"
            
            # Skip coding for this step
            continue

        # If no tool needed, proceed to Coding
        attempts = 0
        success = False
        step_context = current_context # Pass accumulated context
        
        while attempts < 3 and not success:
            code_obj = coder.write_code(step.description, step_context)
            
            # Install Deps
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
                # Add success signal to context
                current_context += f"\n[Step {step.id} Completed]: Created {code_obj.filename}\n"
            else:
                # Auto-Fix Dependencies
                match = re.search(r"No module named '(\w+)'", exec_log)
                if match:
                    lib_name = match.group(1)
                    PKG_MAP = {
                        "PIL": "Pillow", "cv2": "opencv-python-headless",
                        "sklearn": "scikit-learn", "bs4": "beautifulsoup4",
                        "qrcode": "qrcode[pil]" 
                    }
                    if lib_name in PKG_MAP: 
                        lib_name = PKG_MAP[lib_name]
                        
                    print(f"   📦 Auto-Install Missing: {lib_name}")
                    sandbox.run_code("dummy.py", dependencies=[lib_name])
                    accumulated_deps.append(lib_name)
                
                attempts += 1
                print(f"   ❌ Failed ({attempts}/3)")
                step_context += f"\nAttempt {attempts} Log:\n{exec_log}\nFix Suggestion: {review.suggested_fix}\n"
        
        if not success:
            return f"Failed: {step.description}"
            
    return "Mission Complete"
