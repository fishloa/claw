#!/usr/bin/env bash
# client/install.sh — Install claw CLI and link to oMLX server
# Called by: ./setup client [server-host] [port] [api-key]
# Works on macOS (arm64/x86_64) and Linux (x86_64).
# All config lives in the repo — git pull updates everything in place.

set -euo pipefail

REPO_DIR="${1:?REPO_DIR required}"
shift

# ── Colours ──────────────────────────────────────────────────────────
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
CYAN='\033[0;36m'; NC='\033[0m'
info()  { echo -e "${CYAN}[INFO]${NC}  $*"; }
ok()    { echo -e "${GREEN}[OK]${NC}    $*"; }
warn()  { echo -e "${YELLOW}[WARN]${NC}  $*"; }
err()   { echo -e "${RED}[ERROR]${NC} $*" >&2; }

# ── Resolve server connection ────────────────────────────────────────
SERVER_HOST=""
SERVER_PORT="10741"
API_KEY=""
DEFAULT_MODEL="Qwen3-Coder-Next-4bit"

# Try config/connection.env first (scp'd from server)
CONN_FILE="$REPO_DIR/config/connection.env"
if [[ -f "$CONN_FILE" ]]; then
  info "Loading server details from config/connection.env"
  source "$CONN_FILE"
  SERVER_HOST="${CLAW_SERVER_HOST:-}"
  SERVER_PORT="${CLAW_SERVER_PORT:-10741}"
  API_KEY="${CLAW_API_KEY:-}"
  DEFAULT_MODEL="${CLAW_DEFAULT_MODEL:-Qwen3-Coder-Next-4bit}"
fi

# Override with positional args
SERVER_HOST="${1:-$SERVER_HOST}"
SERVER_PORT="${2:-$SERVER_PORT}"
API_KEY="${3:-$API_KEY}"

if [[ -z "$SERVER_HOST" ]]; then
  err "Server host required."
  err ""
  err "Either:"
  err "  1. Copy config/connection.env from the server into this repo clone"
  err "  2. Pass it as an argument:  ./setup client <server-host> [port] [api-key]"
  exit 1
fi

SERVER_URL="http://${SERVER_HOST}:${SERVER_PORT}"

info "Target server: $SERVER_URL"

# ── Detect platform ──────────────────────────────────────────────────
OS="$(uname -s)"
ARCH="$(uname -m)"
info "Platform: $OS $ARCH"

# ── 1. Build dependencies ───────────────────────────────────────────
echo ""
info "Checking build dependencies..."

if [[ "$OS" == "Linux" ]]; then
  if command -v apt-get &>/dev/null; then
    DEPS="build-essential pkg-config libssl-dev git curl"
    MISSING=""
    for dep in $DEPS; do
      dpkg -s "$dep" &>/dev/null || MISSING="$MISSING $dep"
    done
    if [[ -n "$MISSING" ]]; then
      info "Installing:$MISSING"
      sudo apt-get update -qq
      sudo apt-get install -y -qq $MISSING
    fi
  elif command -v dnf &>/dev/null; then
    sudo dnf install -y gcc pkg-config openssl-devel git curl
  elif command -v pacman &>/dev/null; then
    sudo pacman -S --needed --noconfirm base-devel openssl git curl
  else
    warn "Unknown package manager — ensure gcc, pkg-config, libssl-dev, git, curl are installed."
  fi
elif [[ "$OS" == "Darwin" ]]; then
  # Xcode CLI tools provide everything needed
  if ! xcode-select -p &>/dev/null; then
    info "Installing Xcode Command Line Tools..."
    xcode-select --install 2>/dev/null || true
    warn "If a dialog appeared, complete the install and re-run this script."
  fi
fi

ok "Build dependencies ready"

# ── 2. Rust toolchain ───────────────────────────────────────────────
echo ""
info "Checking Rust..."

