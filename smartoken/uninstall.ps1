# uninstall-smartoken.ps1 — Remove smartoken token efficiency stack (Windows)
# Idempotent: safe to run multiple times.
# Run with: powershell -ExecutionPolicy Bypass -File uninstall.ps1

$ErrorActionPreference = "Stop"

function Ok($msg)   { Write-Host "  v $msg" -ForegroundColor Green }
function Info($msg) { Write-Host "  -> $msg" -ForegroundColor Cyan }
function Warn($msg) { Write-Host "  ! $msg" -ForegroundColor Yellow }
function Step($msg) { Write-Host "`n$msg" -ForegroundColor White }

Clear-Host
Write-Host ""
Write-Host "  smartoken -- Uninstaller" -ForegroundColor Magenta
Write-Host "  Removes Serena, Headroom, RTK, Caveman" -ForegroundColor DarkGray
Write-Host ""

$uninstallAll = Read-Host "  Uninstall all four tools? [Y/n]"
if ($uninstallAll -match '^[Nn]') {
  $doSerena   = if ((Read-Host "  Uninstall Serena?   [Y/n]") -match '^[Nn]') { "N" } else { "Y" }
  $doHeadroom = if ((Read-Host "  Uninstall Headroom? [Y/n]") -match '^[Nn]') { "N" } else { "Y" }
  $doRtk      = if ((Read-Host "  Uninstall RTK?      [Y/n]") -match '^[Nn]') { "N" } else { "Y" }
  $doCaveman  = if ((Read-Host "  Uninstall Caveman?  [Y/n]") -match '^[Nn]') { "N" } else { "Y" }
} else {
  $doSerena = "Y"; $doHeadroom = "Y"; $doRtk = "Y"; $doCaveman = "Y"
}
Write-Host ""

$ClaudeDir = "$env:USERPROFILE\.claude"

# Detect Python
$PythonCmd = ""
if (Get-Command python3 -ErrorAction SilentlyContinue) { $PythonCmd = "python3" }
elseif (Get-Command python -ErrorAction SilentlyContinue) { $PythonCmd = "python" }
else { Write-Host "  ! Python not found -- JSON cleanup steps skipped" -ForegroundColor Yellow }

