# Tiny static web server (no installs): serves the repo at http://localhost:8080/ so the microphone and AudioWorklet work properly.
# Usage: powershell -ExecutionPolicy Bypass -File tools\serve.ps1 [-Port 8080]   (Ctrl+C to stop)
param([int]$Port = 8080)
$root = Split-Path $PSScriptRoot -Parent
$mime = @{ '.html' = 'text/html; charset=utf-8'; '.js' = 'text/javascript'; '.json' = 'application/json'; '.png' = 'image/png'; '.jpg' = 'image/jpeg'; '.svg' = 'image/svg+xml'; '.css' = 'text/css'; '.wav' = 'audio/wav'; '.mp3' = 'audio/mpeg'; '.m4a' = 'audio/mp4'; '.flac' = 'audio/flac'; '.txt' = 'text/plain; charset=utf-8'; '.md' = 'text/plain; charset=utf-8' }
$l = New-Object Net.HttpListener; $l.Prefixes.Add("http://localhost:$Port/"); $l.Start()
Write-Host "Serving $root at http://localhost:$Port/  (keep this window open; Ctrl+C to stop)"
$edge = @("${env:ProgramFiles(x86)}\Microsoft\Edge\Application\msedge.exe", "$env:ProgramFiles\Microsoft\Edge\Application\msedge.exe") | Where-Object { Test-Path $_ } | Select-Object -First 1
if ($edge) { Start-Process $edge "http://localhost:$Port/" } else { Start-Process "http://localhost:$Port/" }
try {
  while ($l.IsListening) {
    $c = $l.GetContext(); $p = [Uri]::UnescapeDataString($c.Request.Url.AbsolutePath.TrimStart('/')); if (-not $p) { $p = 'index.html' }
    $full = [IO.Path]::GetFullPath((Join-Path $root $p))
    if ($full.StartsWith($root) -and (Test-Path $full -PathType Leaf)) {
      $b = [IO.File]::ReadAllBytes($full); $ext = [IO.Path]::GetExtension($full).ToLower(); $c.Response.ContentType = $(if ($mime[$ext]) { $mime[$ext] } else { 'application/octet-stream' })
      $c.Response.ContentLength64 = $b.Length; $c.Response.OutputStream.Write($b, 0, $b.Length)
    } else { $c.Response.StatusCode = 404 }
    $c.Response.Close()
  }
} finally { $l.Stop() }
