@echo off
setlocal
rem Compiles the DualSense haptics into a KytyPS5 release (the source is downloaded, patched and
rem built; the object files are kept, so the next version only rebuilds what changed).
rem Pass the emulator folder and its version to skip the guessing:
rem   rebuild.cmd G:\KytyPS5-v20261014 v20261014
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0rebuild.ps1" %*
echo.
pause
