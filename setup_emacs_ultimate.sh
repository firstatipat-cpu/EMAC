#!/bin/bash

# ==========================================
# EMACS v5.0 - The "Gemma-Abliterated" Edition
# Optimized for your specific model & Fixed all logic bugs
# ==========================================

set -e

echo "🚀 Starting EMACS v5.0 Setup..."

# --- 1. Config & Dependencies ---
echo "📝 Generating Configs..."

cat <<EOF > requirements.txt
ollama
openai>=1.0.0
instructor
pydantic>=2.0.0
tenacity
chromadb
langfuse
docker
streamlit
streamlit-autorefresh
pyyaml
watchdog
requests
mcp
python-dotenv
EOF

# .env template
if [ ! -f .env ]; then
cat <<EOF > .env
# GITHUB_PERSONAL_ACCESS_TOKEN=
# POSTGRES_URL=
EOF
fi

cat <<EOF > docker-compose.yml
version: '3'
services:
  searxng:
    image: searxng/searxng:latest
    container_name: emacs-searxng
    ports: ["8081:8080"]
    volumes: ["./settings.yml:/etc/searxng/settings.yml:ro"]
    environment: ["SEARXNG_BASE_URL=http://localhost:8081/"]
    restart: unless-stopped
  langfuse-server:
    image: ghcr.io/langfuse/langfuse:2
    container_name: emacs-langfuse
    depends_on: { db: { condition: service_healthy } }
    ports: ["3000:3000"]
    environment:
      - DATABASE_URL=postgresql://postgres:postgres@db:5432/postgres
      - NEXTAUTH_URL=http://localhost:3000
      - NEXTAUTH_SECRET=mysecret
      - SALT=mysalt
    restart: unless-stopped
  db:
    image: postgres:15
    container_name: emacs-postgres
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -U postgres"]
      interval: 5s
      timeout: 5s
      retries: 5
    environment: ["POSTGRES_USER=postgres", "POSTGRES_PASSWORD=postgres", "POSTGRES_DB=postgres"]
    volumes: ["langfuse-data:/var/lib/postgresql/data"]
    restart: unless-stopped
volumes:
  langfuse-data:
EOF

cat <<EOF > settings.yml
use_default_settings: true
server:
  port: 8080
  bind_address: "0.0.0.0"
  secret_key: "emacs-secret-key-change-me" 
  limiter: false
search:
  formats: ["html", "json"]
EOF

# ✅ FIX 1: Set correct model name
cat <<EOF > genome_config.json
{
  "system_name": "EMACS_v5.0",
  "version": "5.0.0",
  "obsidian_vault_path": "./memory_logs", 
  "max_attempts_per_step": 3,
  "models": {
    "planner": "gemma-abliterated",
    "coder": "gemma-abliterated",
    "critic": "gemma-abliterated",
    "analyst": "gemma-abliterated"
  },
  "docker_image": "python:3.10-slim"
}
EOF

# ✅ FIX 2: Strict Prompts for Tools
cat <<EOF > src/config/prompts.yaml
planner: |
  You are an Autonomous AI Engineer.
  AVAILABLE TOOLS:
  - web_search: Use for finding libraries, syntax, or facts.
  - run_shell: Use for system commands (ls, pip list).
  - list_files: Check file existence.
  
  CRITICAL INSTRUCTION:
  If the user asks to "search" or "find", YOU MUST USE 'web_search' FIRST.
  
  Tool Usage Format:
  - tool_needed: "web_search"
  - description: "python qr code library"  <-- JUST THE QUERY STRING

  Example Step for Coding:
  - tool_needed: null
  - description: "Write script to generate QR code using 'qrcode' library"

coder: |
  You are an Expert Python Developer.
  Return ONLY raw code or JSON.
  The environment is PERSISTENT.
  Filename MUST be a valid file name (e.g. script.py), NOT a directory path.
  ALWAYS include 'if __name__ == "__main__":' and print() the output.

critic: |
  You are a QA Engineer.
  If the code produces no output, fail it (Silent Error).
  If 'ModuleNotFoundError' occurs, suggest the correct pip package name (e.g. Pillow for PIL).

