# smartoken

One-command setup that installs a four-tool token efficiency stack for Claude Code.
**60–95% fewer tokens** on everyday dev tasks — without changing your workflow.

---

## The Stack

Each tool attacks a different source of token waste. Use all four together.

| Tool | What it cuts | Savings |
|------|-------------|---------|
| **Serena** | Code file reads → targeted symbol lookups | 60–90% input tokens |
| **Headroom** | Conversation context compression | 60–95% input tokens |
| **RTK** | CLI output noise (git, test runners, grep, find) | 60–90% input tokens |
| **Caveman** | AI response verbosity (terse "caveman" speech mode) | 65–75% output tokens |

---

## Install

### Mac / Linux

```bash
bash install.sh
```

> Requires: [Claude Code](https://claude.ai/code), Python 3.10+, Node ≥18 (for Caveman)

### Windows

Open PowerShell as Administrator:

```powershell
powershell -ExecutionPolicy Bypass -File install.ps1
```

> Requires: [Claude Code](https://claude.ai/code), Python 3.10+, Node ≥18 (for Caveman)

The installer shows a menu — press **Enter** to install all four, or choose individually.

---

## How each tool works after install

### Serena
At the start of each Claude session you'll be asked:
```
🔵 SERENA MCP — Activate for token-efficient code navigation? [y/n]
```
Say **y** to activate. Serena navigates your codebase using symbol trees instead of reading full files.

### Headroom
When you open Claude from the terminal, you'll be asked once per project:
```
🚀 HEADROOM  60-95% fewer tokens via wrap mode
   Activate for this session? [y/always/n] →
```
- **y** — enabled for this session
- **always** — auto-enables for this project from now on
- **n** — skip, open plain Claude

### RTK
Transparent — runs automatically via a Claude Code hook. Every Bash command output is filtered before it hits Claude's context. Check your savings with:
```bash
rtk gain
```

### Caveman
Trigger with `/caveman` or say "talk like caveman" in any session.
Stop with "normal mode". Intensities: `lite`, `full` (default), `ultra`.

---

## Prerequisites

| Requirement | Mac/Linux | Windows |
|-------------|-----------|---------|
| Claude Code | [claude.ai/code](https://claude.ai/code) | [claude.ai/code](https://claude.ai/code) |
| Python 3.10+ | `brew install python` | [python.org](https://www.python.org/downloads/) |
| Node ≥18 *(Caveman only)* | `brew install node` | [nodejs.org](https://nodejs.org/) |

The installer handles uv, Serena MCP, headroom-ai, RTK binary, and Caveman automatically.

---

## What gets installed

| Component | Location |
|-----------|----------|
| Serena MCP server config | `~/.claude/config.json` |
| SessionStart hook | `~/.claude/settings.json` |
| Serena skill file | `~/.claude/skills/serena-session-start/` |
| Caveman skill file | `~/.claude/skills/caveman/` |
| CLAUDE.md instructions | `~/.claude/CLAUDE.md` |
| RTK binary | `~/.local/bin/rtk` |
| RTK Claude Code hook | `~/.claude/settings.json` |
| Headroom `claude()` wrapper | `~/.zshrc` / `~/.bash_profile` / PowerShell profile |

The installer is **idempotent** — safe to run multiple times.
