param([switch]$RestartDatabase)
$ErrorActionPreference = 'Stop'
$repoRoot = Split-Path $PSScriptRoot -Parent
Push-Location $repoRoot
$apiProcess = $null
$sentinelId = $null
$previousUrls = $env:URLS
$previousAspUrls = $env:ASPNETCORE_URLS

function Invoke-DatabaseSql([string]$sql) {
    $result = $sql | docker compose exec -T postgres psql -U $env:POSTGRES_USER -d $env:POSTGRES_DB -v ON_ERROR_STOP=1 -At
    if ($LASTEXITCODE -ne 0) { throw 'PostgreSQL check failed.' }
    return $result
}

function Start-CheckedApi {
    $apiRoot = Join-Path $repoRoot 'src/Order.Api'
    $logs = Join-Path $repoRoot '.artifacts/week2'
    New-Item -ItemType Directory -Force -Path $logs | Out-Null
    $process = Start-Process -FilePath (Get-Command dotnet).Source -ArgumentList 'bin/Debug/net10.0/Order.Api.dll' -WorkingDirectory $apiRoot -WindowStyle Hidden -PassThru -RedirectStandardOutput (Join-Path $logs 'api.stdout.log') -RedirectStandardError (Join-Path $logs 'api.stderr.log')
    try {
        for ($attempt = 0; $attempt -lt 30; $attempt++) {
            if ($process.HasExited) { throw 'Order.Api exited. See .artifacts/week2.' }
            try {
                $health = Invoke-RestMethod 'http://localhost:5192/health' -TimeoutSec 1
                if ($health.service -eq 'Order.Api') { return $process }
            } catch {}
            Start-Sleep -Milliseconds 250
        }
        throw 'Order.Api did not become ready.'
    } catch {
        if (-not $process.HasExited) { Stop-Process -Id $process.Id; $process.WaitForExit() }
        throw
    }
}

try {
    & "$PSScriptRoot/Import-LocalEnvironment.ps1"
    $env:URLS = 'http://localhost:5192'
    $env:ASPNETCORE_URLS = $null
    docker compose up -d --wait postgres
    if ($LASTEXITCODE -ne 0) { throw 'PostgreSQL failed to start.' }
    dotnet ef database update --project src/Order.Api --no-build
    if ($LASTEXITCODE -ne 0) { throw 'Synchronous migration/seed failed.' }
    dotnet run --project src/Order.Api --no-build --no-launch-profile -- --migrate
    if ($LASTEXITCODE -ne 0) { throw 'Asynchronous migration/seed failed.' }
    Get-Content "$PSScriptRoot/week2-checks.sql" -Raw | docker compose exec -T postgres psql -U $env:POSTGRES_USER -d $env:POSTGRES_DB -v ON_ERROR_STOP=1 -At
    if ($LASTEXITCODE -ne 0) { throw 'Database constraints failed.' }

    $apiProcess = Start-CheckedApi
    $menu = Invoke-RestMethod 'http://localhost:5192/menu'
    if ($menu.Count -lt 10) { throw 'Expected at least 10 available seed items on a demo database.' }
    foreach ($item in $menu) {
        if (-not $item.name -or -not $item.category -or $null -eq $item.price -or -not $item.imageAlt -or -not $item.imageSource) { throw 'Missing menu fields.' }
    }
    $image = Invoke-WebRequest "http://localhost:5192$($menu[0].imageUrl)" -UseBasicParsing
    if ($image.StatusCode -ne 200 -or $image.Headers['Content-Type'] -notmatch 'image/svg') { throw 'Menu image unavailable.' }
    $baseline = $menu | ConvertTo-Json -Depth 5 -Compress
    $sentinelName = 'WEEK2-' + [Guid]::NewGuid().ToString('N')
    $insertSql = 'INSERT INTO "MenuItems" ("Name", "Price", "Category", "ImageUrl", "ImageAlt", "ImageSource", "IsAvailable") VALUES (''' + $sentinelName + ''', 123.45, ''CHECK'', ''/images/menu-placeholder.svg'', ''CHECK'', ''CHECK'', false) RETURNING "Id";'
    $sentinelId = [int](@(Invoke-DatabaseSql $insertSql)[0])
    if ($sentinelId -lt 1000) { throw 'Seed IDs conflict with generated IDs.' }
    $afterInsert = Invoke-RestMethod 'http://localhost:5192/menu'
    if ($afterInsert.id -contains $sentinelId -or ($afterInsert | ConvertTo-Json -Depth 5 -Compress) -ne $baseline) { throw 'Unavailable item leaked into menu.' }
    dotnet ef database update --project src/Order.Api --no-build
    if ($LASTEXITCODE -ne 0) { throw 'Repeated seed failed.' }
    if ([int](Invoke-DatabaseSql 'SELECT count(*) FROM "MenuItems" WHERE "Id" BETWEEN 1 AND 10;') -ne 10) { throw 'Seed duplicated menu rows.' }
    Write-Output 'PASS: /menu fields, image, availability filter and repeated seed.'

    Stop-Process -Id $apiProcess.Id
    $apiProcess.WaitForExit()
    $apiProcess = $null
    if ($RestartDatabase) {
        # Only the project's postgres service is recreated; keep the named volume.
        docker compose up -d --force-recreate --wait postgres
        if ($LASTEXITCODE -ne 0) { throw 'Database recreation failed.' }
    }
    $apiProcess = Start-CheckedApi
    $afterRestart = Invoke-RestMethod 'http://localhost:5192/menu'
    if (($afterRestart | ConvertTo-Json -Depth 5 -Compress) -ne $baseline) { throw 'Menu changed after restart.' }
    if ([int](Invoke-DatabaseSql ('SELECT count(*) FROM "MenuItems" WHERE "Id" = ' + $sentinelId + ' AND "Price" = 123.45 AND NOT "IsAvailable";')) -ne 1) { throw 'Non-seed sentinel lost after restart.' }
    Write-Output "PASS: application restart; database recreation=$RestartDatabase; non-seed data retained."
} finally {
    if ($null -ne $apiProcess -and -not $apiProcess.HasExited) { Stop-Process -Id $apiProcess.Id; $apiProcess.WaitForExit() }
    if ($null -ne $sentinelId) { Invoke-DatabaseSql ('DELETE FROM "MenuItems" WHERE "Id" = ' + [int]$sentinelId + ';') | Out-Null }
    $env:URLS = $previousUrls
    $env:ASPNETCORE_URLS = $previousAspUrls
    Pop-Location
}
