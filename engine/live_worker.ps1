# Live Market Worker for Stock Copilot
# Fetches real HOSE/HNX data from DNSE/Entrade API and stores to PostgreSQL (5434)
# Smart Anti-Spam: Detects Candlestick Patterns with Explicit Bullish (TĂNG) vs Bearish (GIẢM) Trend
# Auto Daily Close Report at 15:00 for multi-funds and stock performance
param (
    [int]$IntervalSeconds = 60,
    [switch]$SingleRun = $false,
    [switch]$ForceReport = $false
)

$token = "8862702138:AAHEUnRXYNdmeSqe7kUQ9n6VMXiI9B_H828"
$chatId = "6428436481"
$headers = @{"User-Agent" = "Mozilla/5.0 (Windows NT 10.0; Win64; x64)"}

Write-Host "==========================================================" -ForegroundColor Cyan
Write-Host "   STOCK COPILOT - SMART SCANNER & DAILY REPORT ENGINE    " -ForegroundColor Cyan
Write-Host "==========================================================" -ForegroundColor Cyan
Write-Host "Database: localhost:5434 (stock_copilot)" -ForegroundColor Gray
Write-Host "Signals: Bullish (TĂNG) & Bearish (GIẢM) | Max 1 alert/stock/day" -ForegroundColor Gray

# Memory cache to prevent duplicate alerts in same day
$alertedToday = @{}

function Send-TelegramMessage($text, $parseMode="HTML") {
    $body = @{
        chat_id = $chatId
        text = $text
        parse_mode = $parseMode
    } | ConvertTo-Json
    try {
        Invoke-RestMethod -Uri "https://api.telegram.org/bot$token/sendMessage" -Method Post -ContentType "application/json; charset=utf-8" -Body $body | Out-Null
    } catch {
        Write-Host "Lỗi gửi Telegram: $_" -ForegroundColor Red
    }
}

function Get-WatchlistFromDb {
    $raw = docker exec stock-copilot-postgres psql -U stock_user -d stock_copilot -t -A -F "|" -c "
        SELECT ticker, company_name, horizon, pivot_price, support_price, resistance_price, catalyst_notes, is_active 
        FROM watchlists;
    "
    $list = @()
    foreach ($line in ($raw -split "`n")) {
        $trimmed = $line.Trim()
        if (-not $trimmed) { continue }
        $parts = $trimmed -split "\|"
        if ($parts.Count -ge 8) {
            $list += [PSCustomObject]@{
                Ticker = $parts[0]
                CompanyName = $parts[1]
                Horizon = $parts[2]
                PivotPrice = [double]$parts[3]
                SupportPrice = [double]$parts[4]
                ResistancePrice = [double]$parts[5]
                Catalyst = $parts[6]
                IsStarred = ($parts[7].Trim() -eq 't' -or $parts[7].Trim() -eq 'true')
            }
        }
    }
    return $list
}

