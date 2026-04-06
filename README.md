# Claw

Local agentic coding infrastructure — oMLX inference on an M2 Ultra,
claw CLI clients on any Mac or Linux box.

## Architecture

```
┌───────────────────────────────────────────────────────┐
│  M2 Ultra Mac Studio (128 GB)  — INFERENCE SERVER     │
│                                                       │
│  oMLX  ← models pinned in unified memory              │
│  ├─ Qwen3-Coder-Next  80B-A3B  Q4   (~46 GB) coder   │
│  ├─ Gemma 4 31B Dense           Q8   (~35 GB) reason  │
│  └─ Gemma 4 26B-A4B MoE        Q4   (~15 GB) fast    │
│                                                       │
│  :10741  OpenAI + Anthropic compat API                │
│  SSD KV cache for instant prefix restore              │
└───────────────┬───────────────────┬───────────────────┘
                │                   │
┌───────────────┴────┐  ┌──────────┴────────────────────┐
│  Any Mac (client)  │  │  Zelkova DL380 Gen10 (Linux)  │
│  claw CLI → oMLX   │  │  claw CLI → oMLX              │
└────────────────────┘  └───────────────────────────────┘
```

## Setup

Clone this repo on every machine:

```bash
git clone https://github.com/fishloa/claw.git
cd claw
```

### Server (M2 Ultra — run once)

```bash
./setup server
```

Installs oMLX, downloads models, starts a launchd service, generates
`config/connection.env` with the server IP/port/key.

Then copy `config/connection.env` to client clones:

```bash
scp config/connection.env user@zelkova:~/claw/config/
scp config/connection.env user@macbook:~/claw/config/
```

### Client (any Mac or Linux — run once per machine)

```bash
./setup client
# or with explicit host:
./setup client 192.168.1.50
```

Installs Rust, builds claw-code-local, symlinks binary and env back into
this repo tree.

### Check status

```bash
./setup status
```

### Update (after git pull)

```bash
git pull
./setup server    # on the server — reloads launchd plist
./setup client    # on clients — rebuilds binary, refreshes env
```

Or use the alias from any client shell:

```bash
claw-update       # = cd $CLAW_REPO_DIR && git pull && ./setup client
```

## Usage

```bash
claw                                  # interactive REPL (default model)
claw --model Qwen3-Coder-Next-4bit   # specific model
claw-coder "explain this codebase"    # alias → Qwen3-Coder-Next
claw-reason "review the auth module"  # alias → Gemma 4 31B
claw-fast "write a commit message"    # alias → Gemma 4 26B MoE
/model gemma-4-31b-it-8bit           # switch mid-session

claw-status                           # list loaded models
claw-ping                             # quick health check
```

## How linking works

Nothing is copied out of this repo. Everything is symlinked or sourced:

| Installed artefact | Points to |
|---|---|
| `~/.claw-env` | → `<repo>/client/claw-env.generated` |
| `~/.local/bin/claw` | → `<repo>/.build/claw-code-local/rust/target/release/claw` |
| `~/Library/LaunchAgents/com.claw.omlx-server.plist` | → `<repo>/server/com.claw.omlx-server.plist` |

`git pull` updates the repo tree. `./setup <role>` regenerates configs
and rebuilds binaries in place — the symlinks don't change.

## Repo layout

```
.
├── setup                          # Single entry point
├── config/
│   ├── omlx-server.env            # Server defaults (committed)
│   ├── models.json                # Model manifest (committed)
│   ├── connection.env.example     # Template for client connection
│   └── connection.env             # ← generated, gitignored (has API key)
├── server/
│   ├── install.sh                 # Server setup logic
│   └── com.claw.omlx-server.plist # ← generated, gitignored
├── client/
│   ├── install.sh                 # Client setup logic (mac + linux)
│   └── claw-env.generated         # ← generated, gitignored
├── .build/                        # ← claw-code-local clone (gitignored)
└── .gitignore
```

## Security

The API key in `config/connection.env` is a local-only bearer token. It
never leaves your network. For internet-facing access, use Tailscale or
put oauth2-proxy in front.

## Models

| Model | Role | Quant | ~RAM | Active params |
|---|---|---|---|---|
| Qwen3-Coder-Next | Agentic coding | Q4 | ~46 GB | 3B (80B MoE) |
| Gemma 4 31B Dense | Complex reasoning | Q8 | ~35 GB | 31B |
| Gemma 4 26B-A4B | Fast auxiliary | Q4 | ~15 GB | 4B (26B MoE) |

Edit `config/models.json` to change. Pin strategy: Coder-Next + 26B-A4B
always loaded (~61 GB); 31B swaps in on demand.
