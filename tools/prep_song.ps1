# 1) extracts the lyrics text from the .docx into audio\lyrics_raw.txt
# 2) lists available tools  3) downloads the performance video to %TEMP% (offline analysis only; not committed)
$ErrorActionPreference = 'Continue'
$root = Split-Path $PSScriptRoot -Parent
$log = Join-Path $PSScriptRoot '_check\prep.log'; New-Item -ItemType Directory -Force (Split-Path $log) | Out-Null
"" | Set-Content $log -Encoding utf8
function L($m) { Add-Content $log $m -Encoding utf8 }
$mmo = Join-Path (Split-Path (Split-Path $root -Parent) -Parent) 'IntelliCARE Phase 3 Content Plans\Learn Singing with Alyssa MMOs'
$docx = Get-ChildItem $mmo -Filter '*Lyrics and Credits*.docx' -ErrorAction SilentlyContinue | Where-Object { $_.Name -notmatch 'Mend|Rainbow' -and $_.Name -notmatch '^~' } | Select-Object -First 1
$cand = Get-ChildItem $root -Recurse -Filter '*.docx' -ErrorAction SilentlyContinue | Select-Object -First 1; if (-not $docx -and $cand) { $docx = $cand }
L "DOCX: $($docx.FullName)"
if ($docx) {
  Add-Type -AssemblyName System.IO.Compression.FileSystem
  $z = [IO.Compression.ZipFile]::OpenRead($docx.FullName); $e = $z.GetEntry('word/document.xml'); $sr = New-Object IO.StreamReader($e.Open(), [Text.Encoding]::UTF8); $xml = $sr.ReadToEnd(); $sr.Close(); $z.Dispose()
  $paras = [regex]::Matches($xml, '<w:p[ >].*?</w:p>', 'Singleline') | ForEach-Object { ([regex]::Matches($_.Value, '<w:t[^>]*>(.*?)</w:t>') | ForEach-Object { $_.Groups[1].Value }) -join '' }
  $txt = ($paras -join "`n") -replace '&amp;', '&' -replace '&lt;', '<' -replace '&gt;', '>' -replace '&quot;', '"' -replace '&apos;', "'"
  [IO.File]::WriteAllText((Join-Path $root 'audio\lyrics_raw.txt'), $txt, (New-Object Text.UTF8Encoding $false)); L "LYRICS lines: $($paras.Count)"
}
foreach ($c in 'python', 'py', 'ffmpeg', 'whisper', 'pip') { $g = Get-Command $c -ErrorAction SilentlyContinue; L "TOOL $c = $(if ($g) { $g.Source } else { '-' })" }
try { $v = & python --version 2>&1; L "PYVER $v"; $m = & python -c "import importlib.util as u;print([m for m in ['numpy','scipy','librosa','torch','demucs','whisper','faster_whisper','soundfile'] if u.find_spec(m)])" 2>&1; L "PYMODS $m" } catch { L "PY ERR $_" }
$vid = Join-Path $env:TEMP 'alyssa_ep03.mp4'
if (-not (Test-Path $vid) -or (Get-Item $vid).Length -lt 1MB) {
  try { $ProgressPreference = 'SilentlyContinue'; Invoke-WebRequest 'https://d2yy42b28nebea.cloudfront.net/activity/Alyssa_Lie_Ep_03_-_20260311_0a1f7d2e_20260311_23d7d845.mp4' -OutFile $vid -UseBasicParsing; L "VIDEO downloaded" } catch { L "VIDEO ERR $_" }
}
if (Test-Path $vid) { L "VIDEO $vid $([math]::Round((Get-Item $vid).Length/1MB,1)) MB" }
L "PREP DONE"
