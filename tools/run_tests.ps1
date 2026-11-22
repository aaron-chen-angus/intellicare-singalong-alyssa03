# Runs index.html?test=1 in headless Edge and prints the result list. Usage: powershell -ExecutionPolicy Bypass -File tools\run_tests.ps1
$root = Split-Path $PSScriptRoot -Parent
$u = ([Uri](Join-Path $root 'index.html')).AbsoluteUri + '?test=1'
New-Item -ItemType Directory -Force (Join-Path $PSScriptRoot '_check') | Out-Null
$out = Join-Path $PSScriptRoot '_check\test.txt'
& powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $PSScriptRoot 'cdp_run.ps1') -Url $u -Expr "(window.__TEST?document.querySelector('pre').textContent:'NO TEST '+document.body.innerText.slice(0,500))" -OutFile $out -TimeoutSec 180 -Port (Get-Random -Minimum 9400 -Maximum 9900) | Out-Null
Get-Content $out -Raw -Encoding utf8