analyst: |
  Analyze failure logs and provide root cause.
EOF

# --- 2. Source Code Generation ---
echo "💻 Generating Core Code..."

# src/core/config.py
cat <<'EOF' > src/core/config.py
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
EOF

# src/core/models.py
cat <<'EOF' > src/core/models.py
from pydantic import BaseModel
from typing import List, Optional
class Step(BaseModel):
    id: int
    description: str
    tool_needed: Optional[str] = None
class Plan(BaseModel):
    goal_analysis: str
    steps: List[Step]
class CodeOutput(BaseModel):
    filename: str
    code: str
    dependencies: List[str] = []
class Critique(BaseModel):
    is_passing: bool
    feedback: str
    suggested_fix: Optional[str] = None
class AnalystResult(BaseModel):
    root_cause: str
    lesson_learned: str
EOF

# src/core/llm.py (✅ FIX 3: Increased Timeout)
cat <<'EOF' > src/core/llm.py
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
EOF

# src/tools/registry.py (✅ FIX 4: Smart Arg Mapping)
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
EOF

# src/tools/mcp_adapter.py
cat <<'EOF' > src/tools/mcp_adapter.py
import asyncio
import os
import threading
from typing import Optional, Dict
from contextlib import AsyncExitStack

try:
    from mcp import ClientSession, StdioServerParameters
    from mcp.client.stdio import stdio_client
    from mcp.types import TextContent
    MCP_AVAILABLE = True
except ImportError:
    MCP_AVAILABLE = False
    print("⚠️ MCP Library not found.")

from src.tools.registry import ToolRegistry

class MCPConnector:
    def __init__(self, registry: ToolRegistry):
        self.registry = registry
        self.exit_stack = AsyncExitStack()
        self.session: Optional[ClientSession] = None
        self._loop = asyncio.new_event_loop()
        self._thread = threading.Thread(target=self._start_background_loop, daemon=True)
        self._thread.start()

    def _start_background_loop(self):
        asyncio.set_event_loop(self._loop)
        self._loop.run_forever()

    def connect(self, command: str, args: list, env: Dict[str, str] = None):
        if not MCP_AVAILABLE: return "MCP Library missing"
        future = asyncio.run_coroutine_threadsafe(
            self._connect_async(command, args, env), 
            self._loop
        )
        return future.result()

    async def _connect_async(self, command: str, args: list, env: Dict[str, str]):
        server_params = StdioServerParameters(command=command, args=args, env={**os.environ, **(env or {})})
        stdio_transport = await self.exit_stack.enter_async_context(stdio_client(server_params))
        self.session = await self.exit_stack.enter_async_context(ClientSession(stdio_transport[0], stdio_transport[1]))
        await self.session.initialize()
        
        result = await self.session.list_tools()
        print(f"🔌 Connected to MCP: {command} (Found {len(result.tools)} tools)")

        for tool in result.tools:
            self._register_mcp_tool(tool)

    def _register_mcp_tool(self, tool_info):
        tool_name = tool_info.name
        tool_desc = tool_info.description or f"External tool: {tool_name}"
        
        def mcp_tool_wrapper(**kwargs):
            future = asyncio.run_coroutine_threadsafe(
                self.session.call_tool(tool_name, arguments=kwargs),
                self._loop
            )
            result = future.result()
            output_text = []
            for content in result.content:
                if isinstance(content, TextContent): output_text.append(content.text)
                else: output_text.append(str(content))
            return "\n".join(output_text)

        mcp_tool_wrapper.__name__ = tool_name
        mcp_tool_wrapper.__doc__ = tool_desc
        self.registry.register(mcp_tool_wrapper, description=tool_desc)
EOF

# src/core/sandbox.py
cat <<'EOF' > src/core/sandbox.py
import docker
import os
import time

