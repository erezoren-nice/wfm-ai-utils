# smartoken

One-command setup that cuts Claude Code token usage by **60–95%** on everyday dev tasks.

It installs two tools:

| Tool | What it does | Savings |
|------|-------------|---------|
| **Serena MCP** | Semantic code navigation — find symbols, declarations, references without reading whole files | 60–90% on code tasks |
| **Headroom** | Compresses Claude's context window before each session | 60–95% per session |

---

## Install

### Mac / Linux

```bash
bash install.sh
```

> Requires: [Claude Code](https://claude.ai/code), Python 3.10+

### Windows

Open PowerShell as Administrator, then run:

```powershell
powershell -ExecutionPolicy Bypass -File install.ps1
```

> Requires: [Claude Code](https://claude.ai/code), Python 3.10+

---

## What gets installed

| Component | Location |
|-----------|----------|
| Serena MCP server | `~/.claude/config.json` |
| Session-start hook | `~/.claude/settings.json` |
| Serena skill file | `~/.claude/skills/serena-session-start/` |
| CLAUDE.md instructions | `~/.claude/CLAUDE.md` |
| Headroom `claude()` wrapper | `~/.zshrc` / `~/.bash_profile` / PowerShell profile |

The installer is **idempotent** — safe to run multiple times; it won't duplicate anything.

---

## How it works after install

### Serena

At the start of every Claude session you'll be asked:

```
🔵 SERENA MCP — Activate for token-efficient code navigation? [y/n]
```

Say **y** to activate for that session. Serena then navigates your codebase semantically instead of reading full files.

### Headroom

When you open a new Claude session from the terminal, you'll be asked once per project:

```
🚀 HEADROOM  60-95% fewer tokens via wrap mode
   Activate for this session? [y/always/n] →
```

- **y** — enabled for this session only
- **always** — creates a `.headroom` file in the project root; auto-enables from now on
- **n** — skip, launch plain Claude

---

## Prerequisites

| Requirement | Mac/Linux | Windows |
|-------------|-----------|---------|
| Claude Code | `brew install claude` or [claude.ai/code](https://claude.ai/code) | [claude.ai/code](https://claude.ai/code) |
| Python 3.10+ | `brew install python` | [python.org](https://www.python.org/downloads/) |
| pip | Included with Python | Included with Python |

The installer handles everything else (uv, Serena, headroom-ai) automatically.

---

## Uninstall

Remove the Serena MCP entry from `~/.claude/config.json`, the hook from `~/.claude/settings.json`, and the `claude()` function from your shell profile. Delete `~/.claude/skills/serena-session-start/` and `~/.claude/hooks/serena-session-start-hook.py`.
