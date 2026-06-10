#!/usr/bin/env bash
# deploy-setup.sh — Deploy Serena + Headroom Claude setup (Mac/Linux)
# Idempotent: safe to run multiple times on the same or a new machine.
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

BOLD="\033[1m"
GREEN="\033[1;92m"
YELLOW="\033[1;93m"
CYAN="\033[1;96m"
RED="\033[1;91m"
RESET="\033[0m"

ok()   { echo -e "${GREEN}  ✔ $*${RESET}"; }
info() { echo -e "${CYAN}  → $*${RESET}"; }
warn() { echo -e "${YELLOW}  ⚠ $*${RESET}"; }
fail() { echo -e "${RED}  ✖ $*${RESET}"; exit 1; }
step() { echo -e "\n${BOLD}$*${RESET}"; }

# read_tty <prompt> <varname> — falls back to stdin when /dev/tty is unavailable
read_tty() {
  if (exec </dev/tty) 2>/dev/null; then
    read -rp "$1" "$2" </dev/tty || true
  else
    read -rp "$1" "$2" || true
  fi
}

PURPLE="\033[1;95m"
DIM="\033[2m"

clear
echo -e ""
echo -e "${PURPLE}  ███████╗███╗   ███╗ █████╗ ██████╗ ████████╗ ██████╗ ██╗  ██╗███████╗███╗   ██╗${RESET}"
echo -e "${PURPLE}  ██╔════╝████╗ ████║██╔══██╗██╔══██╗╚══██╔══╝██╔═══██╗██║ ██╔╝██╔════╝████╗  ██║${RESET}"
echo -e "${PURPLE}  ███████╗██╔████╔██║███████║██████╔╝   ██║   ██║   ██║█████╔╝ █████╗  ██╔██╗ ██║${RESET}"
echo -e "${PURPLE}  ╚════██║██║╚██╔╝██║██╔══██║██╔══██╗   ██║   ██║   ██║██╔═██╗ ██╔══╝  ██║╚██╗██║${RESET}"
echo -e "${PURPLE}  ███████║██║ ╚═╝ ██║██║  ██║██║  ██║   ██║   ╚██████╔╝██║  ██╗███████╗██║ ╚████║${RESET}"
echo -e "${PURPLE}  ╚══════╝╚═╝     ╚═╝╚═╝  ╚═╝╚═╝  ╚═╝   ╚═╝    ╚═════╝ ╚═╝  ╚═╝╚══════╝╚═╝  ╚═══╝${RESET}"
echo -e ""
echo -e "  ${BOLD}Claude Code · Token Efficiency Stack${RESET}  ${DIM}60–95% fewer tokens${RESET}"
echo -e ""
echo -e "  ${CYAN}┌─────────────────────────────────────────────────────────────┐${RESET}"
echo -e "  ${CYAN}│${RESET}  Tool         What it cuts              Savings            ${CYAN}│${RESET}"
echo -e "  ${CYAN}├─────────────────────────────────────────────────────────────┤${RESET}"
echo -e "  ${CYAN}│${RESET}  ${GREEN}✦ Serena${RESET}      code file reads → symbols    ${BOLD}60–90%${RESET} input  ${CYAN}│${RESET}"
echo -e "  ${CYAN}│${RESET}  ${GREEN}✦ Headroom${RESET}    conversation context          ${BOLD}60–95%${RESET} input  ${CYAN}│${RESET}"
echo -e "  ${CYAN}│${RESET}  ${GREEN}✦ RTK${RESET}         CLI output noise              ${BOLD}60–90%${RESET} input  ${CYAN}│${RESET}"
echo -e "  ${CYAN}│${RESET}  ${GREEN}✦ Caveman${RESET}     AI response verbosity         ${BOLD}65–75%${RESET} output ${CYAN}│${RESET}"
echo -e "  ${CYAN}└─────────────────────────────────────────────────────────────┘${RESET}"
echo -e ""
echo -e "  These tools are ${BOLD}complementary${RESET} — each targets a different source of waste."
echo -e "  Install all four for maximum savings."
echo -e ""
read_tty "  Install all? [Y/n] → " INSTALL_ALL
INSTALL_ALL=${INSTALL_ALL:-Y}
if [[ "$INSTALL_ALL" =~ ^[Nn]$ ]]; then
  read_tty "  Install Serena?   [Y/n] → " DO_SERENA;   DO_SERENA=${DO_SERENA:-Y}
  read_tty "  Install Headroom? [Y/n] → " DO_HEADROOM; DO_HEADROOM=${DO_HEADROOM:-Y}
  read_tty "  Install RTK?      [Y/n] → " DO_RTK;      DO_RTK=${DO_RTK:-Y}
  read_tty "  Install Caveman?  [Y/n] → " DO_CAVEMAN;  DO_CAVEMAN=${DO_CAVEMAN:-Y}
