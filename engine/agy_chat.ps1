# AGY Context-Aware Conversational AI Engine for Stock Copilot
# Connects directly to local Gemini 3.8 Flash via agy.exe
# Feeds real-time multi-fund portfolio & market context into the conversation

$agyPath = "C:\Users\hieu.pt\AppData\Local\agy\bin\agy.exe"
$workDir = "c:\AI-Software-Department"

function Get-Portfolio-Context-Text {
    $raw = docker exec stock-copilot-postgres psql -U stock_user -d stock_copilot -t -A -F "|" -c "
        SELECT fund_name, ticker, current_qty, avg_buy_price, total_invested FROM v_portfolio_holdings ORDER BY fund_name, ticker;
    "
    $lines = ($raw -split "`n") | Where-Object { $_.Trim() -ne "" }
    if ($lines.Count -eq 0) {
        return "Hiện tại anh Phan chưa có cổ phiếu nào trong danh mục."
    }
    $res = @()
    foreach ($l in $lines) {
        $p = $l -split "\|"
        $fn = $p[0]
        $tk = $p[1]
        $q = $p[2]
        $avg = [double]$p[3]
        $res += "- Quỹ ${fn}: $q cp $tk (giá vốn: $($avg.ToString('N0')) đ)"
    }
    return ($res -join "`n")
}

function Invoke-AgyConversationalAdvisor($chatId, $userMessage, $historyTurns) {
    # 1. Thu thập bối cảnh danh mục thực tế của anh Phan
    $portContext = Get-Portfolio-Context-Text

    # 2. Định dạng lịch sử trao đổi gần nhất
    $histText = if ($historyTurns -and $historyTurns.Count -gt 0) {
        $historyTurns -join "`n"
    } else {
        "Chưa có trao đổi trước đó."
    }

    # 3. Xây dựng prompt giàu ngữ cảnh cho agy (Gemini)
    $prompt = @"
Bạn là Stock Copilot, chuyên gia tư vấn đầu tư tài chính và quản lý tài sản chứng khoán Việt Nam sắc sảo, tận tâm.
Bạn đang trò chuyện trực tiếp trên Telegram với anh Phan (chủ tài khoản).

DỮ LIỆU TÀI SẢN THỰC TẾ CỦA ANH PHAN (TRONG DATABASE POSTGRESQL):
$portContext

LỊCH SỬ TRAO ĐỔI GẦN ĐÂY TRÊN TELEGRAM:
$histText

CÂU NÓI / THẮC MẮC MỚI NHẤT CỦA ANH PHAN:
"$userMessage"

YÊU CẦU TRẢ LỜI CỦA BẠN:
1. Đọc hiểu sâu sắc ngữ cảnh và liên kết chặt chẽ với những gì anh Phan ĐANG NẮM GIỮ (ví dụ: nếu anh Phan thắc mắc tại sao không khuyên mua PVD mà lại là 3 mã kia vì anh ấy đã có FPT/HPG rồi, hãy công nhận góc nhìn thông minh của anh ấy, giải thích lý do ban đầu của thuật toán và phân tích đa chiều về PVD giúp đa dạng hóa sang ngành Dầu khí).
2. Trả lời HOÀN TOÀN TỰ NHIÊN, sắc sảo như một Giám đốc Tư vấn Đầu tư Chứng khoán (Senior Portfolio Advisor), không máy móc.
3. Đưa ra so sánh cụ thể về: Ngành, Thị giá, Động lực tăng trưởng (Catalyst), Lợi nhuận kỳ vọng và Rủi ro.
4. Trả lời bằng tiếng Việt, định dạng HTML Telegram (dùng <b>in đậm</b>, <i>in nghiêng</i>, các bullet point gạch đầu dòng rõ ràng, có emoji trực quan). Độ dài vừa phải từ 3 đến 5 đoạn súc tích.
"@

    # Gọi agy.exe
    $escapedPrompt = '"' + ($prompt.Replace('"', '\"')) + '"'
    
    $psi = New-Object System.Diagnostics.ProcessStartInfo
    $psi.FileName = $agyPath
    $psi.WorkingDirectory = $workDir
    $psi.Arguments = "--dangerously-skip-permissions --disable-slash-commands --effort low --print $escapedPrompt"
    $psi.UseShellExecute = $false
    $psi.RedirectStandardOutput = $true
    $psi.RedirectStandardError = $true
    $psi.StandardOutputEncoding = [System.Text.Encoding]::UTF8
    $psi.StandardErrorEncoding = [System.Text.Encoding]::UTF8

    try {
        $proc = [System.Diagnostics.Process]::Start($psi)
        $stdout = $proc.StandardOutput.ReadToEnd()
        $stderr = $proc.StandardError.ReadToEnd()
        $proc.WaitForExit()

        $aiReply = $stdout.Trim()
        if (-not $aiReply) {
            $aiReply = $stderr.Trim()
        }

        if ($aiReply) {
            # Gửi phản hồi qua Telegram
            Send-Reply $chatId $aiReply
            return $aiReply
        }
    } catch {
        Write-Host "Lỗi gọi agy: $_" -ForegroundColor Red
    }
    return $null
}