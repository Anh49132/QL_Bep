param()
$ErrorActionPreference = 'Stop'
$repoRoot = Split-Path $PSScriptRoot -Parent
$logRoot = Join-Path $repoRoot '.artifacts/week1'
New-Item -ItemType Directory -Force -Path $logRoot | Out-Null
$dotnetPath = (Get-Command dotnet -ErrorAction Stop).Source
$previousUrls = $env:ASPNETCORE_URLS
$previousGenericUrls = $env:URLS
$previousApiUrl = $env:Services__OrderApiUrl

try {
    foreach ($name in @('Order.Api', 'Kitchen.Worker', 'Notification.Service', 'Restaurant.Web')) {
        $projectRoot = Join-Path $repoRoot "src/$name"
        $dll = "bin/Debug/net10.0/$name.dll"
        $stdout = Join-Path $logRoot "$name.stdout.log"
        $stderr = Join-Path $logRoot "$name.stderr.log"
        # Kiểm tra cấu hình mặc định, không kế thừa URL tùy chỉnh từ Terminal.
        $env:ASPNETCORE_URLS = $null
        $env:URLS = $null
        $env:Services__OrderApiUrl = $null
        $process = Start-Process -FilePath $dotnetPath -ArgumentList $dll -WorkingDirectory $projectRoot -WindowStyle Hidden -PassThru -RedirectStandardOutput $stdout -RedirectStandardError $stderr
        try {
            $ready = $false
            for ($attempt = 0; $attempt -lt 40; $attempt++) {
                if ($process.HasExited) { throw "$name thoát sớm. Xem $stderr" }
                if ($name -eq 'Kitchen.Worker') {
                    $ready = (Get-Content $stdout -Raw -ErrorAction SilentlyContinue) -match 'Application started'
                } else {
                    $port = switch ($name) { 'Order.Api' { 5101 }; 'Notification.Service' { 5102 }; 'Restaurant.Web' { 5103 } }
                    try {
                        $health = Invoke-RestMethod "http://localhost:$port/health" -TimeoutSec 1
                        $ready = $health.service -eq $name -and $health.status -eq 'ok'
                    } catch { $ready = $false }
                }
                if ($ready) { break }
                Start-Sleep -Milliseconds 250
            }
            if (-not $ready) { throw "$name chưa sẵn sàng. Xem $logRoot" }
            if ($name -eq 'Restaurant.Web') {
                $page = Invoke-WebRequest 'http://localhost:5103/' -UseBasicParsing
                $html = [System.Text.Encoding]::UTF8.GetString($page.RawContentStream.ToArray())
                if ($page.StatusCode -ne 200 -or $html -notmatch 'Bếp Nhà') { throw 'Trang web không đúng nội dung' }
                $config = Invoke-RestMethod 'http://localhost:5103/config'
                if ($config.orderApiUrl -ne 'http://localhost:5101' -or $config.notificationUrl -ne 'http://localhost:5102') { throw 'URL dịch vụ không đúng' }
            } elseif ($name -ne 'Kitchen.Worker') {
                $root = Invoke-RestMethod "http://localhost:$port/"
                if ($root.service -ne $name -or $root.week -ne 1) { throw 'Endpoint gốc không đúng' }
            }
            Write-Output "PASS: $name khởi động độc lập và phản hồi đúng."
        } finally {
            if (-not $process.HasExited) { Stop-Process -Id $process.Id; $process.WaitForExit() }
        }
    }
} finally {
    $env:ASPNETCORE_URLS = $previousUrls
    $env:URLS = $previousGenericUrls
    $env:Services__OrderApiUrl = $previousApiUrl
}
