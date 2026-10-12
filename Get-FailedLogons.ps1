<#
.SYNOPSIS
    Reads failed logon attempts (Event ID 4625) from the Security log.

.DESCRIPTION
    Useful for spotting brute-force or password-spray activity. Returns
    event objects by default; use -GroupBy for counts per source IP or
    per account. Must be run as Administrator (Security log access).

    -MaxEvents caps how many (newest-first) events are read, because
    parsing each event's XML is slow on very large logs.

.PARAMETER Hours
    How far back to look. Default 24.

.PARAMETER MaxEvents
    Maximum number of events to read. Default 5000.

.PARAMETER GroupBy
    SourceIP or Account: return counts instead of individual events.

.EXAMPLE
    .\Get-FailedLogons.ps1 -Hours 6

.EXAMPLE
    .\Get-FailedLogons.ps1 -GroupBy SourceIP | Select-Object -First 5
#>
#Requires -RunAsAdministrator
[CmdletBinding()]
param(
    [ValidateRange(1, 720)][int]$Hours = 24,
    [ValidateRange(1, 100000)][int]$MaxEvents = 5000,
    [ValidateSet('SourceIP', 'Account')][string]$GroupBy
)

. (Join-Path $PSScriptRoot '..\..\lib\Common.ps1')

$filter = @{
    LogName   = 'Security'
    Id        = 4625
    StartTime = (Get-Date).AddHours(-$Hours)
}

try {
    # A hashtable filter is far faster than piping the log to Where-Object.
    # -ErrorAction Stop so real problems (permissions, missing log) are NOT hidden.
    $events = Get-WinEvent -FilterHashtable $filter -MaxEvents $MaxEvents -ErrorAction Stop
}
catch {
    # "No events found" is not a failure - it is the good outcome here.
    if ($_.FullyQualifiedErrorId -like 'NoMatchingEventsFound*') {
        Write-Log "No failed logons in the last $Hours hour(s)"
        return
    }
    throw
}

# Each event's useful fields live in its XML payload as named Data nodes.
$parsed = foreach ($e in $events) {
    $data = ([xml]$e.ToXml()).Event.EventData.Data
    [pscustomobject]@{
        Time      = $e.TimeCreated
        Account   = ($data | Where-Object Name -eq 'TargetUserName').'#text'
        SourceIP  = ($data | Where-Object Name -eq 'IpAddress').'#text'
        LogonType = ($data | Where-Object Name -eq 'LogonType').'#text'
    }
}

Write-Log "$(@($parsed).Count) failed logon(s) read from the last $Hours hour(s)" -Level WARN

if ($GroupBy) {
    $parsed | Group-Object -Property $GroupBy | Sort-Object Count -Descending |
        Select-Object Count, @{ n = $GroupBy; e = { $_.Name } }
}
else {
    $parsed
}
