# ==============================================================================
# STOCK COPILOT - AI HOST BRIDGE & CACHE GUARD DAEMON
# Connects Docker with Host Antigravity AI Engine (agy / Gemini)
# Port: 9998
# ==============================================================================

param(
    [int]$Port = 9998
)

$ErrorActionPreference = "Continue"
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8

$agyCandidates = @(
    "C:\Users\hieu.pt\AppData\Local\agy\bin\agy.exe",
    "C:\Users\agent-worker\AppData\Local\agy\bin\agy.exe",
    (Join-Path $env:LOCALAPPDATA "agy\bin\agy.exe")
)
$agyPath = $null
foreach ($cand in $agyCandidates) {
    if (Test-Path $cand) { $agyPath = $cand; break }
}

if (-not $agyPath) {
    Write-Host "[ERROR] agy.exe not found on system!" -ForegroundColor Red
    exit 1
}

$cacheRoot = Join-Path $env:LOCALAPPDATA "stock-copilot-cache"
$isolatedWorkDir = Join-Path $cacheRoot "sandbox"
if (-not (Test-Path $isolatedWorkDir)) {
    New-Item -ItemType Directory -Path $isolatedWorkDir -Force | Out-Null
}

function Purge-AgyCache {
    try {
        $targetDirs = @(
            (Join-Path $isolatedWorkDir ".gemini"),
            (Join-Path $isolatedWorkDir ".agents"),
            (Join-Path $isolatedWorkDir ".system_generated"),
            (Join-Path $env:USERPROFILE ".gemini\antigravity-cli\crashes"),
            (Join-Path $env:USERPROFILE ".gemini\antigravity-cli\cache")
        )
        foreach ($d in $targetDirs) {
            if (Test-Path $d) {
                Get-ChildItem -Path $d -Recurse -ErrorAction SilentlyContinue | Where-Object { 
                    $_.LastWriteTime -lt (Get-Date).AddMinutes(-30) 
                } | Remove-Item -Recurse -Force -ErrorAction SilentlyContinue
            }
        }
    } catch {}
}

Purge-AgyCache
$syncLock = [System.Object]::new()

Write-Host "==================================================================" -ForegroundColor Cyan
Write-Host "   STOCK COPILOT - AI HOST BRIDGE & CACHE GUARD (PORT $Port)      " -ForegroundColor Yellow
Write-Host "==================================================================" -ForegroundColor Cyan
Write-Host "Active AI Engine : Antigravity CLI ($agyPath)" -ForegroundColor Green
Write-Host "Sandbox WorkDir  : $isolatedWorkDir" -ForegroundColor Green
Write-Host "Cache Guard      : ACTIVE (Tự động dọn dẹp chống tràn RAM/Disk)" -ForegroundColor Green
Write-Host "Listener Port    : $Port (Docker host.docker.internal:$Port)" -ForegroundColor Green
Write-Host "------------------------------------------------------------------"

$listener = New-Object System.Net.Sockets.TcpListener([System.Net.IPAddress]::Any, $Port)
$listener.Server.SetSocketOption([System.Net.Sockets.SocketOptionLevel]::Socket, [System.Net.Sockets.SocketOptionName]::ReuseAddress, $true)
$listener.Start()

function Send-HttpResponse {
    param(
        [System.IO.Stream]$Stream,
        [int]$StatusCode = 200,
        [string]$StatusText = "OK",
        [string]$ContentType = "application/json; charset=utf-8",
        [byte[]]$BodyBytes = @()
    )
    $headerStr = "HTTP/1.1 $StatusCode $StatusText`r`n" +
                 "Content-Type: $ContentType`r`n" +
                 "Content-Length: $($BodyBytes.Length)`r`n" +
                 "Access-Control-Allow-Origin: *`r`n" +
                 "Access-Control-Allow-Methods: GET, POST, OPTIONS`r`n" +
                 "Access-Control-Allow-Headers: Content-Type`r`n" +
                 "Connection: close`r`n`r`n"
    $headerBytes = [System.Text.Encoding]::ASCII.GetBytes($headerStr)
    $Stream.Write($headerBytes, 0, $headerBytes.Length)
    if ($BodyBytes.Length -gt 0) {
        $Stream.Write($BodyBytes, 0, $BodyBytes.Length)
    }
    $Stream.Flush()
}

