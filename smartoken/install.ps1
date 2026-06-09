# deploy-setup.ps1 — Deploy Serena + Headroom Claude setup (Windows)
# Idempotent: safe to run multiple times on the same or a new machine.
# Run with: powershell -ExecutionPolicy Bypass -File deploy-setup.ps1

$ErrorActionPreference = "Stop"

function Ok($msg)   { Write-Host "  v $msg" -ForegroundColor Green }
function Info($msg) { Write-Host "  -> $msg" -ForegroundColor Cyan }
function Warn($msg) { Write-Host "  ! $msg" -ForegroundColor Yellow }
function Fail($msg) { Write-Host "  X $msg" -ForegroundColor Red; exit 1 }
function Step($msg) { Write-Host "`n$msg" -ForegroundColor White }

Clear-Host
Write-Host ""
Write-Host "  _____ __  __    _    ____ _____ ___  _  _______ _   _" -ForegroundColor Magenta
Write-Host " / ____|  \/  |  / \  |  _ \_   _/ _ \| |/ / ____| \ | |" -ForegroundColor Magenta
Write-Host " \__  \| |\/| | / _ \ | |_) || || | | | ' /|  _| |  \| |" -ForegroundColor Magenta
Write-Host "  __) | |  | |/ ___ \|  _ < | || |_| | . \| |___| |\  |" -ForegroundColor Magenta
Write-Host " |____/|_|  |_/_/   \_\_| \_\|_| \___/|_|\_\_____|_| \_|" -ForegroundColor Magenta
Write-Host ""
Write-Host "  Claude Code - Token Efficiency Stack   60-95% fewer tokens" -ForegroundColor White
Write-Host ""
Write-Host "  +-----------------------------------------------------------+" -ForegroundColor Cyan
Write-Host "  |  Tool        What it cuts                  Savings        |" -ForegroundColor Cyan
Write-Host "  +-----------------------------------------------------------+" -ForegroundColor Cyan
Write-Host "  |  Serena      code file reads -> symbols    60-90% input   |" -ForegroundColor White
Write-Host "  |  Headroom    conversation context          60-95% input   |" -ForegroundColor White
Write-Host "  |  RTK         CLI output noise              60-90% input   |" -ForegroundColor White
Write-Host "  |  Caveman     AI response verbosity         65-75% output  |" -ForegroundColor White
Write-Host "  +-----------------------------------------------------------+" -ForegroundColor Cyan
Write-Host ""
Write-Host "  These tools are complementary - each targets a different source of waste." -ForegroundColor Gray
Write-Host "  Install all four for maximum savings." -ForegroundColor Gray
Write-Host ""
$installAll = Read-Host "  Install all? [Y/n]"
if ($installAll -match '^[Nn]') {
  $doSerena   = Read-Host "  Install Serena?   [Y/n]"
  $doHeadroom = Read-Host "  Install Headroom? [Y/n]"
  $doRtk      = Read-Host "  Install RTK?      [Y/n]"
  $doCaveman  = Read-Host "  Install Caveman?  [Y/n]"
  $doSerena   = if ($doSerena   -match '^[Nn]') { "N" } else { "Y" }
  $doHeadroom = if ($doHeadroom -match '^[Nn]') { "N" } else { "Y" }
  $doRtk      = if ($doRtk     -match '^[Nn]') { "N" } else { "Y" }
  $doCaveman  = if ($doCaveman  -match '^[Nn]') { "N" } else { "Y" }
} else {
  $doSerena = "Y"; $doHeadroom = "Y"; $doRtk = "Y"; $doCaveman = "Y"
}
Write-Host ""

$ClaudeDir  = "$env:USERPROFILE\.claude"
$SkillsDir  = "$ClaudeDir\skills\serena-session-start"
$HooksDir   = "$ClaudeDir\hooks"

# ── 1. Prerequisites ────────────────────────────────────────────────────────
Step "1/9  Checking prerequisites"

if (-not (Get-Command claude -ErrorAction SilentlyContinue)) {
    Fail "Claude Code not found. Install it first: https://claude.ai/code"
}
Ok "Claude Code installed"

$PythonCmd = ""
if (Get-Command python3 -ErrorAction SilentlyContinue) { $PythonCmd = "python3" }
elseif (Get-Command python -ErrorAction SilentlyContinue) { $PythonCmd = "python" }
else { Fail "Python not found. Install Python 3.10+ from https://python.org" }
Ok "Python found: $PythonCmd"

