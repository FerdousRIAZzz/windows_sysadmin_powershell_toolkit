<#
.SYNOPSIS
    Collects a hardware/OS inventory from one or more Windows machines.

.DESCRIPTION
    Uses CIM (the modern replacement for WMI) to read OS, CPU, RAM, model
    and uptime. Returns one object per computer. Unreachable machines are
    NOT dropped: they come back with Status = 'Unreachable' and the error
    message, so a failure is never mistaken for a healthy machine.

.PARAMETER ComputerName
    One or more computer names. Defaults to the local machine.

.PARAMETER CsvPath
    Optional. If given, the results are also exported to this CSV file.

.EXAMPLE
    .\Get-SystemInventory.ps1

.EXAMPLE
    .\Get-SystemInventory.ps1 -ComputerName SRV01, SRV02 -CsvPath ..\..\reports\inventory.csv

.EXAMPLE
    .\Get-SystemInventory.ps1 -ComputerName SRV01, SRV02 | Where-Object Status -ne 'OK'
#>
[CmdletBinding()]
param(
    [string[]]$ComputerName = $env:COMPUTERNAME,
    [string]$CsvPath
)

. (Join-Path $PSScriptRoot '..\..\lib\Common.ps1')

$localNames = @($env:COMPUTERNAME, 'localhost', '.')

$results = foreach ($computer in $ComputerName) {
    # For the local machine we omit -ComputerName so CIM uses its fast
    # local path and does not need WinRM. Remote machines need WinRM.
    $cimArgs = @{ ErrorAction = 'Stop' }
    if ($computer -notin $localNames) { $cimArgs.ComputerName = $computer }

    try {
        Write-Log "Querying $computer"
        $os  = Get-CimInstance -ClassName Win32_OperatingSystem @cimArgs
        $cs  = Get-CimInstance -ClassName Win32_ComputerSystem  @cimArgs
        $cpu = Get-CimInstance -ClassName Win32_Processor       @cimArgs | Select-Object -First 1

        [pscustomobject]@{
            ComputerName = $computer
            Status       = 'OK'
            OS           = $os.Caption
            OSVersion    = $os.Version
            Manufacturer = $cs.Manufacturer
            Model        = $cs.Model
            CPU          = $cpu.Name
            RAM_GB       = [math]::Round($cs.TotalPhysicalMemory / 1GB, 1)
            UptimeDays   = [math]::Round(((Get-Date) - $os.LastBootUpTime).TotalDays, 1)
            Error        = $null
        }
    }
    catch {
        Write-Log "Could not query $computer : $($_.Exception.Message)" -Level ERROR
        # Same columns as the success row, so the CSV stays consistent.
        [pscustomobject]@{
            ComputerName = $computer
            Status       = 'Unreachable'
            OS = $null; OSVersion = $null; Manufacturer = $null; Model = $null
            CPU = $null; RAM_GB = $null; UptimeDays = $null
            Error        = $_.Exception.Message
        }
    }
}

if ($CsvPath) { $results | Export-ReportCsv -Path $CsvPath }
$results