function Detect-CandlePattern($dayOpen, $dayHigh, $dayLow, $dayClose, $prevOpen, $prevClose, $volSurgeRatio) {
    $body = [Math]::Abs($dayClose - $dayOpen)
    $lowerShadow = [Math]::Min($dayOpen, $dayClose) - $dayLow
    $upperShadow = $dayHigh - [Math]::Max($dayOpen, $dayClose)
    $changePct = [Math]::Round((($dayClose - $prevClose) / $prevClose) * 100, 2)

    # --- 1. NHÓM TÍN HIỆU TĂNG GIÁ (BULLISH SIGNALS) ---
    # 1.1. Nến Búa Rút Chân (Bullish Hammer / Pin Bar)
    if ($lowerShadow -ge (2 * $body) -and $upperShadow -le (0.4 * $body) -and $dayClose -ge $dayOpen -and $volSurgeRatio -ge 1.2) {
        return @{
            Trend = "TĂNG GIÁ"
            Icon = "🟢"
            Header = "🟢 <b>TÍN HIỆU CỔ PHIẾU TĂNG GIÁ (BẮT ĐÁY / HỒI PHỤC)</b>"
            PatternName = "🔨 Nến Búa Rút Chân (Bullish Hammer)"
            Analysis = "Lực cầu bắt đáy nhập cuộc mạnh tại hỗ trợ, đẩy giá đóng cửa hồi phục sát đỉnh nến."
            Action = "Cơ hội gom mua thăm dò hoặc tích sản vùng giá tốt."
        }
    }

    # 1.2. Nến Nhấn Chìm Tăng (Bullish Engulfing)
    if ($prevClose -lt $prevOpen -and $dayClose -gt $dayOpen) {
        if ($dayOpen -le $prevClose -and $dayClose -ge $prevOpen -and $volSurgeRatio -ge 1.3) {
            return @{
                Trend = "TĂNG GIÁ"
                Icon = "🟢"
                Header = "🟢 <b>TÍN HIỆU CỔ PHIẾU TĂNG GIÁ (ĐẢO CHIỀU TĂNG)</b>"
                PatternName = "🔥 Nến Nhấn Chìm Tăng (Bullish Engulfing)"
                Analysis = "Phe mua áp đảo hoàn toàn nến đỏ phiên trước, xác nhận kết thúc nhịp điều chỉnh."
                Action = "Tín hiệu đảo chiều tăng rõ nét, thích hợp mở vị thế mua mới."
            }
        }
    }

    # 1.3. Nến Marubozu Bứt Phá Tăng Mạnh
    if ($changePct -ge 2.5 -and $upperShadow -le (0.2 * [Math]::Max($body, 1)) -and $volSurgeRatio -ge 1.5) {
        return @{
            Trend = "TĂNG GIÁ"
            Icon = "🚀"
            Header = "🚀 <b>TÍN HIỆU CỔ PHIẾU TĂNG GIÁ MẠNH (DÒNG TIỀN ĐỘT BIẾN)</b>"
            PatternName = "🚀 Nến Cường Lực Bứt Phá (Bullish Marubozu)"
            Analysis = "Dòng tiền lớn (Big Boys) giải ngân mạnh mẽ, bứt phá kháng cự với thanh khoản cao."
            Action = "Xu hướng tăng giá rất mạnh, có thể gia tăng tỷ trọng hoặc theo sóng dòng tiền."
        }
    }

    # --- 2. NHÓM TÍN HIỆU GIẢM GIÁ (BEARISH SIGNALS) ---
    # 2.1. Nến Bắn Sao / Người Treo Cổ (Shooting Star)
    if ($upperShadow -ge (2 * $body) -and $lowerShadow -le (0.4 * $body) -and $volSurgeRatio -ge 1.2) {
        return @{
            Trend = "GIẢM GIÁ"
            Icon = "🔴"
            Header = "🔴 <b>TÍN HIỆU CỔ PHIẾU GIẢM GIÁ (CẢNH BÁO RỦI RO / ĐỈNH)</b>"
            PatternName = "☄️ Nến Bắn Sao (Shooting Star / Phân phối đỉnh)"
            Analysis = "Bị lực bán xả hàng dội ngược mạnh từ vùng giá cao, phe mua hụt hơi."
            Action = "Cân nhắc chốt lời từng phần hoặc hạ tỷ trọng, tuyệt đối không mua đuổi."
        }
    }

    # 2.2. Nến Nhấn Chìm Giảm (Bearish Engulfing)
    if ($prevClose -gt $prevOpen -and $dayClose -lt $dayOpen) {
        if ($dayOpen -ge $prevClose -and $dayClose -le $prevOpen -and $volSurgeRatio -ge 1.3) {
            return @{
                Trend = "GIẢM GIÁ"
                Icon = "🔴"
                Header = "🔴 <b>TÍN HIỆU CỔ PHIẾU GIẢM GIÁ (ĐẢO CHIỀU GIẢM)</b>"
                PatternName = "⚠️ Nến Nhấn Chìm Giảm (Bearish Engulfing)"
                Analysis = "Phe bán kiểm soát hoàn toàn thế trận, bao trùm toàn bộ nến tăng phiên trước."
                Action = "Rủi ro gãy xu hướng tăng ngắn hạn, nên chủ động cơ cấu giảm rủi ro."
            }
        }
    }

    # 2.3. Nến Xả Hàng Marubozu Giảm Sâu Kèm Vol Lớn
    if ($changePct -le -2.5 -and $lowerShadow -le (0.2 * [Math]::Max($body, 1)) -and $volSurgeRatio -ge 1.5) {
        return @{
            Trend = "GIẢM GIÁ"
            Icon = "💥"
            Header = "💥 <b>TÍN HIỆU CỔ PHIẾU GIẢM GIÁ MẠNH (BỊ XẢ BÁN THÁO)</b>"
            PatternName = "💥 Nến Xả Hàng Marubozu Giảm Sâu"
            Analysis = "Áp lực bán tháo ồ ạt, giá rơi mạnh xuyên thủng các ngưỡng hỗ trợ gần."
            Action = "Khẩn cấp quản trị rủi ro, tuân thủ kỷ luật cắt lỗ nếu đang nắm giữ."
        }
    }

    return $null
}