# ── Serena ───────────────────────────────────────────────────────────────────
if ($doSerena -eq "Y") {
Step "Serena"

$d = "$ClaudeDir\skills\serena-session-start"
if (Test-Path $d) { Remove-Item $d -Recurse -Force; Ok "Removed skills\serena-session-start\" }
else { Info "skills\serena-session-start\ not found" }

$h = "$ClaudeDir\hooks\serena-session-start-hook.py"
if (Test-Path $h) { Remove-Item $h -Force; Ok "Removed hooks\serena-session-start-hook.py" }

if ($PythonCmd) {
$Script = @'
import json, os

home = os.path.expanduser("~")
cd   = os.path.join(home, ".claude")

p = os.path.join(cd, "config.json")
if os.path.exists(p):
    with open(p, encoding="utf-8") as f: cfg = json.load(f)
    if "oraios/serena" in cfg.get("mcpServers", {}):
        del cfg["mcpServers"]["oraios/serena"]
        with open(p, "w", encoding="utf-8") as f: json.dump(cfg, f, indent=2)
        print("  v Serena removed from config.json")
    else:
        print("  -> Serena not in config.json")

p = os.path.join(cd, "settings.json")
if os.path.exists(p):
    with open(p, encoding="utf-8") as f: s = json.load(f)
    hooks = s.get("hooks", {})
    before = len(hooks.get("SessionStart", []))
    hooks["SessionStart"] = [
        g for g in hooks.get("SessionStart", [])
        if not any("serena-session-start-hook" in h.get("command", "")
                   for h in g.get("hooks", []))
    ]
    if len(hooks["SessionStart"]) < before:
        with open(p, "w", encoding="utf-8") as f: json.dump(s, f, indent=2)
        print("  v SessionStart hook removed from settings.json")
    else:
        print("  -> SessionStart hook not found in settings.json")

p = os.path.join(cd, "CLAUDE.md")
if os.path.exists(p):
    with open(p, encoding="utf-8") as f: lines = f.readlines()
    out, skip = [], False
    for line in lines:
        if line.startswith("# Serena MCP"):
            skip = True; continue
        if skip and line.startswith("# ") and not line.startswith("## "):
            skip = False
        if not skip:
            out.append(line)
    if len(out) < len(lines):
        with open(p, "w", encoding="utf-8") as f: f.writelines(out)
        print("  v Serena section removed from CLAUDE.md")
    else:
        print("  -> Serena section not found in CLAUDE.md")
'@
& $PythonCmd -c $Script
}
}  # end Serena

# ── Headroom ─────────────────────────────────────────────────────────────────
if ($doHeadroom -eq "Y") {
Step "Headroom"

$ProfilePath = $PROFILE
if ($PythonCmd -and (Test-Path $ProfilePath)) {
$Script = @"
import os

profile = r'$ProfilePath'
try:
    with open(profile, encoding='utf-8') as f:
        content = f.read()
except FileNotFoundError:
    print(f'  -> {profile} not found'); exit()

if '# Headroom wrap' not in content:
    print(f'  -> Headroom claude() not found in {profile}'); exit()

lines = content.split('\n')
out, skip = [], False
for line in lines:
    if '# Headroom wrap' in line:
        skip = True
        if out and out[-1].strip() == '':
            out.pop()
        continue
    if skip:
        if line.strip() == '}':
            skip = False
        continue
    out.append(line)

with open(profile, 'w', encoding='utf-8') as f:
    f.write('\n'.join(out))
print(f'  v Headroom claude() removed from {profile}')
"@
& $PythonCmd -c $Script
}

if (Get-Command headroom -ErrorAction SilentlyContinue) {
    $ans = Read-Host "  Also pip uninstall headroom-ai? [y/N]"
    if ($ans -eq "y") {
        & $PythonCmd -m pip uninstall headroom-ai -y --quiet
        Ok "headroom-ai uninstalled"
    } else {
        Info "Kept headroom-ai -- remove later: python -m pip uninstall headroom-ai"
    }
}
}  # end Headroom

# ── RTK ──────────────────────────────────────────────────────────────────────
if ($doRtk -eq "Y") {
Step "RTK"

$rtkBin = "$env:USERPROFILE\.local\bin\rtk.exe"
if (Test-Path $rtkBin) { Remove-Item $rtkBin -Force; Ok "Removed $rtkBin" }
else { Info "RTK binary not found at $rtkBin" }

if ($PythonCmd) {
$Script = @'
import json, os

p = os.path.join(os.path.expanduser("~"), ".claude", "settings.json")
if not os.path.exists(p):
    print("  -> settings.json not found"); exit()
with open(p, encoding="utf-8") as f: s = json.load(f)
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
    with open(p, "w", encoding="utf-8") as f: json.dump(s, f, indent=2)
    print("  v RTK hooks removed from settings.json")
else:
    print("  -> No RTK hooks found in settings.json")
'@
& $PythonCmd -c $Script
}
}  # end RTK

# ── Caveman ───────────────────────────────────────────────────────────────────
if ($doCaveman -eq "Y") {
Step "Caveman"
$d = "$ClaudeDir\skills\caveman"
if (Test-Path $d) { Remove-Item $d -Recurse -Force; Ok "Removed skills\caveman\" }
else { Info "skills\caveman\ not found" }
}  # end Caveman

# ── Done ─────────────────────────────────────────────────────────────────────
Write-Host ""
Write-Host "================================================================" -ForegroundColor Green
Write-Host "  Done. Reload your PowerShell profile:                         " -ForegroundColor Green
Write-Host "  . `$PROFILE                                                   " -ForegroundColor Green
Write-Host "================================================================" -ForegroundColor Green
Write-Host ""