while ($true) {
    try {
        $client = $listener.AcceptTcpClient()
        $stream = $client.GetStream()

        # 1. Đọc Header byte-by-byte an toàn
        $rawHeaders = New-Object System.Collections.Generic.List[byte]
        while ($true) {
            $b = $stream.ReadByte()
            if ($b -lt 0) { break }
            $rawHeaders.Add([byte]$b)
            $len = $rawHeaders.Count
            if ($len -ge 4 -and $rawHeaders[$len-4] -eq 13 -and $rawHeaders[$len-3] -eq 10 -and $rawHeaders[$len-2] -eq 13 -and $rawHeaders[$len-1] -eq 10) {
                break
            }
        }
        if ($rawHeaders.Count -eq 0) {
            $client.Close()
            continue
        }

        $headerText = [System.Text.Encoding]::ASCII.GetString($rawHeaders.ToArray())
        $lines = $headerText -split "`r`n"
        $requestLine = $lines[0]
        $parts = $requestLine.Split(" ")
        $method = $parts[0]
        $path = if ($parts.Length -gt 1) { $parts[1] } else { "/" }

        $contentLength = 0
        if ($headerText -match "(?i)Content-Length:\s*(\d+)") {
            $contentLength = [int]$matches[1]
        }

        if ($method -eq "OPTIONS") {
            Send-HttpResponse -Stream $stream -StatusCode 200 -StatusText "OK"
            $client.Close()
            continue
        }

        if ($method -eq "GET" -and ($path -eq "/health" -or $path -eq "/ping")) {
            $respObj = @{
                status = "healthy"
                engine = "agy"
                port = $Port
                sandbox = $isolatedWorkDir
            }
            $bytes = [System.Text.Encoding]::UTF8.GetBytes(($respObj | ConvertTo-Json -Compress))
            Send-HttpResponse -Stream $stream -StatusCode 200 -BodyBytes $bytes
            $client.Close()
            continue
        }

        if ($method -eq "POST" -and $path -eq "/chat") {
            $body = ""
            if ($contentLength -gt 0) {
                $bodyBytes = New-Object byte[] $contentLength
                $bytesRead = 0
                while ($bytesRead -lt $contentLength) {
                    $r = $stream.Read($bodyBytes, $bytesRead, $contentLength - $bytesRead)
                    if ($r -le 0) { break }
                    $bytesRead += $r
                }
                $body = [System.Text.Encoding]::UTF8.GetString($bodyBytes, 0, $bytesRead).Trim()
                $body = $body.Trim([char]65279)
            }

            $reqJson = $null
            try { $reqJson = $body | ConvertFrom-Json } catch {}

            $promptText = if ($reqJson -and $reqJson.prompt) { $reqJson.prompt } else { "" }
            if (-not $promptText -and $reqJson -and $reqJson.message) {
                $userMsg = $reqJson.message
                $portContext = if ($reqJson.portfolio_context) { $reqJson.portfolio_context } else { "Chưa có cổ phiếu nào." }
                $histText = if ($reqJson.history) { ($reqJson.history -join "`n") } else { "Chưa có trao đổi trước." }
                
                $promptText = @"
Bạn là Stock Copilot, chuyên gia tư vấn đầu tư tài chính và quản lý tài sản chứng khoán Việt Nam sắc sảo, tận tâm.
Bạn đang trò chuyện trực tiếp trên Telegram với anh Phan (chủ tài khoản).

DỮ LIỆU TÀI SẢN THỰC TẾ CỦA ANH PHAN (TRONG DATABASE POSTGRESQL):
$portContext

LỊCH SỬ TRAO ĐỔI GẦN ĐÂY TRÊN TELEGRAM:
$histText

CÂU NÓI / THẮC MẮC MỚI NHẤT CỦA ANH PHAN:
"$userMsg"

YÊU CẦU TRẢ LỜI CỦA BẠN:
1. Đọc hiểu sâu sắc ngữ cảnh và liên kết chặt chẽ với những gì anh Phan ĐANG NẮM GIỮ.
2. Trả lời HOÀN TOÀN TỰ NHIÊN, sắc sảo như một Giám đốc Tư vấn Đầu tư Chứng khoán (Senior Portfolio Advisor), không máy móc.
3. Đưa ra so sánh cụ thể về: Ngành, Thị giá, Động lực tăng trưởng (Catalyst), Lợi nhuận kỳ vọng và Rủi ro.
4. Trả lời bằng tiếng Việt, định dạng HTML Telegram (dùng <b>in đậm</b>, <i>in nghiêng</i>, các bullet point gạch đầu dòng rõ ràng, có emoji trực quan). Độ dài vừa phải từ 3 đến 5 đoạn súc tích.
"@
            }

            if (-not $promptText) {
                $errBytes = [System.Text.Encoding]::UTF8.GetBytes('{"error":"Thiếu prompt hoặc message"}')
                Send-HttpResponse -Stream $stream -StatusCode 400 -BodyBytes $errBytes
                $client.Close()
                continue
            }

            # Khóa luồng đơn (Single-flight mutex) chống tràn RAM
            [System.Threading.Monitor]::Enter($syncLock)
            $aiReply = ""
            try {
                $escapedPrompt = '"' + ($promptText.Replace('"', '\"')) + '"'

                $psi = New-Object System.Diagnostics.ProcessStartInfo
                $psi.FileName = $agyPath
                $psi.WorkingDirectory = "c:\AI-Software-Department"
                $psi.Arguments = "--dangerously-skip-permissions --disable-slash-commands --effort low --print $escapedPrompt"
                $psi.UseShellExecute = $false
                $psi.RedirectStandardOutput = $true
                $psi.RedirectStandardError = $true
                $psi.StandardOutputEncoding = [System.Text.Encoding]::UTF8
                $psi.StandardErrorEncoding = [System.Text.Encoding]::UTF8

                $proc = [System.Diagnostics.Process]::Start($psi)
                $stdoutTask = $proc.StandardOutput.ReadToEndAsync()
                $stderrTask = $proc.StandardError.ReadToEndAsync()

                $finished = $proc.WaitForExit(35000)
                if (-not $finished) {
                    Write-Host "[WARN] agy vượt quá 35s - dừng tiến trình..." -ForegroundColor Yellow
                    try { $proc.Kill($true) } catch {}
                    $aiReply = "⚠️ Hệ thống AI phản hồi quá thời gian cho phép (timeout 35s). Xin vui lòng thử lại câu hỏi ngắn gọn hơn!"
                } else {
                    $stdout = $stdoutTask.Result
                    $stderr = $stderrTask.Result
                    $aiReply = $stdout.Trim()
                    if (-not $aiReply) { $aiReply = $stderr.Trim() }
                }

                Purge-AgyCache
            }
            catch {
                Write-Host "[ERROR] Lỗi thực thi agy: $_" -ForegroundColor Red
                $aiReply = "⚠️ Lỗi kết nối não bộ AI: $_"
            }
            finally {
                [System.Threading.Monitor]::Exit($syncLock)
            }

            $respObj = @{ reply = $aiReply }
            $respJson = $respObj | ConvertTo-Json -Compress
            $respBytes = [System.Text.Encoding]::UTF8.GetBytes($respJson)
            Send-HttpResponse -Stream $stream -StatusCode 200 -BodyBytes $respBytes
            $client.Close()
            continue
        }

        # Mặc định 404
        $notFoundBytes = [System.Text.Encoding]::UTF8.GetBytes('{"error":"Not Found"}')
        Send-HttpResponse -Stream $stream -StatusCode 404 -BodyBytes $notFoundBytes
        $client.Close()
    }
    catch {
        # Client disconnect handler
    }
}