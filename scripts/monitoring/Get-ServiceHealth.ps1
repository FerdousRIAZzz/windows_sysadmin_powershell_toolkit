<#
.SYNOPSIS
    Read-only check of important services. Changes nothing.

.DESCRIPTION
    Health values:
      Healthy   - running
      Unhealthy - NOT running, but set to start Automatically (needs attention)
      Stopped   - not running, and not meant to start automatically (normal)
      NotFound  - no such service on this machine

    To fix Unhealthy services, pipe the results into Repair-StoppedService.ps1.

.PARAMETER ServiceName
    Service short names to check.

.PARAMETER CsvPath
    Optional. Also export the results to this CSV file.

.EXAMPLE
    .\Get-ServiceHealth.ps1

.EXAMPLE
    .\Get-ServiceHealth.ps1 | Where-Object Health -eq 'Unhealthy' | .\Repair-StoppedService.ps1 -WhatIf
#>
[CmdletBinding()]
param(
    [string[]]$ServiceName = @('Spooler', 'W32Time', 'WinRM', 'EventLog'),
    [string]$CsvPath
)

. (Join-Path $PSScriptRoot '..\..\lib\Common.ps1')

$results = foreach ($name in $ServiceName) {
    # SilentlyContinue is acceptable here: the only expected error is
    # "service not found", which we handle explicitly just below.
    $svc = Get-Service -Name $name -ErrorAction SilentlyContinue

    if (-not $svc) {
        [pscustomobject]@{
            Name = $name; DisplayName = $null; Status = $null; StartType = $null; Health = 'NotFound'
        }
        continue
    }

    $health = if     ($svc.Status -eq 'Running')      { 'Healthy' }
              elseif ($svc.StartType -eq 'Automatic') { 'Unhealthy' }
              else                                    { 'Stopped' }

    [pscustomobject]@{
        Name        = $svc.Name
        DisplayName = $svc.DisplayName
        Status      = $svc.Status
        StartType   = $svc.StartType
        Health      = $health
    }
}

$bad = @($results | Where-Object Health -in 'Unhealthy', 'NotFound').Count
if ($bad -gt 0) { Write-Log "$bad service(s) need attention" -Level WARN }
else            { Write-Log 'All checked services look healthy' }

if ($CsvPath) { $results | Export-ReportCsv -Path $CsvPath }
$results
