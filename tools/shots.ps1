# Screenshots of the menu and play screens at 4 viewports + a JS error log. Output: tools\_check\shot-<WxH>-<screen>.png
# Usage: powershell -ExecutionPolicy Bypass -File tools\shots.ps1
param([int]$Port = 9351)
$root = Split-Path $PSScriptRoot -Parent
$url = ([Uri](Join-Path $root 'index.html')).AbsoluteUri
$outDir = Join-Path $PSScriptRoot '_check'; New-Item -ItemType Directory -Force $outDir | Out-Null
$edge = "C:\Program Files (x86)\Microsoft\Edge\Application\msedge.exe"; if (-not (Test-Path $edge)) { $edge = "C:\Program Files\Microsoft\Edge\Application\msedge.exe" }
$ud = Join-Path $env:TEMP ("icm_shots_" + $Port)
$proc = Start-Process -FilePath $edge -ArgumentList @("--headless=new", "--disable-gpu", "--no-first-run", "--user-data-dir=$ud", "--allow-file-access-from-files", "--autoplay-policy=no-user-gesture-required", "--remote-debugging-port=$Port", "about:blank") -PassThru
try {
  $ws = $null
  for ($i = 0; $i -lt 60 -and -not $ws; $i++) { Start-Sleep -Milliseconds 500; try { $t = Invoke-RestMethod "http://127.0.0.1:$Port/json" -TimeoutSec 2; $pg = $t | Where-Object { $_.type -eq 'page' } | Select-Object -First 1; if ($pg) { $ws = $pg.webSocketDebuggerUrl } } catch {} }
  if (-not $ws) { throw "no CDP endpoint" }
  $sock = New-Object System.Net.WebSockets.ClientWebSocket; $sock.Options.SetBuffer(65536, 65536); $sock.ConnectAsync([Uri]$ws, [Threading.CancellationToken]::None).Wait()
  $script:id = 0
  function Send-Cdp($method, $params) {
    $script:id++; $msg = @{ id = $script:id; method = $method; params = $params } | ConvertTo-Json -Depth 8 -Compress
    $b = [Text.Encoding]::UTF8.GetBytes($msg); $sock.SendAsync((New-Object ArraySegment[byte] (, $b)), 'Text', $true, [Threading.CancellationToken]::None).Wait()
    while ($true) {
      $ms = New-Object IO.MemoryStream; $buf = New-Object byte[] 1048576
      do { $r = $sock.ReceiveAsync((New-Object ArraySegment[byte] (, $buf)), [Threading.CancellationToken]::None); $r.Wait(); $ms.Write($buf, 0, $r.Result.Count) } while (-not $r.Result.EndOfMessage)
      $o = [Text.Encoding]::UTF8.GetString($ms.ToArray()) | ConvertFrom-Json
      if ($o.id -eq $script:id) { return $o }
    }
  }
  Send-Cdp "Page.enable" @{} | Out-Null
  Send-Cdp "Page.addScriptToEvaluateOnNewDocument" @{ source = "window.__errs=[];addEventListener('error',e=>__errs.push(String(e.message)+' @'+e.lineno));addEventListener('unhandledrejection',e=>__errs.push('rej '+String(e.reason)));" } | Out-Null
  $log = @()
  foreach ($vp in @(@(360, 740), @(390, 844), @(1024, 768), @(1440, 900))) {
    $w = $vp[0]; $h = $vp[1]
    Send-Cdp "Emulation.setDeviceMetricsOverride" @{ width = $w; height = $h; deviceScaleFactor = 1; mobile = ($w -lt 800) } | Out-Null
    Send-Cdp "Page.navigate" @{ url = $url } | Out-Null; Start-Sleep -Seconds 2
    Send-Cdp "Runtime.evaluate" @{ expression = "Storage.set('activeProfile','guest');UI.closeSheet();UI.renderMenu();0" } | Out-Null; Start-Sleep -Milliseconds 700
    foreach ($step in @(@('menu', '0'), @('play', "Game.start({mode:'watch',from:62});0"), @('results', "(function(){var m=VocalMap.m,U=TestKit.U(m,TestKit.refFn(m,true));var R=TestKit.sim(m,'gentle',U);R.mode='sing';R.dk='gentle';R.ranked=true;R.rankNote='';R.spotCount=0;R.p2=[0,0];R.watchdog=0;R.autoSyncMs=0;R.playbackMode='video';R.U=U;R.map=m;R.latencyMs=0;Game.active=false;Results.show(R);return 0})()"))) {
      if ($step[0] -eq 'results' -and -not $true) { continue }
      Send-Cdp "Runtime.evaluate" @{ expression = $step[1] } | Out-Null
      $wait = if ($step[0] -eq 'play') { 9000 } else { 900 }; Start-Sleep -Milliseconds $wait
      $png = Send-Cdp "Page.captureScreenshot" @{ format = 'png' }
      [IO.File]::WriteAllBytes((Join-Path $outDir "shot-${w}x${h}-$($step[0]).png"), [Convert]::FromBase64String($png.result.data))
      if ($step[0] -eq 'play') {
        $m = Send-Cdp "Runtime.evaluate" @{ expression = "(function(){var v=document.querySelector('#videoWrap').getBoundingClientRect(),l=document.querySelector('#laneWrap').getBoundingClientRect(),c=document.querySelector('#ctrl').getBoundingClientRect();return JSON.stringify({video:[v.top|0,v.bottom|0],lane:[l.top|0,l.bottom|0],ctrl:[c.top|0,c.bottom|0],scrollH:document.documentElement.scrollHeight,innerH:innerHeight})})()"; returnByValue = $true }
        $log += "$w x $h layout: $($m.result.result.value)"
      }
      Send-Cdp "Runtime.evaluate" @{ expression = "Game.active=false;cancelAnimationFrame(Game.raf);Playback.stop();UI.show('menu');0" } | Out-Null
    }
    $e = Send-Cdp "Runtime.evaluate" @{ expression = "JSON.stringify(window.__errs)"; returnByValue = $true }
    $log += "$w x $h errors: $($e.result.result.value)"
  }
  $log | Set-Content (Join-Path $outDir 'shots.log') -Encoding utf8; $log
} finally { try { Stop-Process -Id $proc.Id -Force -ErrorAction SilentlyContinue } catch {} }
