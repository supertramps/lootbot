@echo off
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0Start-LootBot.ps1" -Mode Preview -AllLoot
pause
