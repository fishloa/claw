# Claw Code — Local Model Configuration

## CRITICAL: Available tools

You MUST only use these exact tool names. Do NOT invent tools — any unknown name will fail.

### File operations
- **read_file** — read file contents
- **write_file** — create or overwrite a file
- **edit_file** — make targeted edits to existing files (preferred for changes)
- **NotebookEdit** — edit Jupyter notebooks

### Search
- **glob_search** — find files by glob pattern (e.g. "**/*.rs")
- **grep_search** — search file contents by regex

### Execution
- **bash** — run shell commands (ls, git, cargo, make, etc.)

### Web
- **WebFetch** — fetch a URL
- **WebSearch** — search the web

### Agents & tasks
- **Agent** — spawn a subagent (supports model override)
- **TaskCreate** / **TaskGet** / **TaskList** / **TaskStop** / **TaskUpdate** / **TaskOutput** — manage background tasks

### Planning
- **EnterPlanMode** / **ExitPlanMode** — toggle plan mode
- **TodoWrite** — write todo items
- **AskUserQuestion** — ask the user a question

### Other
- **Skill** — invoke a skill
- **ToolSearch** — search for available tools
- **LSP** — language server protocol operations
- **MCP** — MCP server tool calls
- **Config** — read/write claw config

**To list a directory:** use bash with "ls" — there is NO listdir tool.

## Model routing

You (gemma-4-31b-it-8bit) handle reasoning, planning, reviewing, and architecture.

For coding subagents, use local models via the Agent tool:

- **Implementation/coding:** model: "Qwen3-Coder-Next-4bit"
- **Fast/simple tasks:** model: "gemma-4-26b-a4b-it-4bit"
- **General coding:** model: "Qwen3.5-27B-4bit"

## Available models

- **gemma-4-31b-it-8bit** — reasoning, review, planning (default)
- **Qwen3-Coder-Next-4bit** — agentic coding (80B MoE, 3B active)
- **Qwen3.5-27B-4bit** — general coding (27.8B dense)
- **gemma-4-26b-a4b-it-4bit** — fast tasks (26B MoE, 4B active)

## IMPORTANT: Bash timeouts

When using the bash tool, do NOT set short timeouts. Build commands (cargo, make, npm) can take minutes.

- **No timeout needed** for most commands — omit the timeout field entirely
- If you must set one: use at least **120000** (2 minutes) for build commands
- **NEVER** use timeout: 300 — that's 300ms, not 300 seconds

## NEVER USE THESE — they do NOT exist
- ~~listdir~~ → use `bash` with `ls`
- ~~list_file~~ → use `bash` with `ls` or `glob_search`
- ~~list_directory~~ → use `bash` with `ls`
- ~~search_files~~ → use `glob_search` or `grep_search`
- ~~run_command~~ → use `bash`
- ~~execute~~ → use `bash`
- ~~cat_file~~ → use `read_file`
