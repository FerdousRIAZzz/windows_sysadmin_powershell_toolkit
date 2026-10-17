<#
.SYNOPSIS
    Starts services that are set to Automatic but are not running.

.DESCRIPTION
    This is the CHANGE-MAKING half of the pair (Get-ServiceHealth is the
    read-only half). It supports -WhatIf and -Confirm through
    SupportsShouldProcess, and only touches services whose start type is
    Automatic. Accepts service names from the pipeline.

.PARAMETER Name
    Service short name(s). Also accepted from pipeline objects that have a
    Name property (such as the output of Get-ServiceHealth).

.EXAMPLE
    .\Repair-StoppedService.ps1 -Name Spooler -WhatIf

.EXAMPLE
    .\Get-ServiceHealth.ps1 | Where-Object Health -eq 'Unhealthy' | .\Repair-StoppedService.ps1
#>
[CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'Medium')]
param(
    [Parameter(Mandatory, Position = 0, ValueFromPipelineByPropertyName)]
    [Alias('ServiceName')]
    [string[]]$Name
)

begin {
    . (Join-Path $PSScriptRoot '..\..\lib\Common.ps1')
}

process {
    foreach ($n in $Name) {
        $svc = Get-Service -Name $n -ErrorAction SilentlyContinue

        if (-not $svc) {
            Write-Log "Service '$n' not found" -Level WARN
            [pscustomobject]@{ Name = $n; Action = 'Skipped'; Detail = 'Not found' }
            continue
        }
        if ($svc.Status -eq 'Running') {
            [pscustomobject]@{ Name = $n; Action = 'Skipped'; Detail = 'Already running' }
            continue
        }
        if ($svc.StartType -ne 'Automatic') {
            Write-Log "$n is not set to Automatic; leaving it alone" -Level WARN
            [pscustomobject]@{ Name = $n; Action = 'Skipped'; Detail = "StartType is $($svc.StartType)" }
            continue
        }

        # ShouldProcess powers -WhatIf / -Confirm. It is called only right
        # before a real change, never for read-only work.
        if ($PSCmdlet.ShouldProcess($n, 'Start service')) {
            try {
                Start-Service -Name $n -ErrorAction Stop
                Write-Log "$n started"
                [pscustomobject]@{ Name = $n; Action = 'Started'; Detail = $null }
            }
            catch {
                Write-Log "Failed to start $n : $($_.Exception.Message)" -Level ERROR
                [pscustomobject]@{ Name = $n; Action = 'Failed'; Detail = $_.Exception.Message }
            }
        }
        else {
            [pscustomobject]@{ Name = $n; Action = 'Skipped'; Detail = '-WhatIf or declined' }
        }
    }
}
