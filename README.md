# WinQuickTweak

WinQuickTweak is a lightweight PowerShell script that applies common Windows configuration tweaks from a single file. It is designed to simplify post-installation setup and eliminate repetitive manual configuration.

The script modifies only built-in Windows settings and does not require any third-party software.

## Features

- Disable Bing Search integration in Windows Search
- Disable Windows Widgets
- Enable the High Performance power plan
- Synchronize system time
- Configure the system timezone
- Single-file PowerShell implementation
- No external dependencies

## Requirements

- Windows 10 or Windows 11
- Windows PowerShell 5.1 or PowerShell 7+
- Administrator privileges

## Direct Execution

The script can be executed directly from GitHub without cloning the repository.

```powershell
irm https://raw.githubusercontent.com/samuelkranec/WinQuickTweak/main/WinQuickTweak.ps1 | iex
```

## Usage

Clone the repository:

```powershell
git clone https://github.com/samuelkranec/WinQuickTweak.git
cd WinQuickTweak
```

Alternatively, download **WinQuickTweak.ps1** directly from the repository.

Run PowerShell as Administrator.

Apply all tweaks:

```powershell
.\WinQuickTweak.ps1 -All
```

Disable Bing Search:

```powershell
.\WinQuickTweak.ps1 -DisableBing
```

Disable Windows Widgets:

```powershell
.\WinQuickTweak.ps1 -DisableWidgets
```

Enable the High Performance power plan:

```powershell
.\WinQuickTweak.ps1 -HighPerf
```

Synchronize system time and configure the timezone:

```powershell
.\WinQuickTweak.ps1 -SyncTime
```

Run multiple tweaks:

```powershell
.\WinQuickTweak.ps1 -DisableBing -DisableWidgets -HighPerf
```

## What the Script Changes

The script modifies standard Windows configuration using built-in tools.

- Windows Search settings
- Windows Widgets configuration
- Power plan selection
- Windows Time service
- System timezone

The script does not:

- Install software
- Remove system files
- Download external content
- Create scheduled tasks
- Run background services

## License

This project is licensed under the MIT License.
