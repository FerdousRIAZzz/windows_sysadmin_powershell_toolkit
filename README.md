# Windows SysAdmin PowerShell Toolkit

A collection of PowerShell scripts for everyday Windows system administration: inventory, monitoring, security auditing, Active Directory housekeeping, maintenance and backup.

> **Status: v0.1 (draft).** The scripts are written and statically checked, but have **not yet been tested in a live environment**. The "Tested" column below is updated only after a script has actually been run. Treat anything marked "Not yet" as unverified, and try it in a lab first.

## Design goals

The toolkit is being developed around a consistent set of conventions:

- **Objects first** - scripts return PowerShell objects, so you can filter, sort and pipe them. Add `-CsvPath` to also export a CSV.
- **Safe by default** - anything that changes the system uses `SupportsShouldProcess`, so `-WhatIf` and `-Confirm` work. Read-only and change-making tasks are separate scripts.
- **Honest failures** - an unreachable machine is reported with `Status = Unreachable` and the error, never silently dropped or shown as healthy.
- **Comment-based help** - run `Get-Help .\script.ps1 -Full` for usage and examples.
- **Optional, secret-free logging** - shared helper in `lib/Common.ps1`; no credentials are ever logged.

## Scripts

| Category | Script | What it does | Changes system? | Tested |
|---|---|---|---|---|
| Inventory | `Get-SystemInventory.ps1` | OS, CPU, RAM, model, uptime for one or many machines | No | Not yet |
| Monitoring | `Get-DiskSpaceReport.ps1` | Free space per volume with Warning / Critical status | No | Not yet |
| Monitoring | `Get-ServiceHealth.ps1` | Read-only service check (Healthy / Unhealthy / Stopped / NotFound) | No | Not yet |
| Monitoring | `Repair-StoppedService.ps1` | Starts Automatic services that are not running (`-WhatIf` supported) | Yes | Not yet |
| Security | `Get-FailedLogons.ps1` | Failed logons (Event ID 4625); optional grouping by source IP or account | No | Not yet |
| Security | `Get-LocalAdminAudit.ps1` | Local Administrators group members across machines | No | Not yet |
| Active Directory | `Get-InactiveADUsers.ps1` | Enabled accounts inactive for N days (report only) | No | Not yet |
| Active Directory | `New-BulkADUsers.ps1` | Creates users from a CSV, skips existing (`-WhatIf` supported) | Yes | Not yet |
| Maintenance | `Clear-TempFiles.ps1` | Removes old temp files from approved locations only (`-WhatIf` supported) | Yes | Not yet |
| Backup | `Backup-Folder.ps1` | Timestamped robocopy backup; never uses `/MIR` | Yes | Not yet |

## Compatibility

Only mark a version as supported after testing it.

| Script category | Environment | Verified |
|---|---|---|
| Local inventory, disk, services | Windows, PowerShell 5.1 and 7 | Not yet |
| Event log auditing | Windows, elevated session with Security log access | Not yet |
| Local admin audit (remote) | WinRM enabled and authorised access | Not yet |
| Active Directory | Domain environment, RSAT `ActiveDirectory` module (traditionally Windows PowerShell; may need the compatibility layer in PowerShell 7) | Not yet |

## Usage

```powershell
# From the repo root
Set-Location .\scripts\monitoring

# Read the built-in help
Get-Help .\Get-DiskSpaceReport.ps1 -Full

# Objects you can filter
.\Get-DiskSpaceReport.ps1 | Where-Object Status -ne 'OK'

# ...or export
.\Get-DiskSpaceReport.ps1 -CsvPath ..\..\reports\disks.csv

# Check, then preview a fix, then apply it
.\Get-ServiceHealth.ps1
.\Get-ServiceHealth.ps1 | Where-Object Health -eq 'Unhealthy' | .\Repair-StoppedService.ps1 -WhatIf
```

If script execution is blocked, check the current policy with `Get-ExecutionPolicy -List` and follow your organisation's approved PowerShell execution policy. Do not bypass centrally managed restrictions (Group Policy, AppLocker, WDAC).

## Repository layout

```
windows-sysadmin-powershell-toolkit/
├── .github/workflows/   # CI: PSScriptAnalyzer + Pester
├── lib/                 # shared helpers (Write-Log, Export-ReportCsv)
├── scripts/
│   ├── inventory/
│   ├── monitoring/
│   ├── security/
│   ├── active-directory/
│   ├── maintenance/
│   └── backup/
├── samples/             # sample input files (fictional data only)
├── screenshots/         # real output from tested runs
├── tests/               # Pester tests
├── PSScriptAnalyzerSettings.psd1
├── LICENSE
└── README.md
```

## Quality checks

```powershell
Install-Module PSScriptAnalyzer, Pester -Scope CurrentUser
Invoke-ScriptAnalyzer -Path . -Recurse -Settings .\PSScriptAnalyzerSettings.psd1
Invoke-Pester -Path .\tests
```

The same checks run automatically on every push through GitHub Actions.

## Safety notes

- Test in a lab or non-production environment first.
- Use `-WhatIf` before any script that creates, deletes, starts or copies things.
- `Clear-TempFiles.ps1` can only clean the user temp folder (and, optionally, `C:\Windows\Temp`); there is no free-form path parameter.
- `Backup-Folder.ps1` never deletes at the destination.
- Never commit real usernames, hostnames, passwords or exported reports. `reports/` and `*.log` are git-ignored; files in `samples/` are fictional.

## Roadmap

- [ ] Test every script and fill in the "Tested" and "Verified" columns
- [ ] Add real output screenshots
- [ ] `Get-WindowsUpdateStatus.ps1` - hotfixes, OS build and update status
- [ ] `Get-ScheduledTaskAudit.ps1` - task states, last results, failures
- [ ] Password-expiry notifier
- [ ] Azure VM inventory with the `Az` module