else
  DO_SERENA=Y; DO_HEADROOM=Y; DO_RTK=Y; DO_CAVEMAN=Y
fi
DO_ANY=N
if [[ "$DO_SERENA" =~ ^[Yy]$ ]] || [[ "$DO_HEADROOM" =~ ^[Yy]$ ]] || [[ "$DO_RTK" =~ ^[Yy]$ ]] || [[ "$DO_CAVEMAN" =~ ^[Yy]$ ]]; then
  DO_ANY=Y
fi
echo -e ""

CLAUDE_DIR="$HOME/.claude"
SKILLS_DIR="$CLAUDE_DIR/skills"
HOOKS_DIR="$CLAUDE_DIR/hooks"
OS="$(uname -s)"   # Darwin = macOS, Linux = Linux

# ── 1. Prerequisites ────────────────────────────────────────────────────────
step "1/9  Checking prerequisites"

command -v claude &>/dev/null || fail "Claude Code not found. Install it first: https://claude.ai/code"
ok "Claude Code installed: $(claude --version 2>/dev/null | head -1 || echo 'found')"

if ! command -v python3 &>/dev/null; then
  if [[ "$OS" == "Darwin" ]]; then
    fail "python3 not found. Install: brew install python3  (or https://python.org — needs 3.10+)"
  else
    fail "python3 not found. Install: sudo apt install python3  (or dnf/pacman — needs 3.10+)"
  fi
fi
ok "python3: $(python3 --version)"

# ── 2. Install uv (for Serena MCP) ─────────────────────────────────────────
if [[ "$DO_SERENA" =~ ^[Yy]$ ]]; then
step "  Serena dependency: uv"

if command -v uvx &>/dev/null; then
  ok "uvx already installed: $(uvx --version 2>/dev/null | head -1)"
else
  info "Installing uv (needed for Serena MCP)..."
  curl -LsSf https://astral.sh/uv/install.sh | sh
  export PATH="$HOME/.local/bin:$PATH"
  ok "uv installed"
fi
fi  # end DO_SERENA

# ── 3. Install headroom ─────────────────────────────────────────────────────
if [[ "$DO_HEADROOM" =~ ^[Yy]$ ]]; then
step "3/9  Headroom"

if command -v headroom &>/dev/null; then
  ok "headroom already installed: $(headroom --version 2>/dev/null | head -1 || echo 'found')"
else
  echo -en "${CYAN}  Install headroom-ai now? (60-95% token savings via wrap mode) [y/n] → ${RESET}"
  read -r ans
  if [[ "$ans" == "y" ]]; then
    python3 -m pip install "headroom-ai[all]" --quiet
    ok "headroom installed"
  else
    warn "Skipped — install later: python3 -m pip install 'headroom-ai[all]'"
  fi
fi
fi  # end DO_HEADROOM

# ── 4. Create directory structure ───────────────────────────────────────────
if [[ "$DO_SERENA" =~ ^[Yy]$ ]]; then
step "4/9  Creating directories"

mkdir -p "$SKILLS_DIR/serena-session-start" "$HOOKS_DIR"
ok "Directories ready"
fi  # end DO_SERENA

# ── 5. Write files ──────────────────────────────────────────────────────────
if [[ "$DO_SERENA" =~ ^[Yy]$ ]]; then
step "5/9  Writing skill + hook files"

# — Hook Python script —
cat > "$HOOKS_DIR/serena-session-start-hook.py" << 'PYEOF'
import json

print(json.dumps({
    "systemMessage": "\U0001f535 SERENA — session start required. Claude will ask you about activation now.",
    "hookSpecificOutput": {
        "hookEventName": "SessionStart",
        "additionalContext": (
            "SESSION START REQUIREMENT: Your very first action in this conversation must be to invoke "
            "the Skill tool with skill=serena-session-start. Do this BEFORE responding to any user message, "
            "BEFORE clarifying questions, and BEFORE any other action. "
            "The skill will ask the user about Serena activation and handle everything from there."
        )
    }
}))
PYEOF
ok "Hook script: $HOOKS_DIR/serena-session-start-hook.py"

# — Skill SKILL.md —
cat > "$SKILLS_DIR/serena-session-start/SKILL.md" << 'SKILLEOF'
---
name: serena-session-start
description: Serena MCP session initialization — ask user, activate project, load or build memories. Enables token-efficient semantic code navigation. Invoke at the start of every session.
---

# Serena Session Start

