# Builds the real vocal map from the performance video (no stems needed) and embeds it in index.html.
# Needs: %TEMP%\alyssa_ep03.mp4 (tools\prep_song.ps1), tools\_check\subs.json (tools\scan_subs.ps1), audio\lyrics.txt, audio\lyrics_pinyin.txt
param([int]$Embed = 0)   # -Embed 1 writes the map into index.html
$NoEmbed = ($Embed -ne 1)
$root = Split-Path $PSScriptRoot -Parent; $chk = Join-Path $PSScriptRoot '_check'
$f = { param($p) [Uri]::EscapeDataString(([Uri]$p).AbsoluteUri) }
$u = ([Uri](Join-Path $PSScriptRoot 'extract_melody.html')).AbsoluteUri + '?video=' + (& $f (Join-Path $env:TEMP 'alyssa_ep03.mp4')) + '&subs=' + (& $f (Join-Path $chk 'subs.json')) + '&lyrics=' + (& $f (Join-Path $root 'audio\lyrics.txt')) + '&pinyin=' + (& $f (Join-Path $root 'audio\lyrics_pinyin.txt'))
$raw = Join-Path $chk 'melody.json'
& powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $PSScriptRoot 'cdp_run.ps1') -Url $u -Expr 'window.__RESULT' -OutFile $raw -TimeoutSec 1500 -Port 9397 | Out-Null
$r = Get-Content $raw -Raw -Encoding utf8 | ConvertFrom-Json
($r.log -join "`n") | Set-Content (Join-Path $chk 'melody.log') -Encoding utf8
if ($r.error) { "ERROR $($r.error)" | Add-Content (Join-Path $chk 'melody.log') -Encoding utf8; exit 2 }
[IO.File]::WriteAllBytes((Join-Path $chk 'melody.png'), [Convert]::FromBase64String(($r.preview -replace '^data:image/\w+;base64,', '')))
$mapJson = $r.map | ConvertTo-Json -Depth 12 -Compress
[IO.File]::WriteAllText((Join-Path $PSScriptRoot 'vocalmap.json'), $mapJson, (New-Object Text.UTF8Encoding $false))
if (-not $NoEmbed) {
  $idx = Join-Path $root 'index.html'; $html = [IO.File]::ReadAllText($idx)
  $new = [regex]::Replace($html, '(<script type="application/json" id="vocalmap">)(.*?)(</script>)', { param($m) $m.Groups[1].Value + $mapJson + $m.Groups[3].Value }, 'Singleline')
  [IO.File]::WriteAllText($idx, $new, (New-Object Text.UTF8Encoding $false)); "EMBEDDED $([int]($mapJson.Length/1024)) KB" | Add-Content (Join-Path $chk 'melody.log') -Encoding utf8
}
