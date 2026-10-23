@echo off
chcp 65001 >nul
title Stock Copilot - Dung He Thong
echo ====================================================================
echo             STOCK COPILOT - DUNG VA DON DEP HE THONG               
echo ====================================================================
echo.

echo [1/2] Dang tat cac Container Docker...
docker compose down

echo.
echo [2/2] Dang dung AI Host Bridge va don dep cache agy...
powershell -NoProfile -ExecutionPolicy Bypass -Command "& {
    # 1. Tim va tat tien trinh lang nghe cong 9998
    $conns = Get-NetTCPConnection -LocalPort 9998 -ErrorAction SilentlyContinue
    if ($conns) {
        $pids = $conns | Select-Object -ExpandProperty OwningProcess -Unique
        foreach ($pidToKill in $pids) {
            Write-Host ('Dung tien trinh Bridge PID: ' + $pidToKill) -ForegroundColor Yellow
            Stop-Process -Id $pidToKill -Force -ErrorAction SilentlyContinue
        }
    }

    # 2. Don sach cache rac va tien trinh agy treo neu co
    $cacheDir = Join-Path $env:LOCALAPPDATA 'stock-copilot-cache'
    if (Test-Path $cacheDir) {
        Remove-Item -Path $cacheDir -Recurse -Force -ErrorAction SilentlyContinue
        Write-Host 'Da don dep thu muc cache tam cua agy.' -ForegroundColor Green
    }
}"

echo.
echo ====================================================================
echo  🛑 DA TAT VA DONG GOI DOCKER HOAN TOAN SACH SE!
echo  Khong con tien trinh ngam, khong bi tran RAM hay tran disk cache!
echo ====================================================================
pause