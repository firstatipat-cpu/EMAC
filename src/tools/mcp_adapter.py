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
