# Live NPC probe for Echo Clinic v0.8.
# Reads DEEPSEEK_API_KEY from the current process or your user environment (never prints it),
# lists the models your account can use, then runs every probe case through the real game code.
# Usage:  powershell -ExecutionPolicy Bypass -File tools\run_npc_probe.ps1 [-Model deepseek-chat] [-Only 越狱]
param([string]$Model = "", [string]$Only = "")
$ErrorActionPreference = "Stop"
$root = Split-Path -Parent $PSScriptRoot
$key = $env:DEEPSEEK_API_KEY
if (-not $key) { $key = [Environment]::GetEnvironmentVariable("DEEPSEEK_API_KEY", "User") }
if (-not $key) { $key = [Environment]::GetEnvironmentVariable("DEEPSEEK_API_KEY", "Machine") }
if (-not $key) { Write-Error "DEEPSEEK_API_KEY is not set (process, user or machine)."; exit 2 }

$models = Invoke-RestMethod -Uri "https://api.deepseek.com/models" -Headers @{ Authorization = "Bearer $key" } -Method Get
$ids = @($models.data | ForEach-Object { $_.id })
Write-Output ("Available models: " + ($ids -join ", "))
if (-not $Model) { $Model = if ($ids -contains "deepseek-chat") { "deepseek-chat" } else { $ids[0] } }
Write-Output "Probing with: $Model"

$stamp = Get-Date -Format "yyyyMMdd-HHmmss"
$out = Join-Path $root "captures\npc-probe-$stamp"
New-Item -ItemType Directory -Force $out | Out-Null
$godot = Join-Path $root "tools\godot\Godot_v4.7.2-stable_win64_console.exe"
$gargs = @("--position", "8000,8000", "--path", (Join-Path $root "project"), "--", "--npc-probe", "--probe-model=$Model", "--capture-dir=$($out -replace '\\','/')")
if ($Only) { $gargs += "--probe-only=$Only" }
$env:DEEPSEEK_API_KEY = $key
try {
  & $godot @gargs 2>&1 | Out-File -Encoding utf8 (Join-Path $out "run.log")
} finally {
  Remove-Item Env:\DEEPSEEK_API_KEY -ErrorAction SilentlyContinue
}
Select-String -Path (Join-Path $out "run.log") -Pattern "^PROBE|^FAIL" | ForEach-Object { $_.Line }
Write-Output "Report: $out\npc-probe.md"