## Purpose

Activate Serena MCP to unlock token-efficient semantic code navigation (find symbols, declarations,
references, replace function bodies) instead of expensive raw file reads.

---

## Step 1 — Ask the User

Say exactly this, as your first message — nothing before it, nothing after it on the same turn:

> 🔵 **SERENA MCP** — Activate for token-efficient code navigation? **[y/n]**

Wait for the response. If **n** → skip this skill entirely and proceed normally.

If **y** → continue below.

---

## Step 2 — Load Serena Instructions

Call `mcp__oraios_serena__initial_instructions` (no arguments required).

This loads the Serena manual into context. **Required before any other Serena tool call.** Do not skip.

---

## Step 3 — Detect the Project

```bash
pwd
```

This gives the project root. Also check for a Serena config:

```bash
ls "$(pwd)/project.yml" 2>/dev/null && echo "HAS_CONFIG" || echo "NO_CONFIG"
```

---

## Step 4 — Activate

### Case A: project.yml found → Full activation

1. Call `mcp__oraios_serena__activate_project` with `project_root = <CWD>`
2. Call `mcp__oraios_serena__list_memories` — list all stored memories
3. Read the top 3–5 most relevant memories via `mcp__oraios_serena__read_memory`
4. Tell the user in one sentence what was loaded.

### Case B: project.yml NOT found → Onboarding

Tell the user:
> No Serena config found. Shall I run onboarding? It analyzes the codebase and writes persistent memories. (~2 min)

- If **yes**: call `mcp__oraios_serena__onboarding` with `project_root = <CWD>`. Then re-run Step 4A.
- If **no**: call `mcp__oraios_serena__activate_project` for basic symbol navigation.

---

## Step 5 — Handle Technical Issues

If any Serena call errors:

1. Show the error clearly.
2. Check uvx: `uvx --from git+https://github.com/oraios/serena serena --version 2>&1 | head -3`
3. Fix:

| Symptom | Fix |
|---------|-----|
| `uvx: command not found` | `curl -LsSf https://astral.sh/uv/install.sh \| sh` |
| `Connection refused` | Check `~/.claude/config.json` has correct uvx args |
| Any other error | Invoke the `serena-onboarding` skill for guided setup |

---

## Step 6 — Serena Best Practices (Apply Throughout the Session)

| Instead of | Use |
|------------|-----|
| `Read` large code files | `get_symbols_overview` → `find_symbol` → `find_declaration` |
| `grep` for usages | `find_referencing_symbols` |
| Reading before editing a function | `replace_symbol_body` directly |
| Checking compile errors | `get_diagnostics_for_file` |
| Re-discovering project context | `list_memories` → `read_memory` |

**Rule:** Before any `Read` on a code file, ask: "Can Serena give me what I need?" Fall back to `Read`
only for non-code files or when Serena cannot locate the symbol.
SKILLEOF
ok "Skill: $SKILLS_DIR/serena-session-start/SKILL.md"
fi  # end DO_SERENA

# ── 6. Merge config files (Python) ─────────────────────────────────────────
if [[ "$DO_SERENA" =~ ^[Yy]$ ]]; then
step "6/9  Merging Claude config files"

python3 << 'EOF'
import json, os, sys

home = os.path.expanduser("~")
claude_dir = os.path.join(home, ".claude")

# ── settings.json: add SessionStart hook ──────────────────────────────────
settings_path = os.path.join(claude_dir, "settings.json")
settings = {}
if os.path.exists(settings_path):
    with open(settings_path) as f:
        settings = json.load(f)

hook_cmd = "python3 ~/.claude/hooks/serena-session-start-hook.py"
hooks = settings.setdefault("hooks", {})
session_hooks = hooks.setdefault("SessionStart", [])

already = any(
    any(h.get("command", "").endswith("serena-session-start-hook.py")
        for h in group.get("hooks", []))
    for group in session_hooks
)
if not already:
    session_hooks.append({"hooks": [{"type": "command", "command": hook_cmd, "timeout": 5}]})
    print("  ✔ SessionStart hook added to settings.json")
else:
    print("  ✔ SessionStart hook already present in settings.json")

with open(settings_path, "w") as f:
    json.dump(settings, f, indent=2)

# ── config.json: add Serena MCP server ────────────────────────────────────
config_path = os.path.join(claude_dir, "config.json")
config = {}
if os.path.exists(config_path):
    with open(config_path) as f:
        config = json.load(f)

