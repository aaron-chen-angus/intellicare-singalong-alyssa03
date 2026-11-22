# Opens a URL in headless Edge, waits until document.title is DONE or ERROR,
# then evaluates $Expr (must return a string) and writes it to $OutFile.
param([Parameter(Mandatory)][string]$Url, [string]$Expr = "document.documentElement.outerHTML", [Parameter(Mandatory)][string]$OutFile, [int]$TimeoutSec = 900, [int]$Port = 9333, [string[]]$ExtraArgs = @())
$edge = "C:\Program Files (x86)\Microsoft\Edge\Application\msedge.exe"
$ud = Join-Path $env:TEMP ("icm_cdp_" + $Port)
$proc = Start-Process -FilePath $edge -ArgumentList (@("--headless=new", "--disable-gpu", "--no-first-run", "--user-data-dir=$ud", "--allow-file-access-from-files", "--autoplay-policy=no-user-gesture-required", "--remote-debugging-port=$Port", "--js-flags=--max-old-space-size=6144", "about:blank") + $ExtraArgs) -PassThru
try {
  $ws = $null
  for ($i = 0; $i -lt 60 -and -not $ws; $i++) { Start-Sleep -Milliseconds 500; try { $t = Invoke-RestMethod "http://127.0.0.1:$Port/json" -TimeoutSec 2; $pg = $t | Where-Object { $_.type -eq 'page' } | Select-Object -First 1; if ($pg) { $ws = $pg.webSocketDebuggerUrl } } catch {} }
  if (-not $ws) { throw "no CDP endpoint" }
  $sock = New-Object System.Net.WebSockets.ClientWebSocket
  $sock.Options.SetBuffer(65536, 65536)
  $sock.ConnectAsync([Uri]$ws, [Threading.CancellationToken]::None).Wait()
  $script:id = 0
  function Send-Cdp($method, $params) {
    $script:id++; $msg = @{ id = $script:id; method = $method; params = $params } | ConvertTo-Json -Depth 6 -Compress
    $b = [Text.Encoding]::UTF8.GetBytes($msg); $sock.SendAsync((New-Object ArraySegment[byte] (, $b)), 'Text', $true, [Threading.CancellationToken]::None).Wait()
    while ($true) {
      $ms = New-Object IO.MemoryStream; $buf = New-Object byte[] 1048576
      do { $r = $sock.ReceiveAsync((New-Object ArraySegment[byte] (, $buf)), [Threading.CancellationToken]::None); $r.Wait(); $ms.Write($buf, 0, $r.Result.Count) } while (-not $r.Result.EndOfMessage)
      $txt = [Text.Encoding]::UTF8.GetString($ms.ToArray()); $o = $txt | ConvertFrom-Json
      if ($o.id -eq $script:id) { return $o }
    }
  }
  Send-Cdp "Page.navigate" @{ url = $Url } | Out-Null
  $sw = [Diagnostics.Stopwatch]::StartNew(); $title = ""
  while ($sw.Elapsed.TotalSeconds -lt $TimeoutSec) {
    Start-Sleep -Seconds 2
    $r = Send-Cdp "Runtime.evaluate" @{ expression = "document.title"; returnByValue = $true }
    $title = $r.result.result.value
    if ($title -eq 'DONE' -or $title -eq 'ERROR') { break }
  }
  Write-Output "title=$title after $([int]$sw.Elapsed.TotalSeconds) s"
  $r = Send-Cdp "Runtime.evaluate" @{ expression = $Expr; returnByValue = $true }
  [IO.File]::WriteAllText($OutFile, [string]$r.result.result.value, (New-Object Text.UTF8Encoding $false))
  Write-Output "wrote $OutFile"
} finally {
  try { Stop-Process -Id $proc.Id -Force -ErrorAction SilentlyContinue } catch {}
  Get-Process msedge -ErrorAction SilentlyContinue | Where-Object { $_.CommandLine -like "*icm_cdp_$Port*" } | Stop-Process -Force -ErrorAction SilentlyContinue
}
