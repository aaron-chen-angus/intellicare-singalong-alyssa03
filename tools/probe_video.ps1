param([double]$From = 0, [double]$To = 0, [string]$Name = 'probe')
$vid = Join-Path $env:TEMP 'alyssa_ep03.mp4'
$u = ([Uri](Join-Path $PSScriptRoot 'probe_video.html')).AbsoluteUri + '?video=' + [Uri]::EscapeDataString(([Uri]$vid).AbsoluteUri) + "&from=$From" + $(if ($To -gt 0) { "&to=$To" } else { '' })
$raw = Join-Path $PSScriptRoot "_check\$Name.json"
& powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $PSScriptRoot 'cdp_run.ps1') -Url $u -Expr 'window.__RESULT' -OutFile $raw -TimeoutSec 300 -Port 9395 | Out-Null
$r = Get-Content $raw -Raw | ConvertFrom-Json
if ($r.png) { [IO.File]::WriteAllBytes((Join-Path $PSScriptRoot "_check\$Name.jpg"), [Convert]::FromBase64String(($r.png -replace '^data:image/\w+;base64,', ''))) }
"duration=$($r.duration) size=$($r.w)x$($r.h) error=$($r.error)" | Set-Content (Join-Path $PSScriptRoot "_check\$Name.txt")
