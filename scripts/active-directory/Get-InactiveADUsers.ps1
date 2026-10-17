<#
.SYNOPSIS
    Finds enabled AD users who have not logged on for N days.

.DESCRIPTION
    Stale accounts are a security risk and a licensing cost. This only
    REPORTS them; it does not disable or delete anything. Accounts that
    have never logged on are included only if they were created more than
    N days ago, so brand-new accounts are not flagged by mistake.

    Requires the ActiveDirectory module (RSAT) and read access to AD.

.NOTES
    LastLogonDate comes from the lastLogonTimestamp attribute, which
    replicates only every ~14 days, so treat results as approximate.

.PARAMETER DaysInactive
    Inactivity threshold in days. Default 90.

.PARAMETER CsvPath
    Optional. Also export the results to this CSV file.

.EXAMPLE
    .\Get-InactiveADUsers.ps1 -DaysInactive 120 -CsvPath ..\..\reports\inactive.csv
#>
#Requires -Modules ActiveDirectory
[CmdletBinding()]
param(
    [ValidateRange(1, 3650)][int]$DaysInactive = 90,
    [string]$CsvPath
)

. (Join-Path $PSScriptRoot '..\..\lib\Common.ps1')

$cutoff = (Get-Date).AddDays(-$DaysInactive)

# Filter server-side where possible (Enabled), then compare dates locally.
$results = Get-ADUser -Filter 'Enabled -eq $true' `
        -Properties LastLogonDate, WhenCreated, Department -ErrorAction Stop |
    Where-Object {
        ($_.LastLogonDate -and $_.LastLogonDate -lt $cutoff) -or
        (-not $_.LastLogonDate -and $_.WhenCreated -lt $cutoff)
    } |
    Select-Object Name, SamAccountName, Department, LastLogonDate, WhenCreated,
        @{ n = 'NeverLoggedOn'; e = { -not $_.LastLogonDate } }

Write-Log "$(@($results).Count) enabled user(s) inactive for more than $DaysInactive days"

if ($CsvPath) { $results | Export-ReportCsv -Path $CsvPath }
$results
