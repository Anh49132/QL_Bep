# .env du an dung KEY=value tren tung dong, khong co dau nhay hay noi suy bien.
$ErrorActionPreference = 'Stop'
$envPath = Join-Path (Split-Path $PSScriptRoot -Parent) '.env'
if (-not (Test-Path -LiteralPath $envPath)) {
    throw 'Copy .env.example to .env and set your local database password first.'
}
foreach ($line in Get-Content -LiteralPath $envPath -Encoding UTF8) {
    $line = $line.Trim()
    if (-not $line -or $line.StartsWith('#')) { continue }
    $parts = $line -split '=', 2
    if ($parts.Count -ne 2 -or $parts[0] -notmatch '^[A-Za-z_][A-Za-z0-9_]*$') {
        throw 'Invalid .env format: use KEY=value without quotes or interpolation.'
    }
    Set-Item -LiteralPath "Env:$($parts[0])" -Value $parts[1]
}
Write-Output 'Loaded local environment (values hidden).'
