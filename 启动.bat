@echo off
cd /d "%~dp0"
set "SRV=%~dp0server"

if not exist "%SRV%\RichOnline.Server.exe" (
  echo [ERROR] server\RichOnline.Server.exe not found.
  pause
  exit /b 1
)

tasklist /fi "imagename eq RichOnline.Server.exe" 2>nul | find /i "RichOnline.Server.exe" >nul
if errorlevel 1 (
  echo Starting server ...
  start "RichOnline Server" /MIN /D "%SRV%" "%SRV%\RichOnline.Server.exe" --data-dir "%SRV%\data" --pipe richonline-local --client-profile richonline
  ping -n 6 127.0.0.1 >nul
) else (
  echo Server already running.
)

if not exist "%~dp0online-client\local.kpd" (
  echo [ERROR] online-client\local.kpd not found.
  pause
  exit /b 1
)

echo Starting client ...
start "" "%~dp0RnClient.exe" online-client\local.kpd 0
exit /b 0
