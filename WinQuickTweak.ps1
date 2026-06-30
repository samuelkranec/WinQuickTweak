#Requires -Version 5.1
<#
.SYNOPSIS
    WinQuickTweak - taskbar widgets off, time resync, max performance power plan, Bing search off.
.NOTES
    irm https://raw.githubusercontent.com/samuelkranec/WinQuickTweak/main/WinQuickTweak.ps1 | iex
#>

$ScriptUrl = 'https://raw.githubusercontent.com/samuelkranec/WinQuickTweak/main/WinQuickTweak.ps1'

# --- Self-elevation: relaunch the script or command in an elevated process ---
$principal = New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())
if (-not $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Write-Host "Elevation required - requesting UAC..." -ForegroundColor Yellow
    
    # Check if executing from a local script file or an inline web-expression (irm | iex)
    $ArgumentList = if ($PSCommandPath) {
        @('-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', $PSCommandPath)
    } else {
        @('-NoProfile', '-ExecutionPolicy', 'Bypass', '-Command', "irm $ScriptUrl | iex")
    }

    try {
        Start-Process powershell.exe -Verb RunAs -ArgumentList $ArgumentList
    }
    catch {
        Write-Host "UAC prompt declined or failed. Re-run this command from an elevated prompt." -ForegroundColor Red
    }
    return
}

function Set-RegistryTweak {
    param(
        [Parameter(Mandatory=$true)][string]$Path,
        [Parameter(Mandatory=$true)][string]$Name,
        [Parameter(Mandatory=$true)][int]$Value,
        [Parameter(Mandatory=$true)][string]$Description
    )
    try {
        # Ensure the registry container path exists
        if (-not (Test-Path $Path)) { 
            New-Item -Path $Path -Force | Out-Null 
        }
        
        # Safe structural check for the existing item property
        $current = (Get-ItemProperty -Path $Path -Name $Name -ErrorAction SilentlyContinue).$Name
        if ($null -ne $current -and $current -eq $Value) {
            Write-Host "[SKIP] $Description (already set)" -ForegroundColor Yellow
            return
        }
        
        # FIX: Set-ItemProperty lacks a native type parameter in standard PowerShell core/desktop.
        # Using New-ItemProperty with -Force dynamically handles creation and mutation cleanly with exact types.
        New-ItemProperty -Path $Path -Name $Name -Value $Value -PropertyType DWord -Force | Out-Null
        Write-Host "[ OK ] $Description" -ForegroundColor Green
    }
    catch {
        Write-Host "[FAIL] $Description - $($_.Exception.Message)" -ForegroundColor Red
    }
}

Write-Host "`n=== WinQuickTweak ===" -ForegroundColor Cyan

# 1. Remove Taskbar Widgets
Set-RegistryTweak 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced' 'TaskbarDa' 0 'Taskbar widgets disabled'

# 2. Fix Time and Date
try {
    # Direct service correction; handles edge cases without risking missing .NET properties on legacy PS 5.1 hosts
    Set-Service -Name W32Time -StartupType Automatic -ErrorAction Stop
    
    $w32time = Get-Service -Name W32Time
    if ($w32time.Status -ne 'Running') { 
        Start-Service -Name W32Time -ErrorAction Stop
        Start-Sleep -Seconds 2 # Safety window for service control manager synchronization
    }
    
    $result = w32tm /resync /force 2>&1
    if ($LASTEXITCODE -eq 0) {
        Write-Host "[ OK ] Time synced via W32Time" -ForegroundColor Green
    }
    else {
        Write-Host "[WARN] Time sync failed: $result" -ForegroundColor Yellow
    }
}
catch {
    Write-Host "[FAIL] Time sync - $($_.Exception.Message)" -ForegroundColor Red
}

# 3. Maximize Performance Power Mode (Ultimate Performance, fallback to High Performance)
try {
    $ultimateGuid = 'e9a42b02-d5df-448d-aa00-03f14749eb61'
    $highPerfGuid = '8c5e7fda-e8bf-4a96-9a85-a6e23a8c635c'
    $targetGuid   = $ultimateGuid
    $listOutput   = powercfg /list

    if (-not ($listOutput -match $ultimateGuid)) {
        $dupOutput = powercfg /duplicatescheme $ultimateGuid 2>&1
        if ($LASTEXITCODE -eq 0) {
            # FIX: powercfg /duplicatescheme generates an entirely NEW unique instance GUID string.
            # We must isolate and parse the new runtime GUID instead of attempting to use the template GUID.
            if ($dupOutput -match '([0-9a-fA-F-]{36})') {
                $targetGuid = $Matches[1]
            }
        } else {
            $targetGuid = $highPerfGuid
        }
    } else {
        # If an Ultimate plan already exists, parse out its existing runtime GUID to avoid duplicate bloat
        $matchedLine = $listOutput | Where-Object { $_ -match 'Ultimate Performance' }
        if ($matchedLine -and $matchedLine -match '([0-9a-fA-F-]{36})') {
            $targetGuid = $Matches[1]
        }
    }

    $activeGuid = [regex]::Match(($listOutput | Out-String), '[0-9a-fA-F-]{36}').Value
    # Fetch accurate active scheme to match runtime profiles cleanly
    $activeGuid = [regex]::Match(((powercfg /getactivescheme) -join ' '), '[0-9a-fA-F-]{36}').Value
    $planName   = if ($targetGuid -eq $highPerfGuid) { 'High Performance' } else { 'Ultimate Performance' }

    if ($activeGuid -ieq $targetGuid) {
        Write-Host "[SKIP] Power plan already $planName" -ForegroundColor Yellow
    }
    else {
        powercfg /setactive $targetGuid
        Write-Host "[ OK ] Power plan set to $planName" -ForegroundColor Green
    }
}
catch {
    Write-Host "[FAIL] Power plan - $($_.Exception.Message)" -ForegroundColor Red
}

# 4. Remove Bing Search from Start Menu
Set-RegistryTweak 'HKCU:\Software\Policies\Microsoft\Windows\Explorer' 'DisableSearchBoxSuggestions' 1 'Bing Start menu search disabled'
# Supplementary fallback tweak for modern consumer builds to enforce the layout intent seamlessly
Set-RegistryTweak 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Search' 'BingSearchEnabled' 0 'Bing Search backend suppressed'

# --- Apply changes: restart Explorer once, at the very end ---
Write-Host "`nRestarting Explorer..." -ForegroundColor Cyan
Stop-Process -Name explorer -Force -ErrorAction SilentlyContinue

# Optimized sleep duration to give Winlogon breathing room to drop handle cycles cleanly
Start-Sleep -Seconds 1.5

if (-not (Get-Process -Name explorer -ErrorAction SilentlyContinue)) {
    Start-Process explorer.exe
}

Write-Host "=== Done ===`n" -ForegroundColor Cyan
