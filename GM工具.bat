@echo off
chcp 65001 >nul
cd /d "%~dp0"
powershell -STA -NoProfile -ExecutionPolicy Bypass -File "%~dp0tools\gm-tool.ps1"
if errorlevel 1 pause