class DockerSandbox:
    def __init__(self):
        try:
            self.client = docker.from_env()
            self.image = "python:3.10-slim"
            self.container = None
            self.working_dir = "/app"
            self._start_persistent_container()
        except: self.client = None

    def _start_persistent_container(self):
        abs_path = os.path.abspath("workspace")
        try:
            try:
                old = self.client.containers.get("emacs-sandbox")
                old.remove(force=True)
            except: pass

            self.container = self.client.containers.run(
                self.image,
                name="emacs-sandbox",
                command="tail -f /dev/null",
                volumes={abs_path: {'bind': self.working_dir, 'mode': 'rw'}},
                working_dir=self.working_dir,
                detach=True,
                mem_limit="512m",
                network_disabled=False
            )
            print("📦 Sandbox Started")
        except: pass

    def run_code(self, filename: str, dependencies: list = []) -> str:
        if not self.container: return "Sandbox Not Running"
        
        if dependencies:
            self.container.exec_run(f"pip install {' '.join(dependencies)}")
        
        cmd = f"python -u {filename}"
        exit_code, output = self.container.exec_run(cmd)
        
        logs = output.decode("utf-8")
        if exit_code != 0:
            return f"Error (Exit Code {exit_code}):\n{logs}"
        return logs if logs else "(No Output)"

    def run_shell(self, command: str) -> str:
        if not self.container: return "Sandbox Not Running"
        exit_code, output = self.container.exec_run(command)
        return output.decode("utf-8")
EOF

# src/tools/custom_tools.py
cat <<'EOF' > src/tools/custom_tools.py
import os
import requests
import urllib.parse
from src.core.sandbox import DockerSandbox

_sandbox_instance = None

def get_sandbox():
    global _sandbox_instance
    if _sandbox_instance is None:
        _sandbox_instance = DockerSandbox()
    return _sandbox_instance

def web_search(query: str) -> str:
    try:
        url = f"http://localhost:8081/search?q={urllib.parse.quote(query)}&format=json"
        res = requests.get(url, timeout=5)
        if res.status_code == 200:
            results = res.json().get('results', [])[:3]
            return "\n".join([f"- {r['title']}: {r['url']}" for r in results])
    except: pass
    return "Search failed."

def read_file(filename: str) -> str:
    path = os.path.join("workspace", filename)
    if os.path.exists(path):
        with open(path, 'r') as f: return f.read()
    return "File not found."

def run_shell(command: str) -> str:
    sb = get_sandbox()
    forbidden = ["docker", "sudo", "rm -rf /"] 
    if any(f in command for f in forbidden): return "Command blocked."
    return sb.run_shell(command)
    
def list_files(dummy: str="") -> str:
    return run_shell("ls -la")
EOF

# src/agents/planner.py
cat <<'EOF' > src/agents/planner.py
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
EOF

# src/agents/coder.py (✅ FIX 5: Path & Name Safety)
cat <<'EOF' > src/agents/coder.py
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
EOF

# src/agents/critic.py
cat <<'EOF' > src/agents/critic.py
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
EOF

# src/agents/analyst.py
cat <<'EOF' > src/agents/analyst.py
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
EOF

# src/memory/librarian.py
cat <<'EOF' > src/memory/librarian.py
import chromadb
import os
import datetime
from src.core.config import load_config
class Librarian:
    def __init__(self):
        os.makedirs("chroma_db", exist_ok=True)
        self.client = chromadb.PersistentClient(path="./chroma_db")
        self.collection = self.client.get_or_create_collection("emacs_skills")
        config = load_config()
        self.obsidian_path = config.get("obsidian_vault_path", "./memory_logs")
        os.makedirs(self.obsidian_path, exist_ok=True)
    def recall(self, query: str) -> str:
        try:
            res = self.collection.query(query_texts=[query], n_results=1)
            return res['documents'][0][0] if res['documents'] else ""
        except: return ""
    def memorize(self, objective: str, code: str, filename: str, lesson: str = ""):
        self.collection.add(
            documents=[f"Objective: {objective}\nCode:\n{code}"],
            metadatas=[{"filename": filename}],
            ids=[f"{filename}_{os.urandom(4).hex()}"]
        )
        safe_name = "".join([c for c in objective[:30] if c.isalnum()]).strip() or "skill"
        path = os.path.join(self.obsidian_path, f"{safe_name}.md")
        with open(path, "w", encoding="utf-8") as f:
            f.write(f"# {objective}\n```python\n{code}\n```\n> {lesson}")
