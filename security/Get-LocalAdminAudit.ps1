<#
.SYNOPSIS
    Lists members of the local Administrators group on one or more machines.

.DESCRIPTION
    A quick privilege audit: anyone unexpected in local Administrators is
    worth investigating. The group is looked up by its well-known SID
    (S-1-5-32-544), so it works on non-English Windows where the group has
    a different display name. Remote machines are queried over PowerShell
    remoting (WinRM). Unreachable machines come back with
    Status = 'Unreachable' instead of disappearing from the report.

    Known issue: Get-LocalGroupMember can fail on groups containing
    orphaned domain SIDs. Such machines are reported as failures.

.PARAMETER ComputerName
    One or more computer names. Defaults to the local machine.

.PARAMETER CsvPath
    Optional. Also export the results to this CSV file.

.EXAMPLE
    .\Get-LocalAdminAudit.ps1

.EXAMPLE
    .\Get-LocalAdminAudit.ps1 -ComputerName SRV01, SRV02 | Where-Object Status -ne 'OK'
#>
[CmdletBinding()]
param(
    [string[]]$ComputerName = $env:COMPUTERNAME,
    [string]$CsvPath
)

. (Join-Path $PSScriptRoot '..\..\lib\Common.ps1')

$localNames = @($env:COMPUTERNAME, 'localhost', '.')

# This block runs ON the target machine, so we define it once and reuse it.
$getAdmins = {
    Get-LocalGroupMember -SID 'S-1-5-32-544' -ErrorAction Stop |
        Select-Object Name, ObjectClass, PrincipalSource
}

$results = foreach ($computer in $ComputerName) {
    try {
        Write-Log "Auditing $computer"
        $members = if ($computer -in $localNames) {
            & $getAdmins
        } else {
            Invoke-Command -ComputerName $computer -ScriptBlock $getAdmins -ErrorAction Stop
        }

        foreach ($m in $members) {
            [pscustomobject]@{
                Computer        = $computer
                Status          = 'OK'
                Name            = $m.Name
                ObjectClass     = $m.ObjectClass
                PrincipalSource = $m.PrincipalSource
                Error           = $null
            }
        }
    }
    catch {
        Write-Log "Failed on $computer : $($_.Exception.Message)" -Level ERROR
        [pscustomobject]@{
            Computer = $computer; Status = 'Unreachable'
            Name = $null; ObjectClass = $null; PrincipalSource = $null
            Error = $_.Exception.Message
        }
    }
}

if ($CsvPath) { $results | Export-ReportCsv -Path $CsvPath }
$results
