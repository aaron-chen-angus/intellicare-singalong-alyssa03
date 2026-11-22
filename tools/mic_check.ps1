# Starts the app's real microphone path with your real default mic (headless Edge) and prints what happened.
# Usage: powershell -ExecutionPolicy Bypass -File tools\mic_check.ps1 [-Mode headphones|speakers|demo] [-Engine worklet|script]
param([string]$Mode = 'headphones', [string]$Engine = 'worklet', [int]$Port = 9391)
$root = Split-Path $PSScriptRoot -Parent
$u = ([Uri](Join-Path $root 'index.html')).AbsoluteUri + "?micprobe=$Mode&engine=$Engine"
$out = Join-Path $PSScriptRoot "_check\mic_${Mode}_$Engine.txt"; New-Item -ItemType Directory -Force (Split-Path $out) | Out-Null
& powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $PSScriptRoot 'cdp_run.ps1') -Url $u -Expr "window.__probe" -OutFile $out -TimeoutSec 40 -Port $Port -ExtraArgs '--use-fake-ui-for-media-stream' | Out-Null
"RESULT $Mode/$Engine " + (Get-Content $out -Raw -Encoding utf8)
