@echo off
setlocal
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0claude-menu.ps1" %*