mcp = config.setdefault("mcpServers", {})
if "oraios/serena" not in mcp:
    mcp["oraios/serena"] = {
        "type": "stdio",
        "command": "uvx",
        "args": [
            "--from", "git+https://github.com/oraios/serena",
            "serena", "start-mcp-server", "serena@latest",
            "--context", "ide-assistant"
        ],
        "gallery": "https://api.mcp.github.com",
        "version": "1.0.0"
    }
    print("  ✔ Serena MCP server added to config.json")
else:
    print("  ✔ Serena MCP already present in config.json")

with open(config_path, "w") as f:
    json.dump(config, f, indent=2)

# ── CLAUDE.md: add Serena session-start section ───────────────────────────
claude_md = os.path.join(claude_dir, "CLAUDE.md")
serena_block = """
# Serena MCP — Session Start
At the very start of every conversation, invoke the `serena-session-start` skill BEFORE any other response.
It asks the user whether to activate Serena, handles config detection, and loads project memories.
Once active: prefer Serena semantic tools (`find_symbol`, `find_declaration`, `replace_symbol_body`, etc.) over raw `Read` calls on code files — this saves significant tokens.
"""

content = open(claude_md).read() if os.path.exists(claude_md) else ""
if "Serena MCP" not in content:
    with open(claude_md, "a") as f:
        f.write(serena_block)
    print("  ✔ Serena section added to CLAUDE.md")
else:
    print("  ✔ Serena section already present in CLAUDE.md")
EOF
fi  # end DO_SERENA

# ── 7. Shell profile: Headroom claude() function ───────────────────────────
if [[ "$DO_HEADROOM" =~ ^[Yy]$ ]]; then
step "7/9  Shell profile: Headroom claude() function"

HEADROOM_MARKER="# Headroom wrap — ask per project before launching Claude"
SHELL_PROFILE=""

# Detect active shell profile
if [[ "${SHELL:-}" == *"zsh"* ]] || [[ -f "$HOME/.zshrc" ]]; then
  SHELL_PROFILE="$HOME/.zshrc"
elif [[ "${SHELL:-}" == *"bash"* ]] || [[ -f "$HOME/.bash_profile" ]]; then
  SHELL_PROFILE="$HOME/.bash_profile"
else
  SHELL_PROFILE="$HOME/.profile"
fi

if grep -qF "$HEADROOM_MARKER" "$SHELL_PROFILE" 2>/dev/null; then
  ok "Headroom claude() already in $SHELL_PROFILE"
else
  cat >> "$SHELL_PROFILE" << 'ZSHEOF'

# Headroom wrap — ask per project before launching Claude
# Remembers choice via .headroom file in project root; "always" creates the file.
claude() {
  local cwd="$(pwd)"
  local marker="$cwd/.headroom"
  local use_headroom="n"
  local BOLD="\e[1m"
  local YELLOW="\e[1;93m"
  local GREEN="\e[1;92m"
  local CYAN="\e[1;96m"
  local RESET="\e[0m"

  if [[ -f "$marker" ]]; then
    echo -e "${GREEN}▶ HEADROOM${RESET} ${BOLD}wrap mode active${RESET} for this project. (rm .headroom to disable)"
    use_headroom="y"
  else
    echo -e ""
    echo -e "${YELLOW}╔══════════════════════════════════════════════════════╗${RESET}"
    echo -e "${YELLOW}║  🚀 HEADROOM  60-95% fewer tokens via wrap mode     ║${RESET}"
    echo -e "${YELLOW}╚══════════════════════════════════════════════════════╝${RESET}"
    echo -en "${CYAN}   Activate for this session? [y/always/n] → ${RESET}"
    read -r use_headroom </dev/tty
    if [[ "$use_headroom" == "always" ]]; then
      touch "$marker"
      echo -e "${GREEN}   ✔ Saved .headroom — auto-enabled for this project from now on.${RESET}"
      use_headroom="y"
    elif [[ "$use_headroom" == "y" ]]; then
      echo -e "${GREEN}   ✔ Headroom wrap mode on for this session.${RESET}"
    else
      echo -e "   Skipping Headroom — launching plain claude."
    fi
    echo -e ""
  fi

  if [[ "$use_headroom" == "y" ]]; then
    python3 -m headroom wrap claude "$@"
  else
    command claude "$@"
  fi
}
ZSHEOF
  ok "Headroom claude() added to $SHELL_PROFILE"
fi
fi  # end DO_HEADROOM

# ── 8. RTK — CLI output compressor ─────────────────────────────────────────
if [[ "$DO_RTK" =~ ^[Yy]$ ]]; then
step "8/9  RTK — CLI output compressor"
if command -v rtk &>/dev/null; then
  ok "RTK already installed ($(rtk --version 2>/dev/null | head -1))"
