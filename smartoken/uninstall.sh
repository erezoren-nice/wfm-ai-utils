#!/usr/bin/env bash
# uninstall-smartoken.sh — Remove smartoken token efficiency stack (Mac/Linux)
# Idempotent: safe to run multiple times.
set -euo pipefail

BOLD="\033[1m"
GREEN="\033[1;92m"
YELLOW="\033[1;93m"
CYAN="\033[1;96m"
PURPLE="\033[1;95m"
DIM="\033[2m"
RESET="\033[0m"

ok()   { echo -e "${GREEN}  ✔ $*${RESET}"; }
info() { echo -e "${CYAN}  → $*${RESET}"; }
warn() { echo -e "${YELLOW}  ⚠ $*${RESET}"; }
step() { echo -e "\n${BOLD}$*${RESET}"; }

read_tty() {
  if (exec </dev/tty) 2>/dev/null; then
    read -rp "$1" "$2" </dev/tty || true
  else
    read -rp "$1" "$2" || true
  fi
}

CLAUDE_DIR="$HOME/.claude"

clear
echo -e ""
echo -e "${PURPLE}  smartoken — Uninstaller${RESET}"
echo -e "  ${DIM}Removes Serena · Headroom · RTK · Caveman${RESET}"
echo -e ""
read_tty "  Uninstall all four tools? [Y/n] → " UNINSTALL_ALL
UNINSTALL_ALL=${UNINSTALL_ALL:-Y}
if [[ "$UNINSTALL_ALL" =~ ^[Nn]$ ]]; then
  read_tty "  Uninstall Serena?   [Y/n] → " DO_SERENA;   DO_SERENA=${DO_SERENA:-Y}
  read_tty "  Uninstall Headroom? [Y/n] → " DO_HEADROOM; DO_HEADROOM=${DO_HEADROOM:-Y}
  read_tty "  Uninstall RTK?      [Y/n] → " DO_RTK;      DO_RTK=${DO_RTK:-Y}
  read_tty "  Uninstall Caveman?  [Y/n] → " DO_CAVEMAN;  DO_CAVEMAN=${DO_CAVEMAN:-Y}
else
  DO_SERENA=Y; DO_HEADROOM=Y; DO_RTK=Y; DO_CAVEMAN=Y
fi
echo -e ""

# ── Serena ───────────────────────────────────────────────────────────────────
if [[ "$DO_SERENA" =~ ^[Yy]$ ]]; then
step "Serena"

[[ -d "$CLAUDE_DIR/skills/serena-session-start" ]] \
  && { rm -rf "$CLAUDE_DIR/skills/serena-session-start"; ok "Removed skills/serena-session-start/"; } \
  || info "skills/serena-session-start/ not found"

[[ -f "$CLAUDE_DIR/hooks/serena-session-start-hook.py" ]] \
  && { rm -f "$CLAUDE_DIR/hooks/serena-session-start-hook.py"; ok "Removed hooks/serena-session-start-hook.py"; } \
  || true

python3 << 'PYEOF'
import json, os

home = os.path.expanduser("~")
cd   = os.path.join(home, ".claude")

# config.json — remove oraios/serena
p = os.path.join(cd, "config.json")
if os.path.exists(p):
    with open(p) as f: cfg = json.load(f)
    if "oraios/serena" in cfg.get("mcpServers", {}):
        del cfg["mcpServers"]["oraios/serena"]
        with open(p, "w") as f: json.dump(cfg, f, indent=2)
        print("  ✔ Serena removed from config.json")
    else:
        print("  → Serena not in config.json")

# settings.json — remove SessionStart hook
p = os.path.join(cd, "settings.json")
if os.path.exists(p):
    with open(p) as f: s = json.load(f)
    hooks = s.get("hooks", {})
    before = len(hooks.get("SessionStart", []))
    hooks["SessionStart"] = [
        g for g in hooks.get("SessionStart", [])
        if not any("serena-session-start-hook" in h.get("command", "")
                   for h in g.get("hooks", []))
    ]
    if len(hooks["SessionStart"]) < before:
        with open(p, "w") as f: json.dump(s, f, indent=2)
        print("  ✔ SessionStart hook removed from settings.json")
    else:
        print("  → SessionStart hook not found in settings.json")

