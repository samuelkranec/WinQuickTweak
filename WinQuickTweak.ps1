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
    
    # FIX (Issue #1): Dynamically check if running via local file or remote expression string
    $ArgumentList = if (![string]::IsNullOrEmpty($PSCommandPath) -and (Test-Path $PSCommandPath)) {
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
        if (-not (Test-Path $Path)) { 
            New-Item -Path $Path -Force | Out-Null 
        }
        
        $current = (Get-ItemProperty -Path $Path -Name $Name -ErrorAction SilentlyContinue).$Name
        if ($null -ne $current -and $current -eq $Value) {
            Write-Host "[SKIP] $Description (already set)" -ForegroundColor Yellow
            return
        }
        
        # FIX (Issue #3): Replaced invalid 'Set-ItemProperty -Type' with 'New-ItemProperty -PropertyType -Force'
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
    Set-Service -Name W32Time -StartupType Automatic -ErrorAction Stop
    $w32time = Get-Service -Name W32Time
    if ($w32time.Status -ne 'Running') { 
        Start-Service -Name W32Time -ErrorAction Stop
        Start-Sleep -Seconds 2
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
    
    $listOutput = powercfg /list
    
    # FIX (Issue #2): Track actual created runtime instances instead of hardcoding template GUID pointers
    if ($listOutput -match 'Ultimate Performance') {
        $matchedLine = $listOutput | Where-Object { $_ -match 'Ultimate Performance' } | Select-Object -First 1
        if ($matchedLine -match '([0-9a-fA-F-]{36})') {
            $targetGuid = $Matches[1]
        }
    }
    elseif (-not ($listOutput -match $ultimateGuid)) {
        $dupOutput = powercfg /duplicatescheme $ultimateGuid 2>&1
        if ($LASTEXITCODE -eq 0 -and $dupOutput -match '([0-9a-fA-F-]{36})') {
            $targetGuid = $Matches[1]
        } else {
            # Secondary fallback if the system hardware architecture restricts Ultimate templates
            if ($listOutput -match 'High Performance') {
                $matchedLine = $listOutput | Where-Object { $_ -match 'High Performance' } | Select-Object -First 1
                if ($matchedLine -match '([0-9a-fA-F-]{36})') { $targetGuid = $Matches[1] }
            } else {
                $targetGuid = $highPerfGuid
            }
        }
    }
    
    $activeOutput = powercfg /getactivescheme
    $activeGuid   = if ($activeOutput -match '([0-9a-fA-F-]{36})') { $Matches[1] } else { '' }
    $planName     = if ($targetGuid -eq $highPerfGuid -or $listOutput -match "$targetGuid.*High Performance") { 'High Performance' } else { 'Ultimate Performance' }
    
    if ($activeGuid -ieq $targetGuid) {
        Write-Host "[SKIP] Power plan already set to $planName" -ForegroundColor Yellow
    } else {
        powercfg /setactive $targetGuid
        Write-Host "[ OK ] Power plan set to $planName" -ForegroundColor Green
    }
}
catch {
    Write-Host "[FAIL] Power plan - $($_.Exception.Message)" -ForegroundColor Red
}

# 4. Remove Bing Search from Start Menu
Set-RegistryTweak 'HKCU:\Software\Policies\Microsoft\Windows\Explorer' 'DisableSearchBoxSuggestions' 1 'Bing Start menu search disabled'
Set-RegistryTweak 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Search' 'BingSearchEnabled' 0 'Bing Search backend suppressed'

# --- Apply changes: restart Explorer once, at the very end ---
Write-Host "`nRestarting Explorer..." -ForegroundColor Cyan
Stop-Process -Name explorer -Force -ErrorAction SilentlyContinue
Start-Sleep -Seconds 1.5

if (-not (Get-Process -Name explorer -ErrorAction SilentlyContinue)) {
    Start-Process explorer.exe
}

Write-Host "=== Done ===`n" -ForegroundColor Cyan
