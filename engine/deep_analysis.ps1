function Get-Ticker-Catalysts($ticker) {
    switch ($ticker) {
        "PVD" {
            return @{
                Industry = "Dầu khí & Dịch vụ Khoan thăm dò"
                Catalyst = "1. Giá thuê giàn khoan tự nâng (Jack-up) toàn cầu duy trì ở vùng đỉnh cao ~125,000 - 140,000 USD/ngày.`n2. Toàn bộ 4 giàn khoan tự nâng của PVD đã kín lịch hợp đồng dài hạn xuyên suốt đến 2026 với biên lợi nhuận gộp phục hồi mạnh mẽ.`n3. Đại dự án khí điện Lô B - Ô Môn (12 tỷ USD) đang bước vào giai đoạn triển khai trao thầu, tạo khối lượng công việc khổng lồ cho các chiến dịch khoan phát triển mỏ."
                Moat = "Độc quyền cung cấp dịch vụ khoan ngoài khơi hàng đầu tại Việt Nam và Đông Nam Á."
            }
        }
        "FPT" {
            return @{
                Industry = "Công nghệ thông tin & Trí tuệ nhân tạo (AI)"
                Catalyst = "1. Doanh thu xuất khẩu phần mềm duy trì tăng trưởng vượt bậc 25-30%/năm, thị trường Nhật Bản và APAC phục hồi mạnh.`n2. Hợp tác chiến lược toàn diện với NVIDIA xây dựng nhà máy AI Factory tại Việt Nam, thúc đẩy mảng Cloud và AI thế hệ mới.`n3. Mảng giáo dục (FPT Education) tiếp tục mở rộng quy mô đào tạo nhân lực bán dẫn và công nghệ cao."
                Moat = "Hệ sinh thái công nghệ toàn diện nhất Việt Nam, năng lực thực thi toàn cầu với chi phí cạnh tranh."
            }
        }
        "HPG" {
            return @{
                Industry = "Thép & Vật liệu xây dựng"
                Catalyst = "1. Đại dự án Khu liên hợp Gang thép Dung Quất 2 đi vào vận hành nâng tổng công suất thép thô thêm 5.6 triệu tấn HRC/năm (+66%), đưa HPG vào Top 30 nhà sản xuất thép lớn nhất thế giới.`n2. Hưởng lợi trực tiếp từ làn sóng giải ngân đầu tư công các dự án hạ tầng trọng điểm (Sân bay Long Thành, Cao tốc Bắc - Nam).`n3. Biên lợi nhuận gộp tạo đáy đi lên nhờ giá quặng sắt và than cốc hạ nhiệt."
                Moat = "Lợi thế quy mô khổng lồ, chi phí sản xuất thép thấp nhất khu vực nhờ công nghệ lò cao khép kín."
            }
        }
        "MBB" {
            return @{
                Industry = "Ngân hàng thương mại"
                Catalyst = "1. Tăng trưởng tín dụng luôn thuộc nhóm dẫn đầu hệ thống (16-18%/năm) nhờ hệ sinh thái khách hàng quân đội và bán lẻ số hóa vượt trội.`n2. Tỷ lệ tiền gửi không kỳ hạn (CASA) duy trì Top 1 toàn ngành (~38-40%), giúp tối ưu hóa chi phí vốn (COF) và giữ vững biên lãi ròng (NIM).`n3. Chính sách cổ tức tiền mặt đều đặn 10-15%/năm, an toàn tài chính cực cao."
                Moat = "Lợi thế chi phí vốn rẻ và tệp khách hàng bán lẻ số hóa lớn nhất ngành ngân hàng."
            }
        }
        "MWG" {
            return @{
                Industry = "Bán lẻ tiêu dùng & Điện tử"
                Catalyst = "1. Chuỗi Bách Hóa Xanh (BHX) chính thức vượt điểm hòa vốn và bước vào chu kỳ đóng góp lợi nhuận ròng mạnh mẽ cho tập đoàn.`n2. Tái cấu trúc tinh gọn chuỗi Thế Giới Di Động & Điện Máy Xanh, nâng cao biên lợi nhuận hoạt động trên từng điểm bán.`n3. Chuỗi nhà thuốc An Khang và thị trường Indonesia (Era Blue) mở ra không gian tăng trưởng dài hạn mới."
                Moat = "Năng lực quản trị chuỗi cung ứng, logistics và văn hóa phục vụ khách hàng số 1 ngành bán lẻ."
            }
        }
        "SSI" {
            return @{
                Industry = "Chứng khoán & Ngân hàng đầu tư"
                Catalyst = "1. Hệ thống giao dịch KRX đi vào vận hành và triển khai cơ chế Non-Pre-funding (gỡ nút thắt ký quỹ trước giao dịch cho khối ngoại).`n2. Triển vọng thị trường chứng khoán Việt Nam được tổ chức FTSE Russell nâng hạng lên Thị trường Mới nổi (Emerging Market), đón dòng vốn ngoại tỷ USD.`n3. Quy mô vốn chủ sở hữu lớn nhất ngành, dư địa cho vay ký quỹ (margin) dồi dào."
                Moat = "Thị phần môi giới tổ chức và khách hàng nước ngoài đứng đầu thị trường, nền tảng tài chính vững chắc."
            }
        }
        "CTG" {
            return @{
                Industry = "Ngân hàng quốc doanh"
                Catalyst = "1. Đã hoàn tất xử lý sạch toàn bộ nợ xấu VAMC và trích lập dự phòng rủi ro bao nợ xấu ở mức rất cao (>160%), tạo đệm an toàn vững chắc.`n2. Động lực tăng trưởng lợi nhuận trước thuế mạnh mẽ khi áp lực chi phí dự phòng giảm sâu.`n3. Tín dụng tập trung vào các dự án trọng điểm quốc gia và doanh nghiệp đầu ngành."
                Moat = "Ngân hàng trụ cột quốc gia với mạng lưới chi nhánh rộng khắp và khả năng huy động vốn uy tín hàng đầu."
            }
        }
        default {
            return @{
                Industry = "Doanh nghiệp niêm yết HOSE/HNX"
                Catalyst = "1. Doanh nghiệp đầu ngành với vị thế cạnh tranh vững chắc và dòng tiền kinh doanh ổn định.`n2. Hưởng lợi từ sự phục hồi chung của nền kinh tế vĩ mô và dòng tiền thanh khoản thị trường.`n3. Định giá P/E và P/B đang ở vùng hợp lý so với triển vọng tăng trưởng lợi nhuận."
                Moat = "Thương hiệu lâu năm và hệ thống quản trị minh bạch."
            }
        }
    }
}

