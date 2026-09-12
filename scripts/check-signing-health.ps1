<#
.SYNOPSIS
    Checks whether the sideloaded apps on Akshat's iPhone are actually being re-signed, and says so
    loudly when they are not.

.DESCRIPTION
    Free Apple provisioning expires after seven days. Sideloadly's daemon is what refreshes the
    apps; this script does not refresh anything and never drives Sideloadly's interface. Its only
    job is to prove the refresh happened, because a running daemon is not evidence  -  the daemon can
    sit there for days having done nothing, which is exactly how an app quietly stops launching.

    Success is defined narrowly and on purpose: Sideloadly's own record of a completed install
    moving forward, reported with the bundle ID and the new expiry. A running process, a changed
    file timestamp, or this script exiting cleanly are all explicitly NOT success.

    The one honest limit: this reads Sideloadly's record that it finished signing, which implies a
    real round-trip with Apple, but it is not the phone confirming its profile. Keep opening the
    app occasionally; that is what covers the gap.
#>
[CmdletBinding()]
param(
    [string]$PythonPath,
    [string]$DatabasePath,
    [string]$StatePath = (Join-Path $env:LOCALAPPDATA 'AkshatOSSigningHealth\state.json'),
    [string]$LogPath = (Join-Path $env:LOCALAPPDATA 'AkshatOSSigningHealth\health.log'),
    # Sideloadly aims to refresh at 96 hours, leaving three days. Warn once that has clearly
    # been missed rather than at the first hour it is due.
    [int]$WarnDays = 3,
    [int]$CriticalDays = 2,
    [switch]$Quiet
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

$stateDirectory = Split-Path -Parent $StatePath
if (-not (Test-Path -LiteralPath $stateDirectory)) {
    New-Item -ItemType Directory -Path $stateDirectory -Force | Out-Null
}

function Write-Line {
    param([string]$Level, [string]$Message)
    $line = '{0} [{1}] {2}' -f (Get-Date -Format 'yyyy-MM-dd HH:mm:ss'), $Level, $Message
    Add-Content -LiteralPath $LogPath -Value $line -Encoding utf8
    Write-Output $line
}

function Show-Alert {
    param([string]$Title, [string]$Message, [switch]$Blocking)
    if ($Quiet) { return }
    try {
        Add-Type -AssemblyName System.Windows.Forms -ErrorAction Stop
        if ($Blocking) {
            # Deliberately blocking. An app that stops launching is the whole failure this guards
            # against, so the most serious state must not be dismissible by not looking.
            [System.Windows.Forms.MessageBox]::Show(
                $Message, $Title,
                [System.Windows.Forms.MessageBoxButtons]::OK,
                [System.Windows.Forms.MessageBoxIcon]::Warning) | Out-Null
        }
        else {
            $icon = New-Object System.Windows.Forms.NotifyIcon
            $icon.Icon = [System.Drawing.SystemIcons]::Warning
            $icon.BalloonTipTitle = $Title
            $icon.BalloonTipText = $Message
            $icon.Visible = $true
            $icon.ShowBalloonTip(20000)
            Start-Sleep -Seconds 12
            $icon.Dispose()
        }
    }
    catch {
        Write-Line 'WARN' "Could not show an alert: $($_.Exception.Message)"
    }
}

# --- locate Python -------------------------------------------------------------------------
if (-not $PythonPath) {
    $found = Get-Command python -ErrorAction SilentlyContinue
    if ($found) {
        $PythonPath = $found.Source
    }
    elseif (Test-Path -LiteralPath 'C:\Python314\python.exe') {
        $PythonPath = 'C:\Python314\python.exe'
    }
}
if (-not $PythonPath -or -not (Test-Path -LiteralPath $PythonPath)) {
    # A check that cannot run must shout, not pass quietly.
    Write-Line 'CRITICAL' 'Python was not found, so signing health cannot be checked at all.'
    Show-Alert -Title 'AkshatOS signing health' -Blocking `
        -Message "The signing health check could not run: Python was not found.`n`nUntil this is fixed, nothing is watching whether your apps are being re-signed."
    exit 2
}

$reader = Join-Path $PSScriptRoot 'read-signing-state.py'
if (-not (Test-Path -LiteralPath $reader)) {
    Write-Line 'CRITICAL' "Reader script missing at $reader"
    Show-Alert -Title 'AkshatOS signing health' -Blocking `
        -Message "The signing health check is incomplete: read-signing-state.py is missing."
    exit 2
}

# --- read Sideloadly's record --------------------------------------------------------------
$arguments = @($reader)
if ($DatabasePath) { $arguments += $DatabasePath }
$raw = & $PythonPath @arguments 2>&1
if ($LASTEXITCODE -ne 0) {
    Write-Line 'CRITICAL' "Reader failed: $raw"
    Show-Alert -Title 'AkshatOS signing health' -Blocking `
        -Message "The signing health check failed to read Sideloadly's records.`n`n$raw"
    exit 2
}

try { $report = $raw | ConvertFrom-Json }
catch {
    Write-Line 'CRITICAL' "Reader returned unusable output: $raw"
    exit 2
}

if (-not $report.ok) {
    Write-Line 'CRITICAL' "Could not read Sideloadly: $($report.error)"
    Show-Alert -Title 'AkshatOS signing health' -Blocking `
        -Message "Could not read Sideloadly's records.`n`n$($report.error)"
    exit 2
}

# --- compare against what was true last time -----------------------------------------------
$previous = @{}
if (Test-Path -LiteralPath $StatePath) {
    try {
        (Get-Content -LiteralPath $StatePath -Raw | ConvertFrom-Json).PSObject.Properties |
            ForEach-Object { $previous[$_.Name] = $_.Value }
    }
    catch { Write-Line 'WARN' 'Previous state was unreadable; treating this run as the first.' }
}

$current = @{}
$worst = 0            # 0 healthy, 1 warn, 2 critical
$headlines = @()

foreach ($app in $report.apps) {
    $name = $app.name
    $days = if ($null -ne $app.daysLeft) { [double]$app.daysLeft } else { [double]::NaN }
    $current[$name] = $app.lastSigned

    # A retired app keeps a row in Sideloadly forever and "expires" every seven days with nothing
    # on the phone for it to affect. Logged so the record is not silently dropped, never alarmed -
    # read-signing-state.py documents which identities this covers and why.
    if ($app.retired) {
        Write-Line 'RETIRED' ("{0} ({1}) is retired; ignoring its expiry" -f $name, $app.bundleID)
        continue
    }

    # A refresh actually happening is the only thing reported as success, and it is reported
    # with the identity and the new expiry rather than as a bare "ok".
    if ($previous.ContainsKey($name) -and $previous[$name] -ne $app.lastSigned) {
        Write-Line 'REFRESHED' ("{0} ({1}) re-signed  -  now expires {2}" -f `
            $name, $app.bundleID, $app.expires)
    }

    if ($app.failures -gt 0 -or $app.lastError) {
        $worst = 2
        $headlines += "$name reported an error: $($app.lastError)"
        Write-Line 'CRITICAL' ("{0}: {1} failure(s), last error '{2}'" -f `
            $name, $app.failures, $app.lastError)
        continue
    }

    if ([double]::IsNaN($days)) {
        Write-Line 'WARN' "$name has no usable install date; cannot judge its expiry."
        if ($worst -lt 1) { $worst = 1 }
        continue
    }

    $ever = if ($app.PSObject.Properties.Name -contains 'everRefreshed') { $app.everRefreshed } else { $null }
    $note = if ($ever -eq $false) { ' (never refreshed since first install)' } else { '' }

    if ($days -lt 0) {
        $worst = 2
        $headlines += ("{0} EXPIRED {1:N1} days ago" -f $name, [math]::Abs($days))
        Write-Line 'CRITICAL' ("{0} ({1}) expired {2:N1} days ago{3}" -f `
            $name, $app.bundleID, [math]::Abs($days), $note)
    }
    elseif ($days -le $CriticalDays) {
        $worst = 2
        $headlines += ("{0} expires in {1:N1} days" -f $name, $days)
        Write-Line 'CRITICAL' ("{0} ({1}) expires in {2:N1} days{3}" -f `
            $name, $app.bundleID, $days, $note)
    }
    elseif ($days -le $WarnDays) {
        if ($worst -lt 1) { $worst = 1 }
        $headlines += ("{0} expires in {1:N1} days" -f $name, $days)
        Write-Line 'WARN' ("{0} ({1}) expires in {2:N1} days{3}" -f `
            $name, $app.bundleID, $days, $note)
    }
    else {
        Write-Line 'OK' ("{0} ({1}) expires in {2:N1} days{3}" -f `
            $name, $app.bundleID, $days, $note)
    }
}

$current | ConvertTo-Json -Depth 4 | Set-Content -LiteralPath $StatePath -Encoding utf8

if ($worst -eq 2) {
    Show-Alert -Title 'AkshatOS signing  -  act now' -Blocking -Message @"
$($headlines -join "`n")

Sideloadly's daemon has not re-signed these in time.

Open Sideloadly and use Refresh All Apps Manually, with the iPhone unlocked and on the same
Wi-Fi. If that does not work, connect it over USB and install the cached IPA again.

Do NOT uninstall the app  -  that deletes its data.
"@
}
elseif ($worst -eq 1) {
    Show-Alert -Title 'AkshatOS signing' -Message ($headlines -join "`n")
}

exit $worst
