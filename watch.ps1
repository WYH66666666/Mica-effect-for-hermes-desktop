# Frost Underlay watcher - keep the overlay glued to a target window.
# Loop every 2s: target up -> ensure overlay+FrostTracker running; target gone -> close them.
# Heartbeat: touch watch.heartbeat every cycle so an external watchdog can detect death.
# Single-instance lock with CIM type filter (ErrorRecord poison-pipe workaround).
# NOTE: keep this file pure ASCII - PowerShell 5.1 reads UTF-8 without BOM as ANSI,
# and multibyte comments can corrupt parsing.
param(
    [string]$Target = "",
    [string]$Electron = ""
)

$ErrorActionPreference = "SilentlyContinue"

# param defaults cannot use subexpressions; resolve here
if (-not $Target) {
    if ($env:FROST_TARGET) { $Target = $env:FROST_TARGET } else { $Target = "Hermes" }
}
if (-not $Electron) { $Electron = $env:ELECTRON_PATH }

$scriptDir = $PSScriptRoot
$main = Join-Path $scriptDir "main.js"
$log = Join-Path $scriptDir "watch.log"
$heartbeat = Join-Path $scriptDir "watch.heartbeat"

function Log($msg) {
    $line = "[$(Get-Date -Format 'HH:mm:ss')] $msg"
    Add-Content -Path $log -Value $line -Encoding UTF8
    Write-Output $line
}

function Touch-Heartbeat {
    if (-not (Test-Path $heartbeat)) {
        New-Item -ItemType File -Path $heartbeat -Force | Out-Null
    }
    [System.IO.File]::SetLastWriteTimeUtc($heartbeat, [DateTime]::UtcNow)
}

function Get-OverlayProc {
    # overlay = electron.exe with a main window, launched from a node_modules electron
    return Get-Process electron -ErrorAction SilentlyContinue |
        Where-Object { $_.MainWindowHandle -ne 0 -and $_.Path -like "*\node_modules\electron\dist\electron.exe" }
}

function Is-OverlayRunning {
    return @(Get-OverlayProc).Count -gt 0
}

function Stop-Overlay {
    Get-OverlayProc | ForEach-Object { Stop-Process -Id $_.Id -Force }
    Get-Process FrostTracker -ErrorAction SilentlyContinue | Stop-Process -Force
}

if (-not $Electron) {
    # probe common locations
    $candidates = @(
        (Join-Path $scriptDir "node_modules\electron\dist\electron.exe"),
        (Join-Path $scriptDir "..\node_modules\electron\dist\electron.exe"),
        "$env:LOCALAPPDATA\Programs\Electron\electron.exe"
    )
    foreach ($c in $candidates) {
        if (Test-Path $c) { $Electron = $c; break }
    }
}
if (-not $Electron -or -not (Test-Path $Electron)) {
    Log "electron not found; set ELECTRON_PATH"
}

Log "started, watching '$Target'..."

# single-instance lock: exit if another watch.ps1 is running
# NOTE: type filter required - Get-CimInstance can emit ErrorRecords whose message
# contains 'watch.ps1' and matches -like with an empty ProcessId (false positive)
$others = Get-CimInstance Win32_Process -Filter "Name='powershell.exe'" |
    Where-Object {
        $_ -is [Microsoft.Management.Infrastructure.CimInstance] -and
        $_.CommandLine -like '*watch.ps1*' -and $_.ProcessId -ne $PID
    }
if (@($others).Count -gt 0) {
    Log "another watcher running, exiting"
    exit 0
}

while ($true) {
    try {
        $targetProc = Get-Process $Target -ErrorAction SilentlyContinue |
            Where-Object { $_.MainWindowHandle -ne 0 } |
            Select-Object -First 1

        if ($targetProc) {
            $overlayOk = Is-OverlayRunning
            $trackerOk = @(Get-Process FrostTracker -ErrorAction SilentlyContinue).Count -gt 0
            if (-not $overlayOk -or -not $trackerOk) {
                # self-heal: overlay alive but tracker dead -> restart overlay (it respawns tracker)
                if ($overlayOk) {
                    Log "tracker missing, restarting overlay..."
                    Stop-Overlay
                } else {
                    Log "target up, launching overlay..."
                }
                if ($Electron) {
                    Start-Process -FilePath $Electron -ArgumentList $main -WorkingDirectory $scriptDir
                }
            }
        } else {
            if (Is-OverlayRunning) {
                Log "target gone, closing overlay..."
                Stop-Overlay
            }
        }
    } catch {
        Log "loop error: $($_.Exception.Message)"
    }

    Touch-Heartbeat
    Start-Sleep -Seconds 2
}
