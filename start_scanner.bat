@echo off
title Stock Copilot - Realtime Market Scanner
echo ========================================================
echo    STOCK COPILOT - KICH HOAT QUET DU LIEU THAT (HOSE)
echo ========================================================
powershell -ExecutionPolicy Bypass -File "%~dp0engine\live_worker.ps1" -IntervalSeconds 60
pause