if command -v rustc &>/dev/null && command -v cargo &>/dev/null; then
  ok "Rust $(rustc --version | awk '{print $2}')"
else
  info "Installing Rust..."
  curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y --default-toolchain stable
  source "$HOME/.cargo/env"
  ok "Rust installed"
fi

export PATH="$HOME/.cargo/bin:$PATH"

# ── 3. Clone / update claw-code-local ────────────────────────────────
echo ""
CLAW_SRC="$REPO_DIR/.build/claw-code-local"
info "Claw source: $CLAW_SRC"

if [[ -d "$CLAW_SRC/.git" ]]; then
  info "Updating claw-code-local..."
  cd "$CLAW_SRC"
  git pull --ff-only 2>/dev/null || warn "Pull failed — building from existing checkout"
else
  info "Cloning claw-code-local..."
  mkdir -p "$(dirname "$CLAW_SRC")"
  git clone https://github.com/codetwentyfive/claw-code-local.git "$CLAW_SRC"
fi

ok "Source ready"

# ── 4. Build ─────────────────────────────────────────────────────────
echo ""
info "Building claw CLI (release)..."

cd "$CLAW_SRC/rust"
cargo build -p rusty-claude-cli --release 2>&1 | tail -3

# Find the binary
CLAW_BIN=""
for candidate in \
  "$CLAW_SRC/rust/target/release/claw" \
  "$CLAW_SRC/rust/target/release/claw-cli" \
  ; do
  if [[ -f "$candidate" ]] && [[ -x "$candidate" ]]; then
    CLAW_BIN="$candidate"
    break
  fi
done

# Fallback: find any executable starting with claw
if [[ -z "$CLAW_BIN" ]]; then
  if [[ "$OS" == "Darwin" ]]; then
    CLAW_BIN="$(find "$CLAW_SRC/rust/target/release" -maxdepth 1 -perm +111 -type f -name 'claw*' 2>/dev/null | head -1)"
  else
    CLAW_BIN="$(find "$CLAW_SRC/rust/target/release" -maxdepth 1 -executable -type f -name 'claw*' 2>/dev/null | head -1)"
  fi
fi

if [[ -z "$CLAW_BIN" ]]; then
  err "Could not find built claw binary. Try:"
  err "  cd $CLAW_SRC/rust && cargo install --path crates/claw-cli --locked"
  exit 1
fi

ok "Built: $CLAW_BIN"

# ── 5. Symlink binary into PATH ─────────────────────────────────────
echo ""
info "Linking claw binary..."

BIN_DIR="$HOME/.local/bin"
mkdir -p "$BIN_DIR"

LINK_TARGET="$BIN_DIR/claw"
rm -f "$LINK_TARGET"
ln -sf "$CLAW_BIN" "$LINK_TARGET"

ok "~/.local/bin/claw → $CLAW_BIN"
info "(git pull + ./setup client will rebuild and re-link)"

# ── 6. Generate claw-env in repo, symlink to ~ ──────────────────────
echo ""
info "Writing environment config..."

CLAW_ENV_IN_REPO="$REPO_DIR/client/claw-env.generated"

cat > "$CLAW_ENV_IN_REPO" <<ENV_EOF
# Claw Code — oMLX server connection
# Generated by ./setup client on $(date -Iseconds)
# This file lives in the repo and is symlinked to ~/.claw-env
# Edit config/connection.env (or re-run ./setup client) to change.

# ── Repo location (for updates) ─────────────────────────────────────
export CLAW_REPO_DIR="$REPO_DIR"

# ── Server connection ────────────────────────────────────────────────
export OPENAI_API_KEY="${API_KEY:-dummy}"
export OPENAI_BASE_URL="${SERVER_URL}/v1"
export ANTHROPIC_API_KEY="${API_KEY:-dummy}"
export ANTHROPIC_BASE_URL="${SERVER_URL}"

