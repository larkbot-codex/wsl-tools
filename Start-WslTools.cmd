@echo off
setlocal
rem Isolate bootstrap from user-installed PowerShell modules on an unknown host.
set "PSModulePath=%ProgramFiles%\WindowsPowerShell\Modules;%WINDIR%\System32\WindowsPowerShell\v1.0\Modules"
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0bootstrap.ps1" %*
exit /b %ERRORLEVEL%