EOF

# src/core/orchestrator.py (✅ FIX 6: Package Mapping Logic)
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
    
    # --- ReAct Loop ---
    for i in range(3):
        print(f"🧠 Planning (Iter {i+1})...")
        plan = planner.create_plan_with_tools(objective, current_context, registry)
        
        first_step = plan.steps[0]
        if first_step.tool_needed and first_step.tool_needed.lower() != "none":
            t_name = first_step.tool_needed
            t_args = first_step.description
            print(f"🔎 Tool [{t_name}]: {t_args}")
            
            # Simple Arg Passing
            res = registry.execute(t_name, argument=t_args)
            print(f"   Result: {res[:100]}...")
            current_context += f"\n[Tool {t_name} Result]: {res}\n"
        else:
            print("✅ Ready to Code")
            break
            
    print(f"📋 Steps: {len(plan.steps)}")
    accumulated_deps = []
    
    for step in plan.steps:
        print(f"▶️ Step {step.id}: {step.description}")
        attempts = 0
        success = False
        context = ""
        
        while attempts < 3 and not success:
            code_obj = coder.write_code(step.description, context)
            
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
            else:
                # Auto-Fix with Mapping
                match = re.search(r"No module named '(\w+)'", exec_log)
                if match:
                    lib_name = match.group(1)
                    PKG_MAP = {
                        "PIL": "Pillow", "cv2": "opencv-python-headless",
                        "sklearn": "scikit-learn", "bs4": "beautifulsoup4"
                    }
                    if lib_name in PKG_MAP: 
                        print(f"   🔄 Map: {lib_name}->{PKG_MAP[lib_name]}")
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

# main.py
cat <<'EOF' > main.py
import sys
import os
from src.core.orchestrator import run_mission
if __name__ == "__main__":
    if len(sys.argv) < 2: 
        print("Usage: python main.py 'Objective'")
        sys.exit(1)
    os.makedirs("workspace", exist_ok=True)
    print(run_mission(sys.argv[1]))
EOF

# app.py
cat <<'EOF' > app.py
import streamlit as st
import subprocess
import os
import sys
import logging
from streamlit_autorefresh import st_autorefresh

logging.getLogger('streamlit.runtime.scriptrunner_utils.script_run_context').setLevel(logging.ERROR)
logging.getLogger('streamlit.server.server').setLevel(logging.ERROR)

st.set_page_config(page_title="EMACS Pro", layout="wide")
st.title("🤖 EMACS v5.0 (Gemma-Abliterated Edition)")

col1, col2 = st.columns([1, 2])
with col1:
    if "objective" not in st.session_state: st.session_state.objective = ""
    objective = st.text_area("Objective:", key="input_obj")
    
    if st.button("🚀 Launch"):
        with open("mission_log.txt", "w") as f: f.write("Starting...\n")
        logfile = open("mission_log.txt", "w", encoding="utf-8")
        subprocess.Popen([sys.executable, "-u", "main.py", objective], stdout=logfile, stderr=subprocess.STDOUT)
        st.success("Started!")
        
    st.divider()
    if os.path.exists("workspace"):
        files = os.listdir("workspace")
        if files:
            selected_file = st.selectbox("Select File:", files)
            path = os.path.join("workspace", selected_file)
            if os.path.isfile(path):
                with open(path, "r", encoding="utf-8") as f: st.code(f.read(), language="python")

with col2:
    st.subheader("Logs")
    st_autorefresh(interval=1000, key="logrefresh")
    try:
        with open("mission_log.txt", "r") as f: st.code(f.read())
    except: st.info("No logs.")
EOF

# --- Finish ---
echo "🐍 Setup Env..."
if [ ! -d ".venv" ]; then python3 -m venv .venv; fi
source .venv/bin/activate
pip install --upgrade pip
pip install -r requirements.txt

echo "🐳 Starting Services..."
docker-compose up -d

echo "✅ Setup Complete (v5.0 Gemma-Abliterated)!"
echo "-------------------------------------"
echo "Run: source .venv/bin/activate"
echo "Run: streamlit run app.py"
echo "-------------------------------------"
