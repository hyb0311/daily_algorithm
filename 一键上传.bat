@echo off
rem ASCII-only on purpose: cmd's codepage mangles UTF-8 Chinese in .bat files.
rem All Chinese output comes from push.ps1, which is UTF-8 BOM and renders fine.
cd /d "%~dp0"
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0push.ps1" %*
echo.
pause
