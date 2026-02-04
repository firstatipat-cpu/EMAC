# EMACS Project Knowledge Transfer

## 1. System Overview

EMACS (Evolutionary Multi-Agent Coding System) is an autonomous AI Software Engineer designed to operate locally. It leverages a multi-agent architecture and Language Models (LLMs) to perform complex software development tasks, from planning and coding to testing and self-correction.

## 2. Core Architecture

The system is built around a central Orchestrator that coordinates various specialized AI Agents. It operates in two main phases, often in a hybrid, iterative loop:

*   **Phase 1: Research Loop (ReAct Pattern)**: The Planner agent identifies tasks, utilizes tools (like web search or file operations) to gather information, and formulates a detailed plan.
*   **Phase 2: Coding Loop (MCP-like)**: The Coder agent writes code based on the plan, which is then executed in an isolated sandbox. The Critic agent reviews the execution, identifies errors, and provides feedback for self-correction. The Analyst agent steps in for root cause analysis if repeated failures occur.

## 3. Key Components and Their Roles

### 3.1 Agents (`src/agents/`)

*   **Planner (`planner.py`)**: Responsible for creating step-by-step plans, deciding when to use tools or proceed to code generation. Guided by `prompts.yaml`.
*   **Coder (`coder.py`)**: Generates Python code based on instructions and context. Ensures filename safety and includes standard code boilerplate. Guided by `prompts.yaml`.
*   **Critic (`critic.py`)**: Evaluates code execution logs, detects "Silent Errors" (no output), and suggests fixes or missing dependencies. Guided by `prompts.yaml`.
*   **Analyst (`analyst.py`)**: Performs root cause analysis of failures, providing insights for learning and improvement. Guided by `prompts.yaml`.

### 3.2 Core System Components (`src/core/`)

*   **Orchestrator (`orchestrator.py`)**: The central control unit. It manages the entire mission lifecycle, coordinating agents, executing tools, handling memory interactions, and implementing the iterative coding and testing loop. It also includes auto-installation of dependencies.
*   **LLM Interaction (`llm.py`)**: Provides the primary interface for communicating with Language Models. It uses `instructor` to patch the `OpenAI` client, enabling structured output (Pydantic models) from local Ollama servers.
*   **Models (`models.py`)**: Defines Pydantic data models (e.g., `Plan`, `CodeOutput`, `Critique`) used for structured communication and data validation across the system.
*   **Configuration (`config.py`)**: Handles loading system settings from `genome_config.json` and agent-specific prompts from `src/config/prompts.yaml`.
*   **Docker Sandbox (`sandbox.py`)**: Manages an isolated and persistent Docker container (`python:3.10-slim`) for safe and reproducible execution of generated code and shell commands. It mounts the `workspace` directory.

### 3.3 Memory System (`src/memory/`)

*   **Librarian (`librarian.py`)**: Implements the "Dual Memory" system:
    *   **Machine Memory (ChromaDB)**: Uses a persistent ChromaDB instance (`chroma_db/`) to store and retrieve past "skills" and relevant knowledge (vector embeddings).
    *   **Human Memory (Obsidian Vault)**: Saves objectives, generated code, and lessons learned as Markdown files in a designated directory (`memory_logs/`) for human readability and knowledge base management.

### 3.4 Tools (`src/tools/`)

*   **Custom Tools (`custom_tools.py`)**: Provides fundamental functionalities callable by agents:
    *   `web_search`: Queries a local SearXNG instance for internet search results.
    *   `read_file`: Reads content from files within the `workspace`.
    *   `run_shell`: Executes shell commands within the Docker sandbox (with basic safety checks).
    *   `list_files`: Lists files in the current directory.
*   **Tool Registry (`registry.py`)**: A dynamic system that allows for registering Python functions as callable tools. It automatically generates JSON schemas for these tools, which the Planner agent uses to understand their capabilities and arguments.
*   **MCP Adapter (`mcp_adapter.py`)**: Facilitates integration with external tools or services that adhere to the Model Context Protocol (MCP), enabling dynamic extension of EMACS's toolset.

## 4. Configuration and Entry Points

*   **`genome_config.json`**: Main configuration file for system-wide settings, including model names (for agents), paths (e.g., Obsidian vault), and operational parameters (e.g., `max_attempts_per_step`).
*   **`src/config/prompts.yaml`**: Contains specific system prompts for each agent (`planner`, `coder`, `critic`, `analyst`), crucial for guiding their behavior and role adherence.
*   **`app.py`**: A Streamlit-based Graphical User Interface (GUI) for interacting with EMACS, allowing users to define objectives, launch missions, and monitor progress, logs, and generated files.
*   **`main.py`**: A Command-Line Interface (CLI) entry point for starting EMACS missions with a specified objective.

## 5. External Dependencies and Ecosystem

*   **LLM Runtime**: Ollama (for running local LLMs like Gemma2, Llama3).
*   **Search Engine**: SearXNG (self-hosted, private search engine via Docker).
*   **Observability/Tracing**: Langfuse (via Docker, with PostgreSQL backend).
*   **Database**: PostgreSQL (used by Langfuse, via Docker).
*   **Python Packages**: Managed via `requirements.txt` (includes `ollama`, `instructor`, `pydantic`, `chromadb`, `docker`, `streamlit`, `pyyaml`, etc.).
*   **Workspace (`workspace/`)**: Dedicated directory for AI-generated code, scripts, and output files.
*   **ChromaDB Data (`chroma_db/`)**: Persistent storage for the ChromaDB vector database.
*   **Memory Logs (`memory_logs/`, `obsidian_backup/`)**: Directories storing Markdown files for the human-readable memory (Obsidian vault).

This document summarizes the core components and functionalities of the EMACS project, serving as a comprehensive guide for knowledge transfer.
