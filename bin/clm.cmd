@echo off
setlocal
set "clm_host=%SystemRoot%\System32\WindowsPowerShell\v1.0\powershell.exe"
if defined ProgramFiles if exist "%ProgramFiles%\PowerShell\7\pwsh.exe" set "clm_host=%ProgramFiles%\PowerShell\7\pwsh.exe"
endlocal & "%clm_host%" -NoProfile -ExecutionPolicy Bypass -File "%~dp0claude-menu.ps1" %* & call exit /b %%errorlevel%%
