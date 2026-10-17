@echo off
setlocal
rem Copies the launcher with the cheat switches and the cheats folder onto a KytyPS5 release.
rem Nothing is compiled. Pass the emulator folder to skip the dialog:  install.cmd G:\KytyPS5-v20261014
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0install.ps1" %*
echo.
pause
