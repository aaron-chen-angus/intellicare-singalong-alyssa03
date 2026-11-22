# Headless analysis of audio\vocal.* → tools\vocalmap.json, then embeds it inline in index.html.
# Usage: powershell -ExecutionPolicy Bypass -File tools\run_analyze_vocal.ps1 [-Vocal path] [-NoEmbed]
param([string]$Vocal = '', [switch]$NoEmbed, [int]$Port = 9361)
$root = Split-Path $PSScriptRoot -Parent
function Find-Audio($base) { foreach ($e in 'wav', 'flac', 'mp3', 'm4a') { $p = Join-Path $root "audio\$base.$e"; if (Test-Path $p) { return $p } } return $null }
if (-not $Vocal) { $Vocal = Find-Audio 'vocal' }
if (-not $Vocal) { Write-Host "No audio\vocal.* found. The app keeps its labelled synthetic demo map. See audio\PUT_STEMS_HERE.txt"; exit 1 }
$q = "vocal=" + [Uri]::EscapeDataString(([Uri]$Vocal).AbsoluteUri)
$ins = Find-Audio 'instrumental'; if ($ins) { $q += "&instr=" + [Uri]::EscapeDataString(([Uri]$ins).AbsoluteUri) }
foreach ($pair in @(@('lyrics', 'lyrics.txt'), @('pinyin', 'lyrics_pinyin.txt'))) { $p = Join-Path $root ("audio\" + $pair[1]); if (Test-Path $p) { $q += "&$($pair[0])=" + [Uri]::EscapeDataString(([Uri]$p).AbsoluteUri) } }
$url = ([Uri](Join-Path $PSScriptRoot 'analyze_vocal.html')).AbsoluteUri + "?" + $q
$chk = Join-Path $PSScriptRoot '_check'; New-Item -ItemType Directory -Force $chk | Out-Null; $raw = Join-Path $chk 'analysis.json'
& powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $PSScriptRoot 'cdp_run.ps1') -Url $url -Expr "window.__RESULT" -OutFile $raw -TimeoutSec 900 -Port $Port
$res = Get-Content $raw -Raw -Encoding utf8 | ConvertFrom-Json
if ($res.error) { Write-Host "ANALYSIS FAILED:`n$($res.error)"; exit 2 }
$res.log | ForEach-Object { Write-Host $_ }
$mapJson = $res.map | ConvertTo-Json -Depth 12 -Compress
[IO.File]::WriteAllText((Join-Path $PSScriptRoot 'vocalmap.json'), $mapJson, (New-Object Text.UTF8Encoding $false))
[IO.File]::WriteAllBytes((Join-Path $chk 'preview.png'), [Convert]::FromBase64String(($res.preview -replace '^data:image/png;base64,', '')))
Write-Host "QA: $($res.qa | ConvertTo-Json -Compress)"
if (-not $NoEmbed) {
  $idx = Join-Path $root 'index.html'; $html = [IO.File]::ReadAllText($idx)
  $new = [regex]::Replace($html, '(<script type="application/json" id="vocalmap">)(.*?)(</script>)', { param($m) $m.Groups[1].Value + $mapJson + $m.Groups[3].Value }, 'Singleline')
  [IO.File]::WriteAllText($idx, $new, (New-Object Text.UTF8Encoding $false)); Write-Host "Embedded vocalmap into index.html ($([int]($mapJson.Length/1024)) KB). Review sections, then run tools\run_tests.ps1"
}
