@echo off
REM Run all tests - Windows batch wrapper
REM Usage: run-tests.bat [options]

powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0run-all-tests.ps1" %*
