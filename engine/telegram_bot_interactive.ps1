. "C:\Users\hieu.pt\IdeaProjects\stock-copilot\engine\agy_chat.ps1"
. "C:\Users\hieu.pt\IdeaProjects\stock-copilot\engine\deep_analysis.ps1"
[System.Net.ServicePointManager]::SecurityProtocol = [System.Net.SecurityProtocolType]::Tls12 -bor [System.Net.SecurityProtocolType]::Tls13
# Interactive Telegram Copilot: Smart NLP, Dynamic Watchlist Management & Multi-Fund Portfolio

$token = "8862702138:AAHEUnRXYNdmeSqe7kUQ9n6VMXiI9B_H828"
$headers = @{"User-Agent" = "Mozilla/5.0 (Windows NT 10.0; Win64; x64)"}

Write-Host "==========================================================" -ForegroundColor Cyan
Write-Host "   STOCK COPILOT - WATCHLIST & PORTFOLIO ENGINE RUNNING   " -ForegroundColor Cyan
Write-Host "==========================================================" -ForegroundColor Cyan
Write-Host "Listening for user messages on Telegram..." -ForegroundColor Green

$quickKeyboard = @{
    keyboard = @(
        @( @{ text = "📊 Tổng danh mục" }, @{ text = "📑 Sổ lệnh chờ" } ),
        @( @{ text = "👤 Quỹ Cá nhân" }, @{ text = "👥 Quỹ Chung" } ),
        @( @{ text = "⭐ Danh sách theo dõi" }, @{ text = "❓ Hướng dẫn" } )
    )
    resize_keyboard = $true
    is_persistent = $true
}

function Send-Reply($chatId, $text) {
    $body = @{
        chat_id = $chatId
        text = $text
        parse_mode = "HTML"
        reply_markup = $quickKeyboard
    } | ConvertTo-Json -Depth 5
    try {
        Invoke-RestMethod -Uri "https://api.telegram.org/bot$token/sendMessage" -Method Post -ContentType "application/json; charset=utf-8" -Body $body | Out-Null
    } catch {
        Write-Host "Lỗi gửi phản hồi: $_" -ForegroundColor Red
    }
}

function Get-LivePrice($ticker) {
    $now = [DateTimeOffset]::UtcNow.ToUnixTimeSeconds()
    $past = $now - (4 * 3600)
    $url = "https://services.entrade.com.vn/chart-api/v2/ohlcs/stock?from=$past&to=$now&symbol=$ticker&resolution=1"
    try {
        $res = Invoke-RestMethod -Uri $url -Headers $headers -TimeoutSec 5
        $idx = $res.t.Count - 1
        if ($idx -ge 0) {
            return ($res.c[$idx] * 1000)
        }
    } catch {}
    return 0
}

function Get-Ticker-Metadata($ticker) {
    $sec = "Khác"
    $name = "$ticker Corp"
    if ($ticker -in @("VCB", "TCB", "MBB", "CTG", "BID", "ACB", "VPB", "STB", "HDB", "SHB", "TPB", "LPB", "MSB", "VIB")) {
        $sec = "Ngân hàng"
        if ($ticker -eq "MBB") { $name = "NHTMCP Quân Đội" }
        elseif ($ticker -eq "VCB") { $name = "Vietcombank" }
        elseif ($ticker -eq "CTG") { $name = "VietinBank" }
        elseif ($ticker -eq "TCB") { $name = "Techcombank" }
    }
    elseif ($ticker -in @("FPT", "CMG", "ELC", "ITD")) { $sec = "Công nghệ"; if ($ticker -eq "FPT") { $name = "CTCP FPT" } }
    elseif ($ticker -in @("HPG", "HSG", "NKG", "TLH", "VGS")) { $sec = "Thép & VLXD"; if ($ticker -eq "HPG") { $name = "Tập đoàn Hòa Phát" } }
    elseif ($ticker -in @("MWG", "FRT", "DGW", "PNJ", "MSN")) { $sec = "Bán lẻ"; if ($ticker -eq "MWG") { $name = "Thế Giới Di Động" } }
    elseif ($ticker -in @("PVD", "PVS", "GAS", "BSR", "PLX", "PVT")) { $sec = "Dầu khí" }
    elseif ($ticker -in @("SSI", "VND", "VCI", "HCM", "SHS", "MBS", "FTS", "BSI")) { $sec = "Chứng khoán" }
    elseif ($ticker -in @("POW", "REE", "GEG", "PC1", "HDG")) { $sec = "Điện & Năng lượng" }
    elseif ($ticker -in @("DGC", "DPM", "DCM", "BFC", "CSV")) { $sec = "Hóa chất & Phân bón" }
    elseif ($ticker -in @("VHM", "VIC", "VRE", "KDH", "NLG", "PDR", "DIG", "DXG", "NVL")) { $sec = "Bất động sản" }

    return @{ Sector = $sec; CompanyName = $name }
}

$stopWords = @("MUA", "BAN", "VUA", "MOI", "DAT", "CHO", "CON", "DAN", "QUY", "GIA", "KHI", "CUA", "HOM", "NAY", "ROI", "NHE", "XEM", "HOI", "CON", "COI", "BAI", "BOT", "TUI", "BAC", "LOH", "CAI", "THE", "VAO", "SUA", "LA", "RAI", "KHOI", "RA", "KHO")

# --- 1. QUẢN LÝ DANH SÁCH THEO DÕI (WATCHLIST ENGINE) ---
function Handle-AddWatchlist($chatId, $ticker) {
    $meta = Get-Ticker-Metadata $ticker
    $sector = $meta.Sector
    $name = $meta.CompanyName
    $livePrice = Get-LivePrice $ticker
    $pivotPrice = if ($livePrice -gt 0) { [Math]::Round($livePrice * 1.03, -2) } else { 0 }

    docker exec stock-copilot-postgres psql -U stock_user -d stock_copilot -c "
        INSERT INTO watchlists (ticker, company_name, sector, pivot_price, is_active)
        VALUES ('$ticker', '$name', '$sector', $pivotPrice, TRUE)
        ON CONFLICT (ticker) DO UPDATE SET is_active = TRUE, sector = '$sector';
    " | Out-Null

    $priceStr = if ($livePrice -gt 0) { $livePrice.ToString('N0') + " VND" } else { "Đang cập nhật" }
    $pivotStr = if ($pivotPrice -gt 0) { $pivotPrice.ToString('N0') + " VND" } else { "Tự động tính" }

    $reply = @"
✅ <b>ĐÃ THÊM $ticker VÀO DANH SÁCH THEO DÕI!</b>
─────────────────────
• Mã: <b>$ticker</b> ($name - Ngành: <b>$sector</b>)
• Thị giá sàn HOSE hiện tại: <b>$priceStr</b>
• Ngưỡng Pivot kích hoạt sóng: <b>$pivotStr</b>

📡 <i>Hệ thống đã đưa $ticker vào radar quét nổ khối lượng và bứt phá cản tự động!</i>
"@
    Send-Reply $chatId $reply
}