# CLAUDE.md — remove Serena MCP section (line-by-line, safe)
p = os.path.join(cd, "CLAUDE.md")
if os.path.exists(p):
    with open(p) as f: lines = f.readlines()
    out, skip = [], False
    for line in lines:
        if line.startswith("# Serena MCP"):
            skip = True; continue
        if skip and line.startswith("# ") and not line.startswith("## "):
            skip = False
        if not skip:
            out.append(line)
    if len(out) < len(lines):
        with open(p, "w") as f: f.writelines(out)
        print("  ✔ Serena section removed from CLAUDE.md")
    else:
        print("  → Serena section not found in CLAUDE.md")
PYEOF
fi  # end DO_SERENA

# ── Headroom ─────────────────────────────────────────────────────────────────
if [[ "$DO_HEADROOM" =~ ^[Yy]$ ]]; then
step "Headroom"

python3 << 'PYEOF'
import os

shell = os.environ.get("SHELL", "")
home  = os.path.expanduser("~")
if "zsh" in shell or os.path.exists(os.path.join(home, ".zshrc")):
    profile = os.path.join(home, ".zshrc")
elif "bash" in shell or os.path.exists(os.path.join(home, ".bash_profile")):
    profile = os.path.join(home, ".bash_profile")
else:
    profile = os.path.join(home, ".profile")

if not os.path.exists(profile):
    print(f"  → {profile} not found"); exit()

with open(profile) as f:
    content = f.read()

if "# Headroom wrap" not in content:
    print(f"  → Headroom claude() not found in {profile}"); exit()

# Remove from "# Headroom wrap" comment through the closing } of claude()
lines = content.split("\n")
out, skip = [], False
for line in lines:
    if "# Headroom wrap" in line:
        skip = True
        if out and out[-1].strip() == "":
            out.pop()  # remove preceding blank line
        continue
    if skip:
        if line.strip() == "}":
            skip = False
        continue
    out.append(line)

with open(profile, "w") as f:
    f.write("\n".join(out))
print(f"  ✔ Headroom claude() removed from {profile}")
PYEOF

if command -v headroom &>/dev/null; then
  read_tty "  Also pip uninstall headroom-ai? [y/N] → " DO_PIP
  if [[ "${DO_PIP:-N}" =~ ^[Yy]$ ]]; then
    python3 -m pip uninstall headroom-ai -y --quiet && ok "headroom-ai uninstalled" || warn "pip uninstall failed"
  else
    info "Kept headroom-ai — remove later: python3 -m pip uninstall headroom-ai"
  fi
fi
fi  # end DO_HEADROOM

# ── RTK ──────────────────────────────────────────────────────────────────────
if [[ "$DO_RTK" =~ ^[Yy]$ ]]; then
step "RTK"

RTK_BIN="$HOME/.local/bin/rtk"
[[ -f "$RTK_BIN" ]] \
  && { rm -f "$RTK_BIN"; ok "Removed $RTK_BIN"; } \
  || info "RTK binary not found at $RTK_BIN"

python3 << 'PYEOF'
import json, os

p = os.path.join(os.path.expanduser("~"), ".claude", "settings.json")
if not os.path.exists(p):
    print("  → settings.json not found"); exit()
with open(p) as f: s = json.load(f)
changed = False
for event in list(s.get("hooks", {})):
    before = len(s["hooks"][event])
    s["hooks"][event] = [
        g for g in s["hooks"][event]
        if not any("rtk" in h.get("command", "").lower() for h in g.get("hooks", []))
    ]
    if len(s["hooks"][event]) < before:
        changed = True
if changed:
    with open(p, "w") as f: json.dump(s, f, indent=2)
    print("  ✔ RTK hooks removed from settings.json")
else:
    print("  → No RTK hooks found in settings.json")
PYEOF
fi  # end DO_RTK

# ── Caveman ───────────────────────────────────────────────────────────────────
if [[ "$DO_CAVEMAN" =~ ^[Yy]$ ]]; then
step "Caveman"
[[ -d "$CLAUDE_DIR/skills/caveman" ]] \
  && { rm -rf "$CLAUDE_DIR/skills/caveman"; ok "Removed skills/caveman/"; } \
  || info "skills/caveman/ not found"
fi  # end DO_CAVEMAN

# ── Done ──────────────────────────────────────────────────────────────────────
echo -e ""
echo -e "${GREEN}╔══════════════════════════════════════════════════════╗${RESET}"
echo -e "${GREEN}║  ✔  Done. Reload shell to apply changes:             ║${RESET}"
echo -e "${GREEN}║     source ~/.zshrc  (or ~/.bash_profile)            ║${RESET}"
echo -e "${GREEN}╚══════════════════════════════════════════════════════╝${RESET}"
echo -e ""
