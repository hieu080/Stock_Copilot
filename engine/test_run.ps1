$token = "8862702138:AAHEUnRXYNdmeSqe7kUQ9n6VMXiI9B_H828"
function Send-Reply($cid, $t) {
    Write-Host "--- TELEGRAM OUTPUT ---" -ForegroundColor Cyan
    Write-Host $t
}
. "C:\Users\hieu.pt\IdeaProjects\stock-copilot\engine\agy_chat.ps1"

$testHist = @(
    "Anh Phan: Có 500k thì nên đầu tư gì để có lời?",
    "Stock Copilot: Gợi ý 3 cơ hội: MBB (25 cp @ 19.8k), HPG (23 cp @ 21.3k), FPT (8 cp @ 57.5k)."
)
$testMsg = "Tại sao không đầu tư PVD mà lại là 3 cái này, tôi đã có mấy loại cổ phiếu này rồi."
$ans = Invoke-AgyConversationalAdvisor "6428436481" $testMsg $testHist