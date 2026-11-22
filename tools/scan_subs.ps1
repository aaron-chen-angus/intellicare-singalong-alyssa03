param([double]$Step = 0.2)
$vid = Join-Path $env:TEMP 'alyssa_ep03.mp4'
$u = ([Uri](Join-Path $PSScriptRoot 'scan_subs.html')).AbsoluteUri + '?video=' + [Uri]::EscapeDataString(([Uri]$vid).AbsoluteUri) + "&step=$Step"
$raw = Join-Path $PSScriptRoot '_check\subs.json'
& powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $PSScriptRoot 'cdp_run.ps1') -Url $u -Expr 'window.__RESULT' -OutFile $raw -TimeoutSec 1500 -Port 9396 | Out-Null
$r = Get-Content $raw -Raw | ConvertFrom-Json
if ($r.sheet) { [IO.File]::WriteAllBytes((Join-Path $PSScriptRoot '_check\subs_sheet.jpg'), [Convert]::FromBase64String(($r.sheet -replace '^data:image/\w+;base64,', ''))) }
($r.segs | ForEach-Object -Begin { $i = 0 } -Process { "{0}`t{1}`t{2}`tw={3}`tn={4}" -f $i++, $_.t0, $_.t1, $_.w, $_.n }) | Set-Content (Join-Path $PSScriptRoot '_check\subs.txt')
"segments=$($r.segs.Count)" | Add-Content (Join-Path $PSScriptRoot '_check\subs.txt')
