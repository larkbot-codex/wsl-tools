@echo off
setlocal
set "PSModulePath=%ProgramFiles%\WindowsPowerShell\Modules;%WINDIR%\System32\WindowsPowerShell\v1.0\Modules"
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0bootstrap.ps1" %*
exit /b %ERRORLEVEL%