else
  info "Installing RTK..."
  curl -fsSL https://raw.githubusercontent.com/rtk-ai/rtk/refs/heads/master/install.sh | sh
  export PATH="$HOME/.local/bin:$PATH"
  if command -v rtk &>/dev/null; then
    rtk init --claude-code 2>/dev/null || true
    ok "RTK installed and wired to Claude Code"
  else
    info "RTK installed to ~/.local/bin — add it to PATH then run: rtk init --claude-code"
  fi
fi
fi

# ── 9. Caveman — AI response compressor ─────────────────────────────────────
if [[ "$DO_CAVEMAN" =~ ^[Yy]$ ]]; then
step "9/10  Caveman — AI response compressor"
if [ -f "$HOME/.claude/skills/caveman/SKILL.md" ] || command -v caveman &>/dev/null; then
  ok "Caveman already installed"
else
  if ! command -v node &>/dev/null || [[ $(node --version 2>/dev/null | grep -oE '[0-9]+' | head -1) -lt 18 ]]; then
    if [[ "$OS" == "Darwin" ]]; then
      warn "Caveman requires Node ≥18 — skipping. Install: brew install node  then re-run."
    else
      warn "Caveman requires Node ≥18 — skipping. Install: sudo apt install nodejs  (or https://github.com/nvm-sh/nvm) then re-run."
    fi
  else
    info "Installing Caveman..."
    curl -fsSL https://raw.githubusercontent.com/JuliusBrussee/caveman/main/install.sh | bash
    ok "Caveman installed"
  fi
fi
fi

# ── 10. Management tools (uninstall script + skill) ─────────────────────────
if [[ "$DO_ANY" =~ ^[Yy]$ ]]; then
step "10/10  Management tools"

if [[ -f "$SCRIPT_DIR/uninstall.sh" ]]; then
  cp "$SCRIPT_DIR/uninstall.sh" "$CLAUDE_DIR/uninstall-smartoken.sh"
  chmod +x "$CLAUDE_DIR/uninstall-smartoken.sh"
  ok "Uninstall script: ~/.claude/uninstall-smartoken.sh"
else
  warn "uninstall.sh not found — clone the full repo to enable uninstall support"
fi

mkdir -p "$SKILLS_DIR/smartoken"
cat > "$SKILLS_DIR/smartoken/SKILL.md" << 'SKILLEOF'
---
name: smartoken-uninstall
description: Uninstall smartoken — removes Serena, Headroom, RTK, and Caveman from this machine.
---

# Smartoken Uninstall

Run the uninstall script placed in `~/.claude/` during installation.

**Mac/Linux:**
```bash
~/.claude/uninstall-smartoken.sh
```

**Windows (PowerShell as Administrator):**
```powershell
powershell -ExecutionPolicy Bypass -File "$HOME/.claude/uninstall-smartoken.ps1"
```

The script asks which tools to remove. Reload your shell after.
SKILLEOF
ok "Smartoken skill: ~/.claude/skills/smartoken/"
fi  # end DO_ANY

# ── Done ────────────────────────────────────────────────────────────────────
echo -e ""
echo -e "${GREEN}╔══════════════════════════════════════════════════════════════╗${RESET}"
echo -e "${GREEN}║  ✔  Setup complete! Reload your shell to activate:          ║${RESET}"
echo -e "${GREEN}║     source ~/${SHELL_PROFILE##*/}                                     ║${RESET}"
echo -e "${GREEN}╚══════════════════════════════════════════════════════════════╝${RESET}"
echo -e ""
echo -e "  ${BOLD}What was deployed:${RESET}"
[[ "$DO_SERENA"  =~ ^[Yy]$ ]] && echo -e "  • Serena MCP server  → ~/.claude/config.json"
[[ "$DO_SERENA"  =~ ^[Yy]$ ]] && echo -e "  • SessionStart hook  → ~/.claude/settings.json"
[[ "$DO_SERENA"  =~ ^[Yy]$ ]] && echo -e "  • Serena skill       → ~/.claude/skills/serena-session-start/"
[[ "$DO_SERENA"  =~ ^[Yy]$ ]] && echo -e "  • CLAUDE.md section  → ~/.claude/CLAUDE.md"
[[ "$DO_HEADROOM" =~ ^[Yy]$ ]] && echo -e "  • Headroom claude()  → $SHELL_PROFILE"
[[ "$DO_ANY"     =~ ^[Yy]$ ]] && echo -e "  • Uninstall script   → ~/.claude/uninstall-smartoken.sh"
[[ "$DO_ANY"     =~ ^[Yy]$ ]] && echo -e "  • Smartoken skill    → ~/.claude/skills/smartoken/"
echo -e ""