function Process-Ticker($item) {
    $ticker = $item.Ticker
    $now = [DateTimeOffset]::UtcNow.ToUnixTimeSeconds()
    $pastDaily = $now - (40 * 86400)
    $pastIntraday = $now - (4 * 3600)

    # 1. Fetch Daily OHLCV
    $urlDaily = "https://services.entrade.com.vn/chart-api/v2/ohlcs/stock?from=$pastDaily&to=$now&symbol=$ticker&resolution=1D"
    try {
        $resDaily = Invoke-RestMethod -Uri $urlDaily -Headers $headers -TimeoutSec 10
    } catch {
        return
    }

    $cnt = $resDaily.c.Count
    if ($cnt -lt 5) { return }

    $recentVols = $resDaily.v[($cnt - 21)..($cnt - 2)]
    $ma20Vol = ($recentVols | Measure-Object -Average).Average
    $recentCloses = $resDaily.c[($cnt - 21)..($cnt - 2)]
    $ma20Price = (($recentCloses | Measure-Object -Average).Average) * 1000

    # 2. Fetch Live Intraday Candle
    $urlLive = "https://services.entrade.com.vn/chart-api/v2/ohlcs/stock?from=$pastIntraday&to=$now&symbol=$ticker&resolution=1"
    try {
        $resLive = Invoke-RestMethod -Uri $urlLive -Headers $headers -TimeoutSec 10
    } catch {
        return
    }

    $liveIdx = $resLive.t.Count - 1
    if ($liveIdx -lt 0) { return }

    $currentPrice = $resLive.c[$liveIdx] * 1000
    $dayOpen = $resDaily.o[$cnt - 1] * 1000
    $dayHigh = $resDaily.h[$cnt - 1] * 1000
    $dayLow = $resDaily.l[$cnt - 1] * 1000
    $dayClose = $currentPrice
    $prevOpen = $resDaily.o[$cnt - 2] * 1000
    $prevClose = $resDaily.c[$cnt - 2] * 1000

    $changePct = [Math]::Round((($currentPrice - $prevClose) / $prevClose) * 100, 2)
    $todayTotalVol = $resDaily.v[$cnt - 1]
    $volSurgeRatio = [Math]::Round(($todayTotalVol / [Math]::Max($ma20Vol, 1)), 2)
    $liveTime = [DateTimeOffset]::FromUnixTimeSeconds($resLive.t[$liveIdx]).ToLocalTime().ToString("HH:mm:ss")

    Write-Host ("[{0}] {1, -4} | Giá: {2, 8:N0} đ | +/-: {3, 5}% | Vol: {4, 9:N0} ({5:F1}x MA20)" -f `
        $liveTime, $ticker, $currentPrice, $changePct, $todayTotalVol, $volSurgeRatio) -ForegroundColor White

    # 3. Lưu Snapshot vào PostgreSQL (Port 5434)
    $insertSnapshotSql = "
        INSERT INTO market_snapshots (ticker, current_price, change_pct, volume, ma20_volume, vol_surge_ratio, ma20_price)
        VALUES ('$ticker', $currentPrice, $changePct, $todayTotalVol, $ma20Vol, $volSurgeRatio, $ma20Price);
    "
    docker exec stock-copilot-postgres psql -U stock_user -d stock_copilot -c "$insertSnapshotSql" | Out-Null

    # 4. Kiểm tra MẪU HÌNH NẾN (BULLISH vs BEARISH) - Tối đa 1 lần/ngày
    $pattern = Detect-CandlePattern $dayOpen $dayHigh $dayLow $dayClose $prevOpen $prevClose $volSurgeRatio
    $todayKey = (Get-Date).ToString("yyyyMMdd")
    $dedupKey = "${ticker}_${todayKey}"

    if ($pattern -and (-not $alertedToday.ContainsKey($dedupKey))) {
        $alertedToday[$dedupKey] = $true

        $header = $pattern.Header
        $pName = $pattern.PatternName
        $analysis = $pattern.Analysis
        $action = $pattern.Action
        $changeSign = if ($changePct -ge 0) { "+$changePct%" } else { "$changePct%" }

        $shortAlert = @"
$header
─────────────────────
• Mã cổ phiếu: <b>$ticker</b> - $($item.CompanyName)
• Thị giá sàn: <b>$($currentPrice.ToString('N0')) VND</b> (Biến động: <b>$changeSign</b>)
• Mẫu hình nến: <b>$pName</b>
• Thanh khoản: <b>$($volSurgeRatio)x MA20</b> ($($todayTotalVol.ToString('N0')) cp)
• Đánh giá kỹ thuật: $analysis
🎯 <b>Đề xuất hành động:</b> <i>$action</i>

💡 <i>Nhắn tin '<b>$ticker</b>' để xem tư vấn chuyên sâu & đối chiếu với vị thế tài sản của bạn.</i>
"@
        Send-TelegramMessage $shortAlert
        Write-Host "  -> Bắn cảnh báo $($pattern.Trend) cho $ticker (duy nhất 1 lần/ngày)." -ForegroundColor Green
    }
}

function Check-And-Send-DailyReport($force = $false) {
    $now = Get-Date
    $todayStr = $now.ToString("yyyy-MM-dd")
    $isWeekday = ($now.DayOfWeek -ne [DayOfWeek]::Saturday -and $now.DayOfWeek -ne [DayOfWeek]::Sunday)

    if (-not $force) {
        if (-not $isWeekday) { return }
        if ($now.Hour -lt 15) { return }
    }

    $chkRaw = docker exec stock-copilot-postgres psql -U stock_user -d stock_copilot -t -A -c "
        SELECT 1 FROM daily_reports_log WHERE report_date = '$todayStr';
    "
    $chk = if ($chkRaw) { $chkRaw.Trim() } else { "" }

    if ($chk -eq "1" -and -not $force) {
        return
    }

    Write-Host "--- TIẾN HÀNH TẠO BÁO CÁO TỔNG KẾT CHỐT PHIÊN ($todayStr) ---" -ForegroundColor Yellow

    $raw = docker exec stock-copilot-postgres psql -U stock_user -d stock_copilot -t -A -F "|" -c "
        SELECT fund_name, ticker, company_name, current_qty, avg_buy_price, total_invested 
        FROM v_portfolio_holdings ORDER BY fund_name, ticker;
    "
    $lines = ($raw -split "`n") | Where-Object { $_.Trim() -ne "" }
    if ($lines.Count -eq 0) { return }

    $fundReports = @{}
    $grandValuation = 0
    $grandCost = 0

    foreach ($line in $lines) {
        $p = $line -split "\|"
        $fName = $p[0]
        $tk = $p[1]
        $cName = $p[2]
        $qty = [int]$p[3]
        $avgCost = [double]$p[4]
        $cost = [double]$p[5]

        $nowSec = [DateTimeOffset]::UtcNow.ToUnixTimeSeconds()
        $pastDailySec = $nowSec - (10 * 86400)
        $urlD = "https://services.entrade.com.vn/chart-api/v2/ohlcs/stock?from=$pastDailySec&to=$nowSec&symbol=$tk&resolution=1D"
        $curPrice = $avgCost
        $dayChangeStr = "0.0%"
        try {
            $rd = Invoke-RestMethod -Uri $urlD -Headers $headers -TimeoutSec 8
            $cCount = $rd.c.Count
            if ($cCount -ge 2) {
                $curPrice = $rd.c[$cCount - 1] * 1000
                $prevC = $rd.c[$cCount - 2] * 1000
                $pct = [Math]::Round((($curPrice - $prevC) / $prevC) * 100, 2)
                $dayChangeStr = if ($pct -ge 0) { "+$pct%" } else { "$pct%" }
            }
        } catch {}

        $curVal = $qty * $curPrice
        $pnl = $curVal - $cost
        $pnlPct = if ($cost -gt 0) { [Math]::Round(($pnl / $cost) * 100, 2) } else { 0 }
        $stIcon = if ($pnl -ge 0) { "🟢 +" } else { "🔴 " }

        $grandValuation += $curVal
        $grandCost += $cost

        if (-not $fundReports.ContainsKey($fName)) {
            $fundReports[$fName] = @{
                Valuation = 0
                Cost = 0
                Items = @()
            }
        }
        $fundReports[$fName].Valuation += $curVal
        $fundReports[$fName].Cost += $cost
        $fundReports[$fName].Items += "• <b>$tk</b> ($qty cp): Giá chốt <b>$($curPrice.ToString('N0')) đ</b> ($dayChangeStr)`n  ➔ Giá vốn: $($avgCost.ToString('N0')) đ | Lời/Lỗ: <b>$stIcon$($pnl.ToString('N0')) đ ($pnlPct%)</b>"
    }

    $grandPnl = $grandValuation - $grandCost
    $grandPnlPct = if ($grandCost -gt 0) { [Math]::Round(($grandPnl / $grandCost) * 100, 2) } else { 0 }
    $grandIcon = if ($grandPnl -ge 0) { "🟢 +" } else { "🔴 " }

    $fundsText = ""
    foreach ($fKey in $fundReports.Keys) {
        $fData = $fundReports[$fKey]
        $fPnl = $fData.Valuation - $fData.Cost
        $fPnlPct = if ($fData.Cost -gt 0) { [Math]::Round(($fPnl / $fData.Cost) * 100, 2) } else { 0 }
        $fIcon = if ($fPnl -ge 0) { "🟢 +" } else { "🔴 " }

        $itemsText = $fData.Items -join "`n"
        $fundsText += @"
📂 <b>QUỸ $($fKey.ToUpper()):</b>
• Tổng giá trị: <b>$($fData.Valuation.ToString('N0')) VND</b> | Lời/Lỗ: <b>$fIcon$($fPnl.ToString('N0')) đ ($fPnlPct%)</b>
$itemsText

"@
    }

    $reportMsg = @"
🔔 <b>BÁO CÁO TỔNG KẾT TÀI SẢN CHỐT PHIÊN ($todayStr)</b>
─────────────────────
💰 <b>TỔNG TÀI SẢN:</b> <b>$($grandValuation.ToString('N0')) VND</b>
💵 <b>Tổng vốn đầu tư:</b> $($grandCost.ToString('N0')) VND
📈 <b>Tổng Lời / Lỗ:</b> $grandIcon$($grandPnl.ToString('N0')) VND (<b>$grandPnlPct%</b>)

$fundsText─────────────────────
💡 <i>Thị trường đã kết thúc phiên ATC. Chúc bạn một buổi tối vui vẻ! Ngày mai sàn mở cửa lúc 09:00.</i>
"@

    Send-TelegramMessage $reportMsg
    Write-Host "-> Đã gửi Báo cáo Tổng kết chốt phiên về Telegram thành công!" -ForegroundColor Green

    docker exec stock-copilot-postgres psql -U stock_user -d stock_copilot -c "
        INSERT INTO daily_reports_log (report_date) VALUES ('$todayStr') ON CONFLICT (report_date) DO NOTHING;
    " | Out-Null
}

if ($ForceReport) {
    Check-And-Send-DailyReport $true
    exit
}

do {
    Write-Host "`n--- BẮT ĐẦU VÒNG QUÉT DỮ LIỆU THẬT ($([DateTime]::Now.ToString('HH:mm:ss'))) ---" -ForegroundColor Yellow
    $watchlist = Get-WatchlistFromDb
    foreach ($item in $watchlist) {
        Process-Ticker $item
        Start-Sleep -Milliseconds 250
    }

    Check-And-Send-DailyReport $false

    if ($SingleRun) { break }
    Write-Host "Chờ $IntervalSeconds giây cho lượt quét tiếp theo..." -ForegroundColor DarkGray
    Start-Sleep -Seconds $IntervalSeconds
} while ($true)