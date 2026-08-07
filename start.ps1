# Frost Underlay 一键启动（幂等，防双开）
# 用法: powershell -ExecutionPolicy Bypass -File start.ps1 [-Target Hermes]
param(
    [string]$Target = ""
)
$ErrorActionPreference = "SilentlyContinue"
$scriptDir = $PSScriptRoot
if (-not $Target) { $Target = if ($env:FROST_TARGET) { $env:FROST_TARGET } else { "Hermes" } }

# 找 electron
$electron = $env:ELECTRON_PATH
if (-not $electron) {
    $candidates = @(
        (Join-Path $scriptDir "node_modules\electron\dist\electron.exe"),
        (Join-Path $scriptDir "..\node_modules\electron\dist\electron.exe"),
        "$env:LOCALAPPDATA\Programs\Electron\electron.exe"
    )
    foreach ($c in $candidates) { if (Test-Path $c) { $electron = $c; break } }
}
if (-not $electron) {
    Write-Host "electron not found. Install it or set ELECTRON_PATH. e.g.:" -ForegroundColor Yellow
    Write-Host "  npm install electron --save-dev" -ForegroundColor Cyan
    exit 1
}

# 清掉旧遮罩（防双开）
Get-Process electron -ErrorAction SilentlyContinue |
    Where-Object { $_.MainWindowHandle -ne 0 -and $_.Path -like "*\node_modules\electron\dist\electron.exe" } |
    ForEach-Object { Stop-Process -Id $_.Id -Force }
Get-Process FrostTracker -ErrorAction SilentlyContinue | Stop-Process -Force
Start-Sleep -Milliseconds 800

$env:FROST_TARGET = $Target
Start-Process -FilePath $electron -ArgumentList (Join-Path $scriptDir "main.js") -WorkingDirectory $scriptDir
Write-Host "Frost Underlay started, following '$Target'" -ForegroundColor Green
