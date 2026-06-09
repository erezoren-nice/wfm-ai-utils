# wfm-ai-utils

A collection of AI developer utilities for the WFM engineering team.

---

## Utilities

### [smartoken](./smartoken/)

One-command installer for a four-tool Claude Code token efficiency stack.
Cuts token usage by **60–95%** across code navigation, context, CLI output, and AI responses.

| Tool | Cuts |
|------|------|
| Serena | Code file reads |
| Headroom | Context window |
| RTK | CLI output noise |
| Caveman | AI response verbosity |

**Mac/Linux:**
```bash
bash smartoken/install.sh
```

**Windows:**
```powershell
powershell -ExecutionPolicy Bypass -File smartoken/install.ps1
```

See [smartoken/README.md](./smartoken/README.md) for full details.

---

## Contributing

Add new utilities as top-level directories, each with their own `README.md`. Update this file with a short entry.
