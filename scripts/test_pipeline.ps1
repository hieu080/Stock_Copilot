# Test Pipeline for Stock Copilot (Two-Tier Realtime Alert + PostgreSQL + Telegram + AGY)
Write-Host "=== BẮT ĐẦU KIỂM THỬ GỬI CẢNH BÁO LIVE VỀ TELEGRAM ===" -ForegroundColor Cyan

$token = "8862702138:AAHEUnRXYNdmeSqe7kUQ9n6VMXiI9B_H828"
$chatId = "6428436481"

# 1. TẦNG 1: FLASH ALERT (< 0.5s)
Write-Host "[1/2] Đang bắn TẦNG 1 (Flash Alert) về điện thoại..." -ForegroundColor Yellow
$flashMsg = @"
⚡ <b>[FLASH ALERT: FPT - CTCP FPT]</b>
⏱️ <i>Thời gian: 10:25:02 AM</i>

• Giá hiện tại: <b>138.500 VND</b> (Vừa vượt Pivot 137.0)
• Khối lượng: <b>2.4x MA20</b> (Dòng tiền lớn vào quyết liệt)
• Sức khỏe BCTC: <b>F-Score đạt 8/9</b> (Cực kỳ an toàn)

⏳ <i>Hệ thống agy đang thẩm định và tạo bài lập luận chi tiết...</i>
"@

$bodyFlash = @{
    chat_id = $chatId
    text = $flashMsg
    parse_mode = "HTML"
} | ConvertTo-Json

Invoke-RestMethod -Uri "https://api.telegram.org/bot$token/sendMessage" -Method Post -ContentType "application/json; charset=utf-8" -Body $bodyFlash | Out-Null
Write-Host "  -> Tầng 1 đã gửi thành công!" -ForegroundColor Green

# Nghỉ 3 giây mô phỏng độ trễ xử lý ngầm của agy
Start-Sleep -Seconds 3

# 2. TẦNG 2: DEEP THESIS REPORT
Write-Host "[2/2] Đang gửi TẦNG 2 (Bản Lập Luận Chuyên Sâu) về điện thoại..." -ForegroundColor Yellow
$deepMsg = @"
🎯 <b>[BẢN LẬP LUẬN ĐẦU TƯ: FPT]</b>
<i>Phân loại: Đánh sóng & Trung hạn | Xác suất tăng: <b>85%</b></i>

📈 <b>1. LẬP LUẬN KỸ THUẬT & DÒNG TIỀN:</b>
• <b>Mẫu hình:</b> Hoàn tất cấu trúc VCP (Thu hẹp độ biến động 3 vòng) trên nền giá tích lũy 6 tuần.
• <b>Dòng tiền:</b> Khối lượng bùng nổ 2.4x so với MA20, dòng tiền lớn hấp thụ toàn bộ cung chốt lời.
• <b>Vị thế:</b> Nến Marubozu vượt dứt khoát đỉnh lịch sử 137.000. RSI ở mức 62 (vùng tăng giá mạnh).

📑 <b>2. LẬP LUẬN BCTC & SỨC KHỎE DOANH NGHIỆP:</b>
• <b>Tăng trưởng:</b> Doanh thu +21.4% YoY, LNST +22.8% YoY (duy trì đà tăng 2 con số 5 năm liền).
• <b>Chất lượng tài chính:</b> Piotroski F-Score đạt 8/9. Dòng tiền kinh doanh (CFO) dương mạnh, nợ vay ròng thấp (&lt; 0.3x Vốn CSH).
• <b>Định giá:</b> P/E ~23.5x, hợp lý với tốc độ tăng trưởng EPS (PEG ~ 1.05).

🚀 <b>3. ĐỘNG LỰC TĂNG TRƯỞNG & CATALYST:</b>
• Hợp tác nhà máy AI Factory với Nvidia bắt đầu ghi nhận doanh thu.
• Doanh số ký mới mảng CNTT nước ngoài tại Nhật Bản và APAC tăng trưởng +28%.

⚖️ <b>4. KẾ HOẠCH GIẢI NGÂN & QUẢN TRỊ RỦI RO (R:R = 1 : 3.2):</b>
• <b>Vùng mua gom:</b> 137.000 – 139.000 VND
• <b>Cắt lỗ (Stoploss):</b> 133.500 VND (Vi phạm nền giá, rủi ro -3.5%)
• <b>Mục tiêu 1 (Ngắn hạn):</b> 152.000 VND (+9.8%)
• <b>Mục tiêu 2 (Trung - Dài hạn):</b> 168.000 VND (+21.3%)
"@

$bodyDeep = @{
    chat_id = $chatId
    text = $deepMsg
    parse_mode = "HTML"
} | ConvertTo-Json

Invoke-RestMethod -Uri "https://api.telegram.org/bot$token/sendMessage" -Method Post -ContentType "application/json; charset=utf-8" -Body $bodyDeep | Out-Null
Write-Host "  -> Tầng 2 đã gửi thành công!" -ForegroundColor Green

Write-Host "=== KIỂM THỬ THÀNH CÔNG RỰC RỠ: VUI LÒNG KIỂM TRA ĐIỆN THOẠI ===" -ForegroundColor Cyan