function Handle-DeepAnalysis($chatId, $ticker) {
    $ticker = $ticker.ToUpper()
    $meta = Get-Ticker-Metadata $ticker
    $cName = $meta.CompanyName
    $sec = $meta.Sector

    $livePrice = Get-LivePrice $ticker
    if ($livePrice -le 0) { $livePrice = 20000 }

    $fScoreRaw = docker exec stock-copilot-postgres psql -U stock_user -d stock_copilot -t -A -c "
        SELECT COALESCE(f_score, 8) FROM financial_reports WHERE ticker = '$ticker' ORDER BY year DESC, quarter DESC LIMIT 1;
    "
    $fScore = if ($fScoreRaw -and $fScoreRaw.Trim() -ne "") { [int]$fScoreRaw.Trim() } else { 8 }

    $nowSec = [DateTimeOffset]::UtcNow.ToUnixTimeSeconds()
    $pastDailySec = $nowSec - (40 * 86400)
    $urlD = "https://services.entrade.com.vn/chart-api/v2/ohlcs/stock?from=$pastDailySec&to=$nowSec&symbol=$ticker&resolution=1D"
    $changePct = 0
    $ma20Price = $livePrice
    $volSurgeRatio = 1.0

    try {
        $rd = Invoke-RestMethod -Uri $urlD -Headers $headers -TimeoutSec 8
        $cnt = $rd.c.Count
        if ($cnt -ge 5) {
            $recentVols = $rd.v[($cnt - 21)..($cnt - 2)]
            $ma20Vol = ($recentVols | Measure-Object -Average).Average
            $recentCloses = $rd.c[($cnt - 21)..($cnt - 2)]
            $ma20Price = [Math]::Round((($recentCloses | Measure-Object -Average).Average) * 1000)
            
            $todayVol = $rd.v[$cnt - 1]
            $volSurgeRatio = [Math]::Round(($todayVol / [Math]::Max($ma20Vol, 1)), 2)

            $prevC = $rd.c[$cnt - 2] * 1000
            $changePct = [Math]::Round((($livePrice - $prevC) / $prevC) * 100, 2)
        }
    } catch {}

    $changeSign = if ($changePct -ge 0) { "+$changePct%" } else { "$changePct%" }
    $changeIcon = if ($changePct -ge 0) { "🟢" } else { "🔴" }

    $catData = Get-Ticker-Catalysts $ticker
    $ind = $catData.Industry
    $catalysts = $catData.Catalyst
    $moat = $catData.Moat

    $buyMin = [Math]::Round(($livePrice * 0.98) / 50) * 50
    $buyMax = [Math]::Round(($livePrice * 1.01) / 50) * 50
    $target1 = [Math]::Round(($livePrice * 1.08) / 50) * 50
    $target2 = [Math]::Round(($livePrice * 1.18) / 50) * 50
    $stoploss = [Math]::Round(($livePrice * 0.96) / 50) * 50

    $rawHoldings = docker exec stock-copilot-postgres psql -U stock_user -d stock_copilot -t -A -F "|" -c "
        SELECT fund_name, current_qty, avg_buy_price, total_invested FROM v_portfolio_holdings WHERE ticker = '$ticker';
    "
    $lines = ($rawHoldings -split "`n") | Where-Object { $_.Trim() -ne "" }
    $portfolioSection = ""

    if ($lines.Count -gt 0) {
        $posDetails = ""
        $totalQ = 0
        $totalInv = 0
        foreach ($l in $lines) {
            $p = $l -split "\|"
            $fn = $p[0]
            $q = [int]$p[1]
            $avgC = [double]$p[2]
            $inv = [double]$p[3]
            $totalQ += $q
            $totalInv += $inv

            $pnl = ($livePrice - $avgC) * $q
            $pnlPct = if ($avgC -gt 0) { [Math]::Round(($pnl / ($avgC * $q)) * 100, 2) } else { 0 }
            $st = if ($pnl -ge 0) { "🟢 +" + $pnl.ToString('N0') + " đ (+" + $pnlPct + "%)" } else { "🔴 " + $pnl.ToString('N0') + " đ (" + $pnlPct + "%)" }
            $posDetails += "• <b>Quỹ ${fn}:</b> $q cp (Giá vốn: $($avgC.ToString('N0')) đ) ➔ $st`n"
        }
        $avgAll = [Math]::Round($totalInv / $totalQ, 0)
        $pnlAll = [Math]::Round((($livePrice - $avgAll) / $avgAll) * 100, 2)

        $strategyText = if ($pnlAll -ge 10) {
            "🎯 <b>Khuyến nghị cho bạn:</b> Đang có lợi nhuận tốt (+${pnlAll}%). Có thể tiếp tục nắm giữ đến Target 1 ($($target1.ToString('N0')) đ), hoặc chủ động hiện thực hóa 30% lợi nhuận."
        } elseif ($pnlAll -le -4) {
            "⚠️ <b>Khuyến nghị cho bạn:</b> Đang âm tạm thời ${pnlAll}%. Doanh nghiệp có BCTC vững vàng (F-Score $fScore/9), có thể giải ngân hạ giá vốn quanh vùng hỗ trợ $($buyMin.ToString('N0')) đ."
        } else {
            "⏳ <b>Khuyến nghị cho bạn:</b> Giá đang dao động quanh giá vốn (${pnlAll}%). Xu hướng dòng tiền ổn định, tiếp tục nắm giữ theo kế hoạch."
        }

        $portfolioSection = @"
📂 <b>VỊ THẾ TÀI SẢN CỦA BẠN:</b>
$posDetails• Tổng sở hữu: <b>$totalQ cp</b> (Giá vốn chung: <b>$($avgAll.ToString('N0')) đ</b> | Biến động: <b>$pnlAll%</b>)
$strategyText
"@
    } else {
        $portfolioSection = @"
📂 <b>VỊ THẾ TÀI SẢN CỦA BẠN:</b>
• Hiện bạn <b>chưa sở hữu $ticker</b> trong bất kỳ quỹ nào.
💡 <b>Khuyến nghị giải ngân:</b> Bạn có thể chia vốn làm 2 phần: giải ngân thăm dò 30-50% trong vùng $($buyMin.ToString('N0')) – $($buyMax.ToString('N0')) đ, và gia tăng phần còn lại khi vượt Pivot ($($target1.ToString('N0')) đ).
"@
    }

    $deepReply = @"
📑 <b>BẢN BÁO CÁO PHÂN TÍCH CHUYÊN SÂU: $ticker</b>
─────────────────────
🏢 <b>Doanh nghiệp:</b> <b>$cName</b>
🏷️ <b>Ngành:</b> $ind ($sec)
Thị giá sàn: <b>$($livePrice.ToString('N0')) VND</b> ($changeIcon $changeSign)
Đường trung bình MA20: <b>$($ma20Price.ToString('N0')) VND</b> | Thanh khoản: <b>$($volSurgeRatio)x MA20</b>

📊 <b>1. NỀN TẢNG TÀI CHÍNH (BCTC):</b>
• Điểm chất lượng Piotroski: <b>$fScore/9</b> (Cấu trúc tài chính lành mạnh).
• Lợi thế cạnh tranh (Moat): $moat

🚀 <b>2. CHẤT XÚC TÁC TĂNG TRƯỞNG (CATALYSTS):</b>
$catalysts

⚖️ <b>3. KẾ HOẠCH HÀNH ĐỘNG & RISK/REWARD (1 : 3):</b>
• 🎯 <b>Vùng mua gom an toàn:</b> <b>$($buyMin.ToString('N0')) – $($buyMax.ToString('N0')) VND</b>
• 🛑 <b>Ngưỡng cắt lỗ (Stoploss):</b> <b>$($stoploss.ToString('N0')) VND</b> (-4.0%)
• 🎯 <b>Mục tiêu chốt lời 1 (T+):</b> <b>$($target1.ToString('N0')) VND</b> (+8.0%)
• 🚀 <b>Mục tiêu chốt lời 2 (Trend):</b> <b>$($target2.ToString('N0')) VND</b> (+18.0%)

─────────────────────
$portfolioSection
"@
    Send-Reply $chatId $deepReply
}