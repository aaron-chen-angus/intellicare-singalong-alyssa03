@echo off
rem Double-click: starts a local web server for this folder and opens the app in Microsoft Edge.
rem Keep this black window open while you use the app. Close it to stop.
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0tools\serve.ps1" -Port 8080
pause
