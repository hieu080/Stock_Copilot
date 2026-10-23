. "C:\Users\hieu.pt\IdeaProjects\stock-copilot\engine\deep_analysis.ps1"
$token = "8862702138:AAHEUnRXYNdmeSqe7kUQ9n6VMXiI9B_H828"
$headers = @{"User-Agent" = "Mozilla/5.0"}

function Send-Reply($c, $t) {
    Write-Host "Send-Reply called with length: $($t.Length)"
    $body = @{ chat_id = $c; text = $t; parse_mode = "HTML" } | ConvertTo-Json
    try {
        Invoke-RestMethod -Uri "https://api.telegram.org/bot$token/sendMessage" -Method Post -ContentType "application/json; charset=utf-8" -Body $body
        Write-Host "Telegram sent successfully!"
    } catch {
        Write-Host "Lỗi gửi: $_"
    }
}

function Get-LivePrice($tk) { return 18900 }
function Get-Ticker-Metadata($tk) {
    return [PSCustomObject]@{
        Ticker = $tk
        CompanyName = "Tong CTCP Khoan Dau Khi"
        Sector = "Dau khi"
    }
}

Handle-DeepAnalysis "6428436481" "PVD"
