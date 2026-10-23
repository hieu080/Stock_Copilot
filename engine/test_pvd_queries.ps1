$token = "8862702138:AAHEUnRXYNdmeSqe7kUQ9n6VMXiI9B_H828"
function Send-Reply($cid, $t) {
    Write-Host "--- AI RESPONSE ---" -ForegroundColor Cyan
    Write-Host $t
}
. "C:\Users\hieu.pt\IdeaProjects\stock-copilot\engine\agy_chat.ps1"

$hist = @(
    "Anh Phan: Có 500k nên đầu tư gì",
    "Stock Copilot: Gợi ý MBB, HPG, FPT...",
    "Anh Phan: Thế còn PVD thì sao, không tốt bằng à",
    "Stock Copilot: PVD rất tốt để đa dạng hóa ngành Dầu khí, hưởng lợi Lô B Ô Môn...",
    "Anh Phan: Vậy PVD để lướt sóng ngắn và trung hạn à",
    "Stock Copilot: Đúng vậy, PVD có tính chu kỳ và biên độ dao động mạnh...",
    "Anh Phan: Hãy phân tích PVD để tôi chuẩn bị các lệnh cho phiên tới"
)

$testQuery = "500k thì đầu tư vào bao nhiêu cho PVD"
Invoke-AgyConversationalAdvisor "6428436481" $testQuery $hist