function Handle-RemoveWatchlist($chatId, $ticker) {
    docker exec stock-copilot-postgres psql -U stock_user -d stock_copilot -c "
        UPDATE watchlists SET is_active = FALSE WHERE ticker = '$ticker';
    " | Out-Null

    $reply = @"
🗑️ <b>ĐÃ LOẠI BỎ $ticker KHỎI DANH SÁCH THEO DÕI!</b>
─────────────────────
• Mã <b>$ticker</b> đã được gỡ khỏi radar quét tín hiệu realtime.
• <i>(Các giao dịch mua/bán của $ticker trong danh mục tài sản vẫn được giữ nguyên đầy đủ).</i>
"@
    Send-Reply $chatId $reply
}

function Handle-RefreshWatchlist($chatId) {
    $raw = docker exec stock-copilot-postgres psql -U stock_user -d stock_copilot -t -A -F "|" -c "
        SELECT ticker, company_name, sector, pivot_price FROM watchlists WHERE is_active = TRUE ORDER BY sector, ticker;
    "
    $lines = ($raw -split "`n") | Where-Object { $_.Trim() -ne "" }
    if ($lines.Count -eq 0) {
        Send-Reply $chatId "⭐ Danh sách theo dõi hiện đang trống. Nhắn: <i>'thêm MBB vào danh sách theo dõi'</i> để thêm mới."
        return
    }

    $outText = ""
    foreach ($line in $lines) {
        $p = $line -split "\|"
        $t = $p[0]
        $cName = $p[1]
        $sec = $p[2]
        $piv = [double]$p[3]
        $cur = Get-LivePrice $t
        $curStr = if ($cur -gt 0) { $cur.ToString('N0') + " đ" } else { "Đang đóng cửa" }

        $outText += @"
• <b>$t</b> ($sec - $cName)
  Thị giá HOSE: <b>$curStr</b> | Pivot kích hoạt: $($piv.ToString('N0')) đ

"@
    }

    $reply = @"
🔄 <b>ĐÃ LÀM MỚI DANH SÁCH THEO DÕI (WATCHLIST)!</b>
─────────────────────
$outText
💡 <b>CÁC THAO TÁC THEO DÕI NHANH:</b>
• <i>'thêm DGC'</i> ➔ Thêm mã mới vào radar
• <i>'loại bỏ MWG khỏi danh sách theo dõi'</i> ➔ Gỡ mã ra
• Gõ thẳng tên mã (vd: <b>FPT</b>, <b>MBB</b>) để nhận phân tích chi tiết!
"@
    Send-Reply $chatId $reply
}

function Handle-WatchlistReport($chatId) {
    Handle-RefreshWatchlist $chatId
}

# --- 2. BỘ PHÂN TÍCH GIAO DỊCH NLP & SỬA NHẦM ---
function Parse-Stock-Intent($t) {
    $isBuy = $t -match "(mua|múc|gom|vào|đang có|có|đã mua|vừa mua|mới mua|buy)"
    $isSell = $t -match "(bán|sút|chốt|hạ|thoát|xả|đã bán|vừa bán|mới bán|sell)"
    $action = if ($isBuy) { "BUY" } elseif ($isSell) { "SELL" } else { $null }

    $isPending = $t -match "(đặt|treo|kê|chờ)"
    $fund = if ($t -match "(tiền chung|quỹ chung|sở hữu chung|chung)") { "Tiền chung" } else { "Cá nhân" }

    $cleanText = ($t -replace "[.,:;!?'`"]", " ")
    $words = $cleanText -split "\s+"
    $ticker = $null
    foreach ($w in $words) {
        $u = $w.Trim().ToUpper()
        if ($u.Length -eq 3 -and $u -notin $stopWords -and $u -match "^[A-Z]{3}$") {
            $ticker = $u
            break
        }
    }

    $qty = 0
    if ($t -match "(\d+)\s*(cp|cổ|cổ phiếu|con|lô)\b") {
        $qty = [int]$Matches[1]
    } elseif ($t -match "(mua|múc|bán|sút|chốt|có)\s+(\d+)\b") {
        $qty = [int]$Matches[2]
    }

    $price = 0
    if ($t -match "(giá|khi|ở|\@)\s*([0-9]+[.,]?[0-9]*)\s*k?\b") {
        $raw = $Matches[2]
        $val = [double]($raw -replace ",", ".")
        $price = if ($val -lt 1000) { $val * 1000 } else { $val }
    } elseif ($t -match "\b([0-9]+[.,]?[0-9]*)\s*k\b") {
        $raw = $Matches[1]
        $val = [double]($raw -replace ",", ".")
        $price = $val * 1000
    } elseif ($t -match "\b([0-9]{2,3}[.,][0-9]+)\b") {
        $raw = $Matches[1]
        $val = [double]($raw -replace ",", ".")
        $price = if ($val -lt 1000) { $val * 1000 } else { $val }
    }

    return [PSCustomObject]@{
        Action = $action
        IsPending = $isPending
        Ticker = $ticker
        Qty = $qty
        Price = $price
        Fund = $fund
    }
}