# ── 2. Install uv (for Serena MCP) ─────────────────────────────────────────
Step "2/9  Serena dependency: uv"

if (Get-Command uvx -ErrorAction SilentlyContinue) {
    Ok "uvx already installed"
} else {
    Info "Installing uv (needed for Serena MCP)..."
    powershell -ExecutionPolicy ByPass -c "irm https://astral.sh/uv/install.ps1 | iex"
    $env:PATH = "$env:USERPROFILE\.local\bin;$env:PATH"
    Ok "uv installed"
}

# ── 3. Install headroom ─────────────────────────────────────────────────────
Step "3/9  Headroom"

if (Get-Command headroom -ErrorAction SilentlyContinue) {
    Ok "headroom already installed"
} else {
    $ans = Read-Host "  Install headroom-ai now? (60-95% token savings via wrap mode) [y/n]"
    if ($ans -eq "y") {
        pip install "headroom-ai[all]" --quiet
        Ok "headroom installed"
    } else {
        Warn "Skipped -- install later: pip install 'headroom-ai[all]'"
    }
}

# ── 4. Create directory structure ───────────────────────────────────────────
Step "4/9  Creating directories"

New-Item -ItemType Directory -Path $SkillsDir -Force | Out-Null
New-Item -ItemType Directory -Path $HooksDir  -Force | Out-Null
Ok "Directories ready"

# ── 5. Write skill + hook files ─────────────────────────────────────────────
Step "5/9  Writing skill + hook files"

# — Hook Python script —
$HookScript = @'
import json

