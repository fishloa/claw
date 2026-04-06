# Claw

Local agentic coding — oMLX inference on an M2 Ultra, claw CLI on any
Mac or Linux box.

## Quick start

```bash
git clone https://github.com/fishloa/claw.git
cd claw
./setup server          # on the M2 Ultra
./setup client          # on any client machine
```

## Architecture

```
┌──────────────────────────────────────────────────────┐
│  M2 Ultra 128 GB  —  oMLX inference server           │
│                                                      │
│  Qwen3-Coder-Next  80B-A3B Q4  (~46 GB)  coder      │
│  Gemma 4 31B Dense        Q8   (~35 GB)  reasoning   │
│  Gemma 4 26B-A4B MoE     Q4   (~15 GB)  fast        │
│                                                      │
│  :10741  OpenAI + Anthropic compat API               │
│  SSD KV cache → instant prefix restore               │
└───────────────┬───────────────────┬──────────────────┘
                │                   │
┌───────────────┴────┐  ┌──────────┴───────────────────┐
│  Any Mac           │  │  Zelkova (Linux x86_64)      │
│  claw → oMLX       │  │  claw → oMLX                 │
└────────────────────┘  └──────────────────────────────┘
```

## Setup

### Server (M2 Ultra — once)

```bash
./setup server                  # install oMLX, download models, start service
./setup server --skip-models    # skip downloads if you already have them
```

Then distribute the connection file to clients:

```bash
scp ~/.claw/config/connection.env user@zelkova:~/.claw/config/
scp ~/.claw/config/connection.env user@macbook:~/.claw/config/
```

### Client (Mac or Linux — once per machine)

```bash
# After placing connection.env:
./setup client

# Or pass the server host directly:
./setup client 192.168.1.50
```

### Update (after git pull)

```bash
git pull
./setup server    # server: picks up config changes, reloads service
./setup client    # client: rebuilds binary, refreshes env
```

## Usage

```bash
claw                                  # interactive REPL
claw --model Qwen3-Coder-Next-4bit   # specific model
claw-coder "explain this codebase"    # → Qwen3-Coder-Next
claw-reason "review the auth module"  # → Gemma 4 31B
claw-fast "write a commit message"    # → Gemma 4 26B MoE
/model gemma-4-31b-it-8bit           # switch mid-session

claw-status                           # list loaded models
claw-ping                             # health check
```

## File layout

```
~/.claw/                              # all config & runtime (per-machine)
├── config/
│   ├── omlx-server.env               # server settings (edit here)
│   ├── models.json                   # model manifest (edit here)
│   └── connection.env                # server→client credentials
├── settings.json                     # oMLX settings (generated)
├── api_key                           # bearer token (generated)
├── claw-env                          # shell env (generated, symlinked)
├── com.claw.omlx-server.plist        # launchd plist (generated, symlinked)
├── cache/                            # SSD KV cache
└── logs/                             # oMLX logs
```

```
<repo>/                               # clone anywhere, git pull to update
├── setup                             # single entry point
├── config/                           # factory defaults (copied on first run)
│   ├── omlx-server.env
│   ├── models.json
│   └── connection.env.example
├── server/install.sh                 # server logic
├── client/install.sh                 # client logic (mac + linux)
└── .build/                           # claw-code-local checkout (gitignored)
```

The repo is disposable — all state lives in `~/.claw/`. Clone it
anywhere, run `./setup`, done. `git pull && ./setup` to update.

## How linking works

| Artefact | → Target |
|---|---|
| `~/.claw-env` | → `~/.claw/claw-env` |
| `~/.local/bin/claw` | → `<repo>/.build/claw-code-local/rust/target/release/claw` |
| `~/Library/LaunchAgents/com.claw.omlx-server.plist` | → `~/.claw/com.claw.omlx-server.plist` |