function Handle-Correction($chatId, $text) {
    if ($text -match "(xóa|xoá|hủy bỏ|xóa đi|undo|xóa lệnh|xóa gd)") {
        $lastRow = docker exec stock-copilot-postgres psql -U stock_user -d stock_copilot -t -A -F "|" -c "
            SELECT id, fund_name, ticker, quantity, price FROM portfolio_transactions ORDER BY id DESC LIMIT 1;
        "
        if (-not $lastRow.Trim()) {
            Send-Reply $chatId "⚠️ Hiện không có giao dịch nào để xóa."
            return $true
        }
        $p = $lastRow.Trim() -split "\|"
        $delId = $p[0]
        $delFund = $p[1]
        $delTicker = $p[2]
        $delQty = $p[3]
        $delPrice = [double]$p[4]

        docker exec stock-copilot-postgres psql -U stock_user -d stock_copilot -c "
            DELETE FROM portfolio_transactions WHERE id = $delId;
        " | Out-Null

        Send-Reply $chatId "🗑️ <b>ĐÃ XÓA GIAO DỊCH GẦN NHẤT THÀNH CÔNG!</b>`n• Đã xóa: <b>$delQty cp $delTicker</b> @ $($delPrice.ToString('N0')) đ ($delFund)`n• Danh mục tài sản đã được hoàn tác."
        return $true
    }

    $intent = Parse-Stock-Intent $text
    if ($intent.Action -and $intent.Ticker -and $intent.Qty -gt 0 -and $intent.Price -gt 0) {
        $targetIdRaw = docker exec stock-copilot-postgres psql -U stock_user -d stock_copilot -t -A -c "
            SELECT id FROM portfolio_transactions WHERE ticker = '$($intent.Ticker)' ORDER BY id DESC LIMIT 1;
        "
        $targetId = if ($targetIdRaw.Trim()) { $targetIdRaw.Trim() } else {
            (docker exec stock-copilot-postgres psql -U stock_user -d stock_copilot -t -A -c "SELECT id FROM portfolio_transactions ORDER BY id DESC LIMIT 1;").Trim()
        }

        if ($targetId) {
            docker exec stock-copilot-postgres psql -U stock_user -d stock_copilot -c "
                UPDATE portfolio_transactions 
                SET ticker = '$($intent.Ticker)', quantity = $($intent.Qty), price = $($intent.Price), fund_name = '$($intent.Fund)'
                WHERE id = $targetId;
            " | Out-Null
            
            Send-Reply $chatId "✏️ <b>ĐÃ ĐIỀU CHỈNH GIAO DỊCH THÀNH CÔNG!</b>`n• Đã sửa thành: <b>$($intent.Qty) cp $($intent.Ticker)</b> @ $($intent.Price.ToString('N0')) đ`n• Quỹ: <b>$($intent.Fund)</b>`n• Danh mục đã tự động cập nhật lại giá vốn."
            return $true
        }
    }

    if ($text -match "(sửa giá|nhầm giá|sửa lại giá|đổi giá|thành giá|giá là)\s*([0-9]+[.,]?[0-9]*)\s*k?\b" -or $text -match "(sửa|chỉnh)\s+giá\s+([A-Za-z]{3})?\s*(thành|là)?\s*([0-9]+[.,]?[0-9]*)\s*k?\b") {
        $rawP = if ($Matches[4]) { $Matches[4] } elseif ($Matches[2]) { $Matches[2] } else { $Matches[1] }
        $valP = [double]($rawP -replace "k", "" -replace ",", ".")
        $newPrice = if ($valP -lt 1000) { $valP * 1000 } else { $valP }

        $tickerClause = ""
        if ($text -match "\b([A-Za-z]{3})\b") {
            $tCode = $Matches[1].ToUpper()
            if ($tCode -notin $stopWords) { $tickerClause = "WHERE ticker = '$tCode'" }
        }

        $targetId = (docker exec stock-copilot-postgres psql -U stock_user -d stock_copilot -t -A -c "
            SELECT id FROM portfolio_transactions $tickerClause ORDER BY id DESC LIMIT 1;
        ").Trim()

        if ($targetId) {
            docker exec stock-copilot-postgres psql -U stock_user -d stock_copilot -c "
                UPDATE portfolio_transactions SET price = $newPrice WHERE id = $targetId;
            " | Out-Null
            
            $info = (docker exec stock-copilot-postgres psql -U stock_user -d stock_copilot -t -A -F "|" -c "
                SELECT ticker, quantity, fund_name FROM portfolio_transactions WHERE id = $targetId;
            ").Trim() -split "\|"

            Send-Reply $chatId "✏️ <b>ĐÃ ĐIỀU CHỈNH MỨC GIÁ THÀNH CÔNG!</b>`n• Mã: <b>$($info[0])</b> ($($info[2]))`n• Mức giá mới: <b>$($newPrice.ToString('N0')) VND</b> (Số lượng: $($info[1]) cp)`n• Giá vốn bình quân đã được cập nhật lại chuẩn xác."
            return $true
        }
    }

    if ($text -match "(sửa số lượng|sửa sl|nhầm số lượng|sửa lại|đổi thành)\s*(\d+)\s*(cp|cổ|cổ phiếu|con)?\b" -or $text -match "(sửa|chỉnh)\s+([A-Za-z]{3})?\s*(thành)?\s*(\d+)\s*(cp|cổ|con)\b") {
        $newQty = [int](if ($Matches[4]) { $Matches[4] } elseif ($Matches[2]) { $Matches[2] } else { $Matches[1] })

        $tickerClause = ""
        if ($text -match "\b([A-Za-z]{3})\b") {
            $tCode = $Matches[1].ToUpper()
            if ($tCode -notin $stopWords) { $tickerClause = "WHERE ticker = '$tCode'" }
        }

        $targetId = (docker exec stock-copilot-postgres psql -U stock_user -d stock_copilot -t -A -c "
            SELECT id FROM portfolio_transactions $tickerClause ORDER BY id DESC LIMIT 1;
        ").Trim()

        if ($targetId) {
            docker exec stock-copilot-postgres psql -U stock_user -d stock_copilot -c "
                UPDATE portfolio_transactions SET quantity = $newQty WHERE id = $targetId;
            " | Out-Null

            $info = (docker exec stock-copilot-postgres psql -U stock_user -d stock_copilot -t -A -F "|" -c "
                SELECT ticker, price, fund_name FROM portfolio_transactions WHERE id = $targetId;
            ").Trim() -split "\|"

            Send-Reply $chatId "✏️ <b>ĐÃ ĐIỀU CHỈNH SỐ LƯỢNG THÀNH CÔNG!</b>`n• Mã: <b>$($info[0])</b> ($($info[2]))`n• Số lượng mới: <b>$newQty cp</b> @ $([double]$info[1]).ToString('N0') đ`n• Danh mục đã tự động cập nhật lại tổng tài sản."
            return $true
        }
    }

    return $false
}

function Execute-DirectTrade($chatId, $intent) {
    $fund = $intent.Fund
    $ticker = $intent.Ticker
    $qty = $intent.Qty
    $price = $intent.Price
    $act = $intent.Action

    $meta = Get-Ticker-Metadata $ticker
    $sector = $meta.Sector
    $name = $meta.CompanyName

    if ($act -eq "BUY") {
        docker exec stock-copilot-postgres psql -U stock_user -d stock_copilot -c "
            INSERT INTO watchlists (ticker, company_name, sector) VALUES ('$ticker', '$name', '$sector')
            ON CONFLICT (ticker) DO UPDATE SET sector = EXCLUDED.sector WHERE watchlists.sector = 'Khác';
            INSERT INTO portfolio_transactions (fund_name, ticker, action, quantity, price, notes)
            VALUES ('$fund', '$ticker', 'BUY', $qty, $price, 'Telegram NLP');
        " | Out-Null

        $holdingRaw = docker exec stock-copilot-postgres psql -U stock_user -d stock_copilot -t -A -F "|" -c "
            SELECT current_qty, avg_buy_price, total_invested FROM v_portfolio_holdings WHERE fund_name = '$fund' AND ticker = '$ticker';
        "
        $parts = $holdingRaw.Trim() -split "\|"
        $curQty = $parts[0]
        $avgCost = [double]$parts[1]

        $reply = @"
✅ <b>ĐÃ GHI NHẬN LỆNH MUA VÀO QUỸ [$($fund.ToUpper())]!</b>
─────────────────────
• Mã: <b>$ticker</b> ($sector)
• Số lượng mua: <b>$qty cp</b> @ <b>$($price.ToString('N0')) đ</b>
• Tổng tiền lệnh: <b>$([Math]::Round($qty * $price).ToString('N0')) VND</b>

📊 <b>VỊ THẾ QUỸ $fund HIỆN TẠI:</b>
• Đang nắm giữ: <b>$curQty cp $ticker</b>
• <b>Giá vốn bình quân: $($avgCost.ToString('N0')) VND</b>
"@
        Send-Reply $chatId $reply
    }
    elseif ($act -eq "SELL") {
        $holdingRaw = docker exec stock-copilot-postgres psql -U stock_user -d stock_copilot -t -A -F "|" -c "
            SELECT current_qty, avg_buy_price FROM v_portfolio_holdings WHERE fund_name = '$fund' AND ticker = '$ticker';
        "
        $avgCost = 0
        $curQty = 0
        if ($holdingRaw -and $holdingRaw.Trim() -ne "") {
            $parts = $holdingRaw.Trim() -split "\|"
            $curQty = [int]$parts[0]
            $avgCost = [double]$parts[1]
        }

        docker exec stock-copilot-postgres psql -U stock_user -d stock_copilot -c "
            INSERT INTO portfolio_transactions (fund_name, ticker, action, quantity, price, notes)
            VALUES ('$fund', '$ticker', 'SELL', $qty, $price, 'Telegram NLP');
        " | Out-Null

        $revenue = $qty * $price
        $costBasis = $qty * $avgCost
        $realizedPnl = $revenue - $costBasis
        $pnlPct = if ($costBasis -gt 0) { [Math]::Round(($realizedPnl / $costBasis) * 100, 2) } else { 0 }
        $remainQty = [Math]::Max(0, ($curQty - $qty))

        $pnlIcon = if ($realizedPnl -ge 0) { "🎉 CHỐT LÃI: +" } else { "⚠️ CẮT LỖ: " }

        $reply = @"
✅ <b>ĐÃ GHI NHẬN LỆNH BÁN CHO QUỸ [$($fund.ToUpper())]!</b>
─────────────────────
• Mã: <b>$ticker</b> | Bán: <b>$qty cp</b> @ <b>$($price.ToString('N0')) đ</b>
• Tổng tiền thu về: <b>$($revenue.ToString('N0')) VND</b>
• <b>Lợi nhuận thực tế: $pnlIcon$($realizedPnl.ToString('N0')) VND ($pnlPct%)</b>

📊 <b>SỐ DƯ QUỸ $fund CÒN LẠI:</b> <b>$remainQty cp $ticker</b>
"@
        Send-Reply $chatId $reply
    }
}

function Handle-PortfolioReport($chatId, $filterFund = "") {
    $sqlFilter = if ($filterFund -ne "") { "WHERE fund_name = '$filterFund'" } else { "" }
    $raw = docker exec stock-copilot-postgres psql -U stock_user -d stock_copilot -t -A -F "|" -c "
        SELECT fund_name, ticker, company_name, sector, current_qty, avg_buy_price, total_invested
        FROM v_portfolio_holdings $sqlFilter ORDER BY fund_name, total_invested DESC;
    "
    $lines = ($raw -split "`n") | Where-Object { $_.Trim() -ne "" }
    if ($lines.Count -eq 0) {
        $msgTarget = if ($filterFund -ne "") { "của <b>Quỹ $filterFund</b>" } else { "" }
        Send-Reply $chatId "📂 <b>Danh mục tài sản $msgTarget hiện đang trống.</b>`n`nBạn có thể nhắn:`n• <i>'Đã mua 10cp FPT giá 65,3'</i>`n• <i>'Quỹ chung đã mua 10cp CTG giá 30,05'</i>"
        return
    }

    $fundGroups = @{}
    $grandValuation = 0
    $grandCost = 0
    $sectorMap = @{}

    foreach ($line in $lines) {
        $parts = $line -split "\|"
        $fund = $parts[0]
        $ticker = $parts[1]
        $companyName = $parts[2]
        $sector = $parts[3]
        $qty = [int]$parts[4]
        $avgCost = [double]$parts[5]
        $invested = [double]$parts[6]

        $livePrice = Get-LivePrice $ticker
        if ($livePrice -eq 0) { $livePrice = $avgCost }

        $curVal = $qty * $livePrice
        $pnlVal = $curVal - $invested
        $pnlPct = if ($invested -gt 0) { [Math]::Round(($pnlVal / $invested) * 100, 2) } else { 0 }
        $grandCost += $invested
        $grandValuation += $curVal

        if (-not $fundGroups.ContainsKey($fund)) {
            $fundGroups[$fund] = @{
                Holdings = @()
                TotalCost = 0
                TotalVal = 0
            }
        }
        $fundGroups[$fund].TotalCost += $invested
        $fundGroups[$fund].TotalVal += $curVal
        $fundGroups[$fund].Holdings += [PSCustomObject]@{
            Ticker = $ticker
            Sector = $sector
            Qty = $qty
            AvgCost = $avgCost
            LivePrice = $livePrice
            CurVal = $curVal
            PnlVal = $pnlVal
            PnlPct = $pnlPct
        }

        if (-not $sectorMap.ContainsKey($sector)) { $sectorMap[$sector] = 0 }
        $sectorMap[$sector] += $curVal
    }

    $grandPnl = $grandValuation - $grandCost
    $grandPnlPct = if ($grandCost -gt 0) { [Math]::Round(($grandPnl / $grandCost) * 100, 2) } else { 0 }
    $grandIcon = if ($grandPnl -ge 0) { "🟢 +" } else { "🔴 " }

    $bodyText = ""
    foreach ($fKey in $fundGroups.Keys) {
        $fg = $fundGroups[$fKey]
        $fPnl = $fg.TotalVal - $fg.TotalCost
        $fPnlPct = if ($fg.TotalCost -gt 0) { [Math]::Round(($fPnl / $fg.TotalCost) * 100, 2) } else { 0 }
        $fIcon = if ($fPnl -ge 0) { "🟢 +" } else { "🔴 " }

        $bodyText += "🏛️ <b>QUỸ " + $fKey.ToUpper() + ":</b>`n"
        $bodyText += "  • Giá trị: " + $fg.TotalVal.ToString('N0') + " đ | Lời/Lỗ: " + $fIcon + $fPnl.ToString('N0') + " đ (" + $fPnlPct + "%)`n"
        foreach ($h in $fg.Holdings) {
            $pIcon = if ($h.PnlVal -ge 0) { "🟢 +" } else { "🔴 " }
            $bodyText += "    ▫️ <b>" + $h.Ticker + "</b> (" + $h.Sector + "): <b>" + $h.Qty + " cp</b>`n"
            $bodyText += "       Vốn: " + $h.AvgCost.ToString('N0') + " đ | Thị giá: " + $h.LivePrice.ToString('N0') + " đ`n"
            $bodyText += "       Giá trị: " + $h.CurVal.ToString('N0') + " đ (" + $pIcon + $h.PnlVal.ToString('N0') + " đ | " + $h.PnlPct + "%)`n"
        }
        $bodyText += "`n"
    }

    $sectorText = ""
    foreach ($sKey in $sectorMap.Keys) {
        $pct = [Math]::Round(($sectorMap[$sKey] / $grandValuation) * 100, 1)
        $sectorText += "  - " + $sKey + ": " + $sectorMap[$sKey].ToString('N0') + " đ (" + $pct + "%)`n"
    }

    $reply = @"
📊 <b>BÁO CÁO TỔNG TÀI SẢN & ĐA QUỸ ĐẦU TƯ</b>
─────────────────────
💰 <b>TỔNG TÀI SẢN:</b> <b>$($grandValuation.ToString('N0')) VND</b>
💵 <b>Tổng vốn đầu tư:</b> $($grandCost.ToString('N0')) VND
📈 <b>Tổng Lời / Lỗ:</b> $grandIcon$($grandPnl.ToString('N0')) VND (<b>$grandPnlPct%</b>)

$bodyText
🏢 <b>PHÂN BỔ THEO NGÀNH:</b>
$sectorText
💡 <i>Nếu nhập nhầm giá hoặc số lượng, chỉ cần nhắn: <b>'sửa giá thành 57.3'</b> hoặc <b>'xóa giao dịch vừa rồi'</b>!</i>
"@
    Send-Reply $chatId $reply
}

function Handle-PersonalizedAdvice($chatId, $ticker) {
    $ticker = $ticker.ToUpper()
    $raw = docker exec stock-copilot-postgres psql -U stock_user -d stock_copilot -t -A -F "|" -c "
        SELECT fund_name, current_qty, avg_buy_price, total_invested FROM v_portfolio_holdings WHERE ticker = '$ticker';
    "
    $lines = ($raw -split "`n") | Where-Object { $_.Trim() -ne "" }
    $livePrice = Get-LivePrice $ticker

    $fScoreRaw = docker exec stock-copilot-postgres psql -U stock_user -d stock_copilot -t -A -c "
        SELECT COALESCE(f_score, 8) FROM financial_reports WHERE ticker = '$ticker' ORDER BY year DESC, quarter DESC LIMIT 1;
    "
    $fScore = if ($fScoreRaw -and $fScoreRaw.Trim() -ne "") { [int]$fScoreRaw.Trim() } else { 8 }

    if ($lines.Count -gt 0) {
        $posText = ""
        $totalQtyAll = 0
        $totalCostAll = 0

        foreach ($l in $lines) {
            $p = $l -split "\|"
            $fName = $p[0]
            $q = [int]$p[1]
            $cost = [double]$p[2]
            $inv = [double]$p[3]
            $totalQtyAll += $q
            $totalCostAll += $inv

            $pnlVal = ($livePrice - $cost) * $q
            $pnlPct = if ($cost -gt 0) { [Math]::Round(($pnlVal / ($cost * $q)) * 100, 2) } else { 0 }
            $st = if ($pnlVal -ge 0) { "🟢 +" + $pnlVal.ToString('N0') + " đ (+" + $pnlPct + "%)" } else { "🔴 " + $pnlVal.ToString('N0') + " đ (" + $pnlPct + "%)" }

            $posText += "• <b>Quỹ " + $fName + ":</b> " + $q + " cp (Vốn: " + $cost.ToString('N0') + " đ) ➔ " + $st + "`n"
        }

        $overallAvg = [Math]::Round($totalCostAll / $totalQtyAll, 0)
        $overallPnlPct = [Math]::Round((($livePrice - $overallAvg) / $overallAvg) * 100, 2)

        $strategy = ""
        if ($overallPnlPct -gt 15) {
            $strategy = "🎯 <b>Chiến lược: CHỐT LỜI TỪNG PHẦN.</b> Đang có biên lãi rất tốt (+" + $overallPnlPct + "%). Nên chốt 30-50% số lượng để bảo toàn lợi nhuận."
        } elseif ($overallPnlPct -lt -5) {
            $strategy = "⚠️ <b>Chiến lược: CANH HẠ GIÁ VỐN.</b> Đang âm tạm thời " + $overallPnlPct + "%. Doanh nghiệp có BCTC vững (F-Score " + $fScore + "/9), có thể mua thăm dò hạ giá vốn quanh vùng " + $livePrice.ToString('N0') + " đ."
        } else {
            $strategy = "⏳ <b>Chiến lược: TIẾP TỤC NẮM GIỮ.</b> Giá dao động quanh giá vốn. Dòng tiền ổn định."
        }

        $reply = @"
🎯 <b>TƯ VẤN CÁ NHÂN HÓA: CỔ PHIẾU $ticker</b>
─────────────────────
Thị giá sàn HOSE hiện tại: <b>$($livePrice.ToString('N0')) VND</b>
F-Score doanh nghiệp: <b>$fScore/9</b>

👤 <b>VỊ THẾ CỦA BẠN TRONG CÁC QUỸ:</b>
$posText
➡️ <i>Tổng sở hữu: <b>$totalQtyAll cp</b> (Giá vốn chung: $($overallAvg.ToString('N0')) đ | Biến động: $overallPnlPct%)</i>

💡 <b>ĐỀ XUẤT HÀNH ĐỘNG:</b>
$strategy
"@
    } else {
        $reply = @"
🔍 <b>PHÂN TÍCH NHANH: $ticker</b>
─────────────────────
• Hiện tại bạn <b>chưa có cổ phiếu $ticker</b> trong bất kỳ quỹ nào.
• Thị giá sàn HOSE hiện tại: <b>$($livePrice.ToString('N0')) VND</b>.
• Sức khỏe BCTC: F-Score đạt <b>$fScore/9</b>.
• Vùng giải ngân an toàn: $($([Math]::Round($livePrice * 0.99)).ToString('N0')) – $($livePrice.ToString('N0')) VND.

💡 <i>Nhắn tin: <b>'Phân tích chuyên sâu $ticker'</b> để nhận Bản lập luận đầu tư 4 trụ cột chi tiết!</i>
"@
    }
    Send-Reply $chatId $reply
}

function Parse-Budget-Query($t, $foundTicker = $null) {
    if ($foundTicker -or ($t -match "(bao nhiêu|cho|vào|thế còn|tại sao|sao lại|chuẩn bị|lệnh|phần nào)")) {
        return $null
    }
    if ($t -match "(?:có|với|tôi có|đang có|dư|còn|vốn)\s+(\d+[\.,]?\d*)\s*(k|nghìn|ngàn|tr|triệu|củ|tỏi|m|đ|vnd)?\b.*(đầu tư|mua|con nào|mã nào|sinh lời|có lời|kiếm lời|gì)" -or `
        $t -match "\b(\d+[\.,]?\d*)\s*(k|nghìn|ngàn|tr|triệu|củ|tỏi|m)\b.*(đầu tư|mua gì|mua con nào|sinh lời|cơ hội)") {
        
        $numStr = $Matches[1] -replace ",", "."
        $val = [double]$numStr
        $unit = if ($Matches[2]) { $Matches[2].ToLower() } else { "" }
        
        $multiplier = 1
        if ($unit -in @("k", "nghìn", "ngàn")) {
            $multiplier = 1000
        } elseif ($unit -in @("tr", "triệu", "củ", "m")) {
            $multiplier = 1000000
        } elseif ($unit -in @("tỏi")) {
            $multiplier = 1000000000
        } else {
            if ($val -ge 50 -and $val -le 999) { $multiplier = 1000 }
            elseif ($val -lt 50) { $multiplier = 1000000 }
        }
        $budget = [Math]::Round($val * $multiplier)
        if ($budget -ge 50000) { return $budget }
    }
    return $null
}

function Handle-BudgetInvestmentAdvice($chatId, $budget) {
    $pMBB = Get-LivePrice "MBB"
    if ($pMBB -le 0) { $pMBB = 19850 }
    $pHPG = Get-LivePrice "HPG"
    if ($pHPG -le 0) { $pHPG = 21300 }
    $pFPT = Get-LivePrice "FPT"
    if ($pFPT -le 0) { $pFPT = 57500 }

    $qtyMBB = [Math]::Floor($budget / $pMBB)
    $costMBB = $qtyMBB * $pMBB
    $remMBB = $budget - $costMBB

    $qtyHPG = [Math]::Floor($budget / $pHPG)
    $costHPG = $qtyHPG * $pHPG
    $remHPG = $budget - $costHPG

    $qtyFPT = [Math]::Floor($budget / $pFPT)
    $costFPT = $qtyFPT * $pFPT
    $remFPT = $budget - $costFPT

    $tradeNote = if ($qtyMBB -lt 100 -or $qtyHPG -lt 100 -or $qtyFPT -lt 100) {
@"
💡 <b>CƠ CHẾ ĐẦU TƯ VỐN NHỎ / LÔ LẺ:</b>
• Trên sàn HOSE/HNX, lô chuẩn là 100 cp. Tuy nhiên các CTCK (DNSE, TCBS, VPS,...) đều hỗ trợ đặt lệnh <b>LÔ LẺ (1 - 99 cổ phiếu)</b> với giá khớp realtime như bảng điện tử.
• Với số vốn <b>$($budget.ToString('N0')) VND</b>, bạn hoàn toàn có thể mua tích sản từng phần để tối đa hóa lợi nhuận!
"@
    } else {
@"
💡 <b>LƯU Ý GIAO DỊCH LÔ CHUẨN:</b>
• Với số vốn <b>$($budget.ToString('N0')) VND</b>, bạn có thể mua thoải mái <b>lô chuẩn (100 cp trở lên)</b> và phân bổ đa dạng hóa thành danh mục 2-3 ngành!
"@
    }

    $strategyPick = ""
    if ($budget -le 1000000) {
        $strategyPick = @"
🌟 <b>ĐỀ XUẤT CHO BẠN:</b>
• Nếu muốn <b>an toàn, tích lũy số lượng & nhận cổ tức tiền mặt</b>: Mua <b>$qtyMBB cp MBB</b>.
• Nếu muốn <b>tăng trưởng mạnh & đón sóng phục hồi</b>: Mua <b>$qtyHPG cp HPG</b> hoặc <b>$qtyFPT cp FPT</b>.
"@
    } else {
        $halfBudget = $budget / 2
        $qFPT = [Math]::Floor($halfBudget / $pFPT)
        $qHPG = [Math]::Floor($halfBudget / $pHPG)
        $strategyPick = @"
🌟 <b>ĐỀ XUẤT PHÂN BỔ DANH MỤC 50 / 50:</b>
• <b>$qFPT cp FPT</b> (~$(($qFPT * $pFPT).ToString('N0')) đ) ➔ Trụ cột Tăng trưởng Công nghệ & AI
• <b>$qHPG cp HPG</b> (~$(($qHPG * $pHPG).ToString('N0')) đ) ➔ Đón sóng Chu kỳ Công nghiệp Dung Quất 2
"@
    }

    $reply = @"
💡 <b>TƯ VẤN ĐẦU TƯ THEO NGÂN SÁCH: $($budget.ToString('N0')) VND</b>
─────────────────────
$tradeNote

📊 <b>SO SÁNH 3 CƠ HỘI ĐẦU TƯ SINH LỜI TỐT NHẤT:</b>

1️⃣ <b>MBB (Ngân hàng Quân Đội)</b> — <i>Tích sản & Cổ tức an toàn</i>
• Thị giá realtime: <b>$($pMBB.ToString('N0')) đ/cp</b>
• Số lượng mua được: <b>$qtyMBB cp</b> (Chi: $($costMBB.ToString('N0')) đ, Dư: $($remMBB.ToString('N0')) đ)
• Sức khỏe BCTC: F-Score 8/9 | P/B ~1.0 (Định giá rẻ)
• Tỷ suất cổ tức tiền mặt: 10 - 15%/năm | Kỳ vọng sinh lời: <b>15 - 20%/năm</b>
• Ưu điểm: Rủi ro cực thấp, quản trị nợ xấu hàng đầu hệ thống.

2️⃣ <b>HPG (Tập đoàn Hòa Phát)</b> — <i>Đón sóng Chu kỳ Phục hồi</i>
• Thị giá realtime: <b>$($pHPG.ToString('N0')) đ/cp</b>
• Số lượng mua được: <b>$qtyHPG cp</b> (Chi: $($costHPG.ToString('N0')) đ, Dư: $($remHPG.ToString('N0')) đ)
• Sức khỏe BCTC: F-Score 7/9 | Doanh nghiệp đầu ngành Thép
• Động lực bứt phá: Dự án Dung Quất 2 tăng gấp đôi sản lượng thép HRC
• Kỳ vọng sinh lời: <b>20 - 30%/năm</b> khi thị trường BĐS & đầu tư công khởi sắc.

3️⃣ <b>FPT (Tập đoàn FPT)</b> — <i>Siêu Tăng trưởng Kép Bền vững</i>
• Thị giá realtime: <b>$($pFPT.ToString('N0')) đ/cp</b>
• Số lượng mua được: <b>$qtyFPT cp</b> (Chi: $($costFPT.ToString('N0')) đ, Dư: $($remFPT.ToString('N0')) đ)
• Sức khỏe BCTC: F-Score 9/9 | Tăng trưởng 20%/năm suốt 10 năm qua
• Động lực bứt phá: Làn sóng AI, Chip bán dẫn & Hợp đồng phần mềm toàn cầu
• Kỳ vọng sinh lời: <b>25 - 35%/năm</b> (Lý tưởng cho tích sản dài hạn).

─────────────────────
$strategyPick
"@
    Send-Reply $chatId $reply
}

# --- VÒNG LẶP LẮNG NGHE BOT (THỨ TỰ ƯU TIÊN HOÀN HẢO) ---
$lastUpdateId = 0
try {
    $init = Invoke-RestMethod -Uri "https://api.telegram.org/bot$token/getUpdates"
    if ($init.result.Count -gt 0) {
        $lastUpdateId = $init.result[-1].update_id
    }
} catch {}

$chatHistory = @()

while ($true) {
    try {
        $url = "https://api.telegram.org/bot$token/getUpdates?offset=$($lastUpdateId + 1)&timeout=15"
        $updates = Invoke-RestMethod -Uri $url -TimeoutSec 20
        foreach ($u in $updates.result) {
            $lastUpdateId = $u.update_id
            $msg = $u.message
            if (-not $msg -or -not $msg.text) { continue }
            $chatId = $msg.chat.id
            $text = $msg.text.Trim()
            $sender = $msg.from.first_name

            Write-Host "[$([DateTime]::Now.ToString('HH:mm:ss'))] Nhận tin nhắn từ " + $sender + ": " + $text -ForegroundColor Yellow

            # Trích xuất mã ticker nếu có
            $cleanText = ($text -replace "[.,:;!?'`"]", " ")
            $words = $cleanText -split "\s+"
            $foundTicker = $null
            foreach ($w in $words) {
                $u = $w.Trim().ToUpper()
                if ($u.Length -eq 3 -and $u -notin $stopWords -and $u -match "^[A-Z]{3}$") {
                    $foundTicker = $u
                    break
                }
            }

            # 1. ƯU TIÊN SỐ 1: LOẠI BỎ KHỎI DANH SÁCH THEO DÕI (PHẢI TRƯỚC THÊM ĐỂ KHÔNG BỊ TRÙNG TỪ 'THEO DÕI')
            $isRemoveWatchlist = ($text -match "(loại|loại bỏ|bỏ|xóa|xoá|gỡ|remove)") -and $foundTicker -and ($text -notmatch "(giao dịch|lệnh|gd)")
            if ($isRemoveWatchlist) {
                Handle-RemoveWatchlist $chatId $foundTicker
                continue
            }

            # 2. ƯU TIÊN SỐ 2: THÊM VÀO DANH SÁCH THEO DÕI (KHÔNG CHỨA TỪ KHÓA MUA/BÁN/GIÁ)
            $isAddWatchlist = ($text -match "(thêm|theo dõi thêm|add|cho vào theo dõi)") -and $foundTicker -and ($text -notmatch "(mua|múc|bán|sút|giá)")
            if ($isAddWatchlist) {
                Handle-AddWatchlist $chatId $foundTicker
                continue
            }

            # 3. ƯU TIÊN SỐ 3: LÀM MỚI DANH SÁCH THEO DÕI
            if ($text -match "(làm mới|cập nhật lại|cập nhật|refresh)\s*(lại)?\s*(danh sách|theo dõi|watchlist)?") {
                Handle-RefreshWatchlist $chatId
                continue
            }

                        # 3.5. ƯU TIÊN: TƯ VẤN ĐẦU TƯ THEO NGÂN SÁCH (VD: 'Có 500k nên đầu tư gì', 'Có 1tr nên mua con nào')
            $budget = Parse-Budget-Query $text $foundTicker
            if ($budget -and $budget -gt 0) {
                Handle-BudgetInvestmentAdvice $chatId $budget
                continue
            }

            # 4. ƯU TIÊN SỐ 4: SỬA NHẦM / ĐÍNH CHÍNH / XÓA GIAO DỊCH
            if ($text -match "(sửa|chỉnh|nhầm|sửa lại|đính chính|update|edit|xóa|xoá|hủy bỏ|xóa đi|undo)") {
                $corrected = Handle-Correction $chatId $text
                if ($corrected) { continue }
            }

            # 5. ƯU TIÊN SỐ 5: GIAO DỊCH MUA / BÁN TỰ NHIÊN
            $intent = Parse-Stock-Intent $text
            if ($intent.Action -and $intent.Ticker -and $intent.Qty -gt 0 -and $intent.Price -gt 0) {
                Execute-DirectTrade $chatId $intent
                continue
            }

            # 6. ƯU TIÊN SỐ 6: BÁO CÁO DANH MỤC / THEO DÕI
            if ($text -match "(danh sách theo dõi|theo dõi|watchlist|/theodoi|/watchlist)") {
                Handle-WatchlistReport $chatId
                continue
            }
            if ($text -match "(danh mục cá nhân|tài sản cá nhân|quỹ cá nhân|/canhan)") {
                Handle-PortfolioReport $chatId "Cá nhân"
                continue
            }
            if ($text -match "(danh mục chung|tài sản chung|quỹ chung|/chung)") {
                Handle-PortfolioReport $chatId "Tiền chung"
                continue
            }
            if ($text -match "(danh mục|tài sản|portfolio|/portfolio|/list|/danhmuc)") {
                Handle-PortfolioReport $chatId ""
                continue
            }

                        # 6.5. ƯU TIÊN: PHÂN TÍCH CHUYÊN SÂU CỔ PHIẾU (VD: 'Phân tích chuyên sâu PVD', 'Phân tích PVD', '/deep PVD')
            $isDeepAnalysis = (($text -match "^/(deep|phantich|ptcs)\b") -or ($text -match "^(phân tích chuyên sâu|luận điểm đầu tư|báo cáo|hồ sơ)\s+[A-Za-z]{3}$")) -and $foundTicker
            if ($isDeepAnalysis) {
                Handle-DeepAnalysis $chatId $foundTicker
                continue
            }

            # 7. HỎI MÃ CỔ PHIẾU CỤ THỂ (CHỈ KHI GÕ DUY NHẤT TÊN MÃ NGẮN GỌN)
            $isDirectTickerOnly = $foundTicker -and ($words.Count -le 2) -and ($text -notmatch "(sao|tại sao|nên|không|đầu tư|thế nào|ổn|mua|bán|vì sao|mấy|rồi|này|kia|gì)")
            if ($isDirectTickerOnly) {
                Handle-PersonalizedAdvice $chatId $foundTicker
                continue
            }

            # 8. TẦNG NÃO BỘ AI: TRÒ CHUYỆN & TƯ VẤN TỰ NHIÊN BẰNG AGY (GEMINI) - HOÀN TOÀN KHÔNG DÙNG IF/ELSE BẮT TỪ KHÓA
            Write-Host "[$([DateTime]::Now.ToString('HH:mm:ss'))] Kích hoạt não bộ AI (agy / Gemini) trả lời tự nhiên cho: $text" -ForegroundColor Cyan
            $aiAnswer = Invoke-AgyConversationalAdvisor $chatId $text $chatHistory
            if ($aiAnswer) {
                $chatHistory += "Anh Phan: $text"
                $chatHistory += "Stock Copilot: $aiAnswer"
                if ($chatHistory.Count -gt 8) {
                    $chatHistory = $chatHistory[($chatHistory.Count - 8)..($chatHistory.Count - 1)]
                }
                continue
            }

            # 9. MẶC ĐỊNH DỰ PHÒNG: HƯỚNG DẪN
            $helpMsg = @"
👋 Xin chào <b>$sender</b>! Stock Copilot đã sẵn sàng:

⭐ <b>QUẢN LÝ THEO DÕI:</b>
• <i>'Thêm DGC vào danh sách theo dõi'</i>
• <i>'Loại bỏ MWG ra khỏi danh sách theo dõi'</i>
• <i>'Làm mới danh sách theo dõi'</i>
• <i>'Phân tích chuyên sâu PVD'</i> ➔ Bản báo cáo 4 trụ cột (BCTC, Catalysts, Điểm Mua/Bán)
• <i>'Có 500k thì nên đầu tư gì'</i> / <i>'Có 1tr nên mua con nào'</i>

💬 <b>GIAO DỊCH & QUẢN LÝ TÀI SẢN:</b>
• <i>'Đã mua 10cp FPT giá 65,3'</i>
• <i>'Quỹ chung đã mua 10cp CTG giá 30,05'</i>
• <i>'sửa giá thành 57.3'</i> / <i>'xóa giao dịch vừa rồi'</i>
"@
            Send-Reply $chatId $helpMsg
        }
    } catch {
        Start-Sleep -Seconds 2
    }
}
