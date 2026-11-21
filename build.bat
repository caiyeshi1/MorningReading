@echo off
rem 一键编译（绕过 PowerShell 执行策略限制）
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0build.ps1" %*
pause