# ── Defaults ─────────────────────────────────────────────────────────
export CLAW_DEFAULT_MODEL="${DEFAULT_MODEL}"

# ── PATH ─────────────────────────────────────────────────────────────
export PATH="\$HOME/.local/bin:\$HOME/.cargo/bin:\$PATH"

# ── Aliases ──────────────────────────────────────────────────────────
alias claw-coder='claw --model Qwen3-Coder-Next-4bit'
alias claw-reason='claw --model gemma-4-31b-it-8bit'
alias claw-fast='claw --model gemma-4-26b-a4b-it-4bit'
alias claw-status='curl -s ${SERVER_URL}/v1/models | python3 -m json.tool'
alias claw-ping='curl -sf ${SERVER_URL}/v1/models >/dev/null && echo "oMLX: OK" || echo "oMLX: UNREACHABLE"'
alias claw-update='cd "\$CLAW_REPO_DIR" && git pull && ./setup client'
ENV_EOF

# Symlink ~/.claw-env → repo
rm -f "$HOME/.claw-env"
ln -sf "$CLAW_ENV_IN_REPO" "$HOME/.claw-env"

ok "~/.claw-env → $CLAW_ENV_IN_REPO"

# ── 7. Hook into shell profile ───────────────────────────────────────
echo ""
info "Hooking into shell profile..."

MARKER="# >>> claw >>>"
SNIPPET='[ -f "$HOME/.claw-env" ] && source "$HOME/.claw-env"'

hook_shell_rc() {
  local rc="$1"
  [[ -f "$rc" ]] || return 0
  if grep -qF "$MARKER" "$rc" 2>/dev/null; then
    ok "Already in $rc"
  else
    printf '\n%s\n%s\n# <<< claw <<<\n' "$MARKER" "$SNIPPET" >> "$rc"
    ok "Added to $rc"
  fi
}

hook_shell_rc "$HOME/.zshrc"
hook_shell_rc "$HOME/.bashrc"
# Create .bash_profile → .bashrc forward if on Linux with no .bash_profile
if [[ "$OS" == "Linux" ]] && [[ ! -f "$HOME/.bash_profile" ]] && [[ -f "$HOME/.bashrc" ]]; then
  hook_shell_rc "$HOME/.bashrc"
fi

# Source now for the test
source "$CLAW_ENV_IN_REPO"

# ── 8. Test connection ───────────────────────────────────────────────
echo ""
info "Testing connection to $SERVER_URL ..."

if curl -sf "${SERVER_URL}/v1/models" >/dev/null 2>&1; then
  ok "Server reachable"
  curl -s "${SERVER_URL}/v1/models" 2>/dev/null \
    | python3 -c "
import json, sys
try:
    data = json.load(sys.stdin)
    for m in data.get('data', []):
        print(f'         • {m[\"id\"]}')
except: pass
" 2>/dev/null || true
else
  warn "Server not reachable at $SERVER_URL"
  warn "Ensure oMLX is running and the port/host are correct."
  if [[ "$OS" == "Linux" ]]; then
    warn "Check firewall: sudo ufw allow ${SERVER_PORT}/tcp  (on server)"
  fi
fi

# ── Summary ──────────────────────────────────────────────────────────
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
ok "Client setup complete"
echo ""
info "  Open a new shell, or:  source ~/.claw-env"
echo ""
echo "  claw                          # interactive REPL"
echo "  claw --model <name> \"prompt\"  # one-shot with specific model"
echo "  claw-coder \"explain this\"     # Qwen3-Coder-Next"
echo "  claw-reason \"review auth\"     # Gemma 4 31B"
echo "  claw-fast \"commit msg\"        # Gemma 4 26B MoE"
echo "  claw-status                   # list loaded models"
echo "  claw-ping                     # quick connectivity check"
echo "  claw-update                   # git pull + rebuild"
echo ""
info "  To update after a git pull:  ./setup client"
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
