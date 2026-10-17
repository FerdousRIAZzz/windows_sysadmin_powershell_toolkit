<#
.SYNOPSIS
    Shared helpers, dot-sourced by the scripts in this repo.

.DESCRIPTION
    Write-Log       - timestamped, levelled console logging with an optional log file.
    Export-ReportCsv - pipeline-friendly CSV export that creates the folder if needed.

    SECURITY NOTE: never pass passwords, tokens or other secrets to Write-Log.
#>

function Write-Log {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$Message,
        [ValidateSet('INFO', 'WARN', 'ERROR')][string]$Level = 'INFO',
        [string]$LogFile   # optional: logging to disk only happens if this is supplied
    )

    # Format: 2026-10-11 20:15:03 [INFO] message
    $line = '{0} [{1}] {2}' -f (Get-Date -Format 'yyyy-MM-dd HH:mm:ss'), $Level, $Message

    # Write-Host goes to the information stream, NOT the output stream,
    # so log lines never get mixed into the objects a script returns.
    switch ($Level) {
        'INFO'  { Write-Host $line }
        'WARN'  { Write-Host $line -ForegroundColor Yellow }
        'ERROR' { Write-Host $line -ForegroundColor Red }
    }

    if ($LogFile) { Add-Content -Path $LogFile -Value $line }
}

function Export-ReportCsv {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory, ValueFromPipeline)]$InputObject,
        [Parameter(Mandatory)][string]$Path
    )

    # Collect everything first, then write once at the end, so the CSV
    # always has a single consistent header.
    begin   { $items = [System.Collections.Generic.List[object]]::new() }
    process { $items.Add($InputObject) }
    end {
        $dir = Split-Path -Path $Path -Parent
        if ($dir -and -not (Test-Path -Path $dir)) {
            New-Item -ItemType Directory -Path $dir -Force | Out-Null
        }
        $items | Export-Csv -Path $Path -NoTypeInformation
        Write-Log "Report saved to $Path"
    }
}
