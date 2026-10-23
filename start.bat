@echo off
chcp 65001 >nul
title Stock Copilot - Khoi Dong He Thong
echo ====================================================================
echo          STOCK COPILOT - HE THONG DAU TU CHUNG KHOAN AI            
echo ====================================================================
echo.

echo [1/3] Kiem tra va khoi chay AI Host Bridge (Cache-Guard)...
powershell -NoProfile -ExecutionPolicy Bypass -Command "& {
    $port = 9998
    $active = Get-NetTCPConnection -LocalPort $port -State Listen -ErrorAction SilentlyContinue
    if (-not $active) {
        Write-Host 'Khoi dong tien trinh AI Host Bridge tren cong 9998...' -ForegroundColor Cyan
        Start-Process powershell -ArgumentList '-NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File \"\"%~dp0engine\stock_ai_bridge.ps1\"\"'
        Start-Sleep -Seconds 2
    } else {
        Write-Host 'AI Host Bridge da san sang tren cong 9998.' -ForegroundColor Green
    }
}"

echo.
echo [2/3] Khoi dong cac Container Docker (Database + Bot + Scanner)...
docker compose up -d

echo.
echo ====================================================================
echo  🚀 STOCK COPILOT DONG GOI DOCKER DA SAN SANG!
echo ====================================================================
echo  • PostgreSQL Database  : stock-copilot-postgres (Cong 5434)
echo  • App (Bot & Scanner)  : stock-copilot-app (Docker)
echo  • Nao bo AI Bridge     : Port 9998 (Bao ve chong tran cache agy)
echo.
echo  Anh co the mo Telegram va chat truc tiep voi Bot ngay bay gio!
echo ====================================================================
pause