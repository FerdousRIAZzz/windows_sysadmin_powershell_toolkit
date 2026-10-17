<#
.SYNOPSIS
    Reports free space on local fixed disks, with Warning/Critical status.

.DESCRIPTION
    Returns objects, so you can filter, sort or export them yourself.

.PARAMETER WarningPercent
    Free-space percentage below which a volume is 'Warning'. Default 20.

.PARAMETER CriticalPercent
    Free-space percentage below which a volume is 'Critical'. Default 10.

.PARAMETER CsvPath
    Optional. Also export the results to this CSV file.

.EXAMPLE
    .\Get-DiskSpaceReport.ps1

.EXAMPLE
    .\Get-DiskSpaceReport.ps1 -WarningPercent 15 | Where-Object Status -ne 'OK'
#>
[CmdletBinding()]
param(
    [ValidateRange(2, 99)][int]$WarningPercent = 20,
    [ValidateRange(1, 98)][int]$CriticalPercent = 10,
    [string]$CsvPath
)

. (Join-Path $PSScriptRoot '..\..\lib\Common.ps1')

if ($CriticalPercent -ge $WarningPercent) {
    throw '-CriticalPercent must be lower than -WarningPercent.'
}

# DriveType=3 means local fixed disks (skips CD-ROMs, network drives, USB).
$disks = Get-CimInstance -ClassName Win32_LogicalDisk -Filter 'DriveType=3' -ErrorAction Stop

$results = foreach ($d in $disks) {
    # Guard against a zero-size volume (would be divide-by-zero).
    $pctFree = if ($d.Size -gt 0) { [math]::Round(($d.FreeSpace / $d.Size) * 100, 1) } else { 0 }

    $status = if     ($pctFree -lt $CriticalPercent) { 'Critical' }
              elseif ($pctFree -lt $WarningPercent)  { 'Warning' }
              else                                   { 'OK' }

    [pscustomobject]@{
        Drive       = $d.DeviceID
        SizeGB      = [math]::Round($d.Size / 1GB, 1)
        FreeGB      = [math]::Round($d.FreeSpace / 1GB, 1)
        PercentFree = $pctFree
        Status      = $status
    }
}

$flagged = @($results | Where-Object Status -ne 'OK').Count
if ($flagged -gt 0) { Write-Log "$flagged volume(s) need attention" -Level WARN }
else                { Write-Log 'All volumes above thresholds' }

if ($CsvPath) { $results | Export-ReportCsv -Path $CsvPath }
$results