print(json.dumps({
    "systemMessage": "\U0001f535 SERENA -- session start required. Claude will ask you about activation now.",
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
'@
Set-Content -Path "$HooksDir\serena-session-start-hook.py" -Value $HookScript -Encoding UTF8
Ok "Hook script: $HooksDir\serena-session-start-hook.py"

# — Skill SKILL.md —
$SkillMd = @'
---
name: serena-session-start
description: Serena MCP session initialization -- ask user, activate project, load or build memories. Enables token-efficient semantic code navigation. Invoke at the start of every session.
---

# Serena Session Start

## Purpose

Activate Serena MCP to unlock token-efficient semantic code navigation (find symbols, declarations,
references, replace function bodies) instead of expensive raw file reads.

---

## Step 1 -- Ask the User

Say exactly this, as your first message -- nothing before it, nothing after it on the same turn:

> SERENA MCP -- Activate for token-efficient code navigation? [y/n]

Wait for the response. If **n** -> skip this skill entirely and proceed normally.

If **y** -> continue below.

---

## Step 2 -- Load Serena Instructions

Call `mcp__oraios_serena__initial_instructions` (no arguments required).

This loads the Serena manual. **Required before any other Serena tool call.**

---

## Step 3 -- Detect the Project

Run `pwd` (or `Get-Location` on Windows) to get the project root.
Check for a Serena config: look for `project.yml` in CWD.

---

## Step 4 -- Activate

### Case A: project.yml found
1. Call `mcp__oraios_serena__activate_project` with `project_root = <CWD>`
2. Call `mcp__oraios_serena__list_memories`
3. Read top 3-5 memories via `mcp__oraios_serena__read_memory`

### Case B: project.yml NOT found
Offer to run onboarding: call `mcp__oraios_serena__onboarding` with `project_root = <CWD>`.
If declined, activate without config for basic symbol navigation.

---

## Step 5 -- Handle Technical Issues

| Symptom | Fix |
|---------|-----|
| `uvx: command not found` | Install uv from https://astral.sh/uv |
| `Connection refused` | Check config.json has correct uvx args |
| Any other error | Run the `serena-onboarding` skill |

---

## Step 6 -- Best Practices

| Instead of | Use |
|------------|-----|
| Read large code files | get_symbols_overview -> find_symbol -> find_declaration |
| grep for usages | find_referencing_symbols |
| Reading before editing | replace_symbol_body directly |
| Checking errors | get_diagnostics_for_file |
'@
Set-Content -Path "$SkillsDir\SKILL.md" -Value $SkillMd -Encoding UTF8
Ok "Skill: $SkillsDir\SKILL.md"

# ── 6. Merge config files (Python) ─────────────────────────────────────────
Step "6/9  Merging Claude config files"

# Use the detected python command (handle forward slashes for Windows paths)
$HookCmdPath = "$ClaudeDir\hooks\serena-session-start-hook.py" -replace '\\', '/'
$PythonScript = @"
import json, os, sys

home = os.path.expanduser('~')
claude_dir = os.path.join(home, '.claude')

# -- settings.json: add SessionStart hook ------------------------------------
settings_path = os.path.join(claude_dir, 'settings.json')
settings = {}
if os.path.exists(settings_path):
    with open(settings_path, encoding='utf-8') as f:
        settings = json.load(f)

hook_cmd = '$PythonCmd ~/.claude/hooks/serena-session-start-hook.py'
hooks = settings.setdefault('hooks', {})
session_hooks = hooks.setdefault('SessionStart', [])

already = any(
    any('serena-session-start-hook' in h.get('command', '')
        for h in group.get('hooks', []))
    for group in session_hooks
)
if not already:
    session_hooks.append({'hooks': [{'type': 'command', 'command': hook_cmd, 'timeout': 5}]})
    print('  v SessionStart hook added to settings.json')
else:
    print('  v SessionStart hook already present in settings.json')

with open(settings_path, 'w', encoding='utf-8') as f:
    json.dump(settings, f, indent=2)

# -- config.json: add Serena MCP server -------------------------------------
config_path = os.path.join(claude_dir, 'config.json')
config = {}
if os.path.exists(config_path):
    with open(config_path, encoding='utf-8') as f:
        config = json.load(f)

mcp = config.setdefault('mcpServers', {})
if 'oraios/serena' not in mcp:
    mcp['oraios/serena'] = {
        'type': 'stdio',
        'command': 'uvx',
        'args': [
            '--from', 'git+https://github.com/oraios/serena',
            'serena', 'start-mcp-server', 'serena@latest',
            '--context', 'ide-assistant'
        ],
        'gallery': 'https://api.mcp.github.com',
        'version': '1.0.0'
    }
    print('  v Serena MCP server added to config.json')
else:
    print('  v Serena MCP already present in config.json')

with open(config_path, 'w', encoding='utf-8') as f:
    json.dump(config, f, indent=2)

# -- CLAUDE.md: add Serena section ------------------------------------------
claude_md = os.path.join(claude_dir, 'CLAUDE.md')
serena_block = '''
# Serena MCP - Session Start
At the very start of every conversation, invoke the serena-session-start skill BEFORE any other response.
It asks the user whether to activate Serena, handles config detection, and loads project memories.
Once active: prefer Serena semantic tools (find_symbol, find_declaration, replace_symbol_body) over
raw Read calls on code files - this saves significant tokens.
'''
content = open(claude_md, encoding='utf-8').read() if os.path.exists(claude_md) else ''
if 'Serena MCP' not in content:
    with open(claude_md, 'a', encoding='utf-8') as f:
        f.write(serena_block)
    print('  v Serena section added to CLAUDE.md')
else:
    print('  v Serena section already present in CLAUDE.md')
"@

& $PythonCmd -c $PythonScript

# ── 7. PowerShell profile: Headroom claude function ─────────────────────────
Step "7/9  PowerShell profile: Headroom claude() function"

$ProfilePath = $PROFILE
if (-not (Test-Path (Split-Path $ProfilePath))) {
    New-Item -ItemType Directory -Path (Split-Path $ProfilePath) -Force | Out-Null
}
if (-not (Test-Path $ProfilePath)) { New-Item -ItemType File -Path $ProfilePath | Out-Null }

$ProfileContent = Get-Content $ProfilePath -Raw -ErrorAction SilentlyContinue
if ($ProfileContent -and $ProfileContent.Contains("Headroom wrap")) {
    Ok "Headroom claude() already in $ProfilePath"
} else {
    $HeadroomFunc = @'

# Headroom wrap -- ask per project before launching Claude
# Remembers choice via .headroom file in project root; "always" creates the file.
function claude {
    $cwd = (Get-Location).Path
    $marker = "$cwd\.headroom"

    if (Test-Path $marker) {
        Write-Host "HEADROOM wrap mode active for this project. (del .headroom to disable)" -ForegroundColor Green
        headroom wrap claude @args
        return
    }

    Write-Host ""
    Write-Host "================================================================" -ForegroundColor Yellow
    Write-Host "   HEADROOM  60-95% fewer tokens via wrap mode                  " -ForegroundColor Yellow
    Write-Host "================================================================" -ForegroundColor Yellow
    $ans = Read-Host "   Activate for this session? [y/always/n]"

    if ($ans -eq "always") {
        New-Item -ItemType File -Path $marker -Force | Out-Null
        Write-Host "   Saved .headroom -- auto-enabled for this project from now on." -ForegroundColor Green
        headroom wrap claude @args
    } elseif ($ans -eq "y") {
        Write-Host "   Headroom wrap mode on for this session." -ForegroundColor Green
        headroom wrap claude @args
    } else {
        Write-Host "   Skipping Headroom -- launching plain claude."
        & claude.exe @args
    }
}
'@
    Add-Content -Path $ProfilePath -Value $HeadroomFunc -Encoding UTF8
    Ok "Headroom claude() added to $ProfilePath"
}


# ── 8. RTK — CLI output compressor ───────────────────────────────────────────
if ($doRtk -eq "Y") {
Step "8/9  RTK — CLI output compressor"
$rtkPath = "$env:USERPROFILE\.local\bin\rtk.exe"
if (Get-Command rtk -ErrorAction SilentlyContinue) {
    Ok "RTK already installed"
} else {
    Info "Downloading RTK..."
    $arch = if ($env:PROCESSOR_ARCHITECTURE -eq "ARM64") { "aarch64" } else { "x86_64" }
    $rtkUrl = "https://github.com/rtk-ai/rtk/releases/latest/download/rtk-$arch-pc-windows-msvc.zip"
    $zipPath = "$env:TEMP\rtk.zip"
    $binDir = "$env:USERPROFILE\.local\bin"
    New-Item -ItemType Directory -Path $binDir -Force | Out-Null
    try {
        Invoke-WebRequest -Uri $rtkUrl -OutFile $zipPath -UseBasicParsing
        Expand-Archive -Path $zipPath -DestinationPath $binDir -Force
        Remove-Item $zipPath
        $env:PATH += ";$binDir"
        if (Get-Command rtk -ErrorAction SilentlyContinue) {
            rtk init --claude-code 2>$null
            Ok "RTK installed and wired to Claude Code"
        } else {
            Info "RTK installed to $binDir — add to PATH then run: rtk init --claude-code"
        }
    } catch {
        Warn "RTK install failed: $_"
    }
}

}  # end RTK gate

# ── 9. Caveman — AI response compressor ───────────────────────────────────────
if ($doCaveman -eq "Y") {
Step "9/9  Caveman — AI response compressor"
if (Test-Path "$ClaudeDir\skills\caveman\SKILL.md") {
    Ok "Caveman already installed"
} else {
    $nodeOk = $false
    try {
        $nodeVer = (node --version 2>$null) -replace 'v','' -split '\.' | Select-Object -First 1
        if ([int]$nodeVer -ge 18) { $nodeOk = $true }
    } catch {}
    if (-not $nodeOk) {
        Warn "Caveman requires Node >=18 — skipping. Install Node then re-run."
    } else {
        Info "Installing Caveman..."
        try {
            irm https://raw.githubusercontent.com/JuliusBrussee/caveman/main/install.ps1 | iex
            Ok "Caveman installed"
        } catch {
            Warn "Caveman install failed: $_"
        }
    }
}

}  # end Caveman gate

# ── Done ─────────────────────────────────────────────────────────────────────
Write-Host ""
Write-Host "================================================================" -ForegroundColor Green
Write-Host "  Setup complete!                                                " -ForegroundColor Green
Write-Host "  Reload your profile: . `$PROFILE                              " -ForegroundColor Green
Write-Host "================================================================" -ForegroundColor Green
Write-Host ""
Write-Host "  What was deployed:" -ForegroundColor White
Write-Host "  * Serena MCP server  -> $ClaudeDir\config.json"
Write-Host "  * SessionStart hook  -> $ClaudeDir\settings.json"
Write-Host "  * Serena skill       -> $SkillsDir\"
Write-Host "  * CLAUDE.md section  -> $ClaudeDir\CLAUDE.md"
Write-Host "  * Headroom claude()  -> $ProfilePath"
Write-Host ""
