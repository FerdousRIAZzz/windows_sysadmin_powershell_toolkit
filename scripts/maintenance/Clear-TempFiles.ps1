<#
.SYNOPSIS
    Deletes old files from the user temp folder (and optionally the
    Windows temp folder) and reports what was removed.

.DESCRIPTION
    Safeguards built in:
      * Only two locations can ever be cleaned: $env:TEMP, and (with
        -IncludeSystemTemp) $env:WINDIR\Temp. There is no -Path parameter,
        so the script cannot be pointed at an arbitrary folder.
      * A path is skipped unless it exists and ends in '\Temp'.
      * Only FILES older than -OlderThanDays are removed (minimum 1 day);
        folders are left in place, and symbolic-link files are skipped.
      * -WhatIf lists every file that WOULD be deleted. Run it first.

.PARAMETER OlderThanDays
    Only files not modified within this many days are removed. Default 7.

.PARAMETER IncludeSystemTemp
    Also clean C:\Windows\Temp (needs an elevated session).

.EXAMPLE
    .\Clear-TempFiles.ps1 -OlderThanDays 14 -WhatIf

.EXAMPLE
    .\Clear-TempFiles.ps1 -OlderThanDays 14
#>
[CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'Medium')]
param(
    [ValidateRange(1, 3650)][int]$OlderThanDays = 7,
    [switch]$IncludeSystemTemp
)

. (Join-Path $PSScriptRoot '..\..\lib\Common.ps1')

$cutoff   = (Get-Date).AddDays(-$OlderThanDays)
$approved = @($env:TEMP)
if ($IncludeSystemTemp) { $approved += (Join-Path $env:WINDIR 'Temp') }

foreach ($path in ($approved | Select-Object -Unique)) {
    $full = [System.IO.Path]::GetFullPath($path).TrimEnd('\')

    # Sanity checks before we ever delete anything.
    if (-not (Test-Path -LiteralPath $full) -or $full -notmatch '\\Temp$') {
        Write-Log "Skipping unexpected or missing path: $path" -Level WARN
        continue
    }

    Write-Log "Scanning $full"
    $old = @(
        Get-ChildItem -LiteralPath $full -Recurse -File -Force -ErrorAction SilentlyContinue |
            Where-Object {
                $_.LastWriteTime -lt $cutoff -and
                -not ($_.Attributes -band [System.IO.FileAttributes]::ReparsePoint)
            }
    )

    $deleted = 0; $failed = 0; $bytes = 0
    foreach ($f in $old) {
        # With -WhatIf, PowerShell prints "What if: Performing the operation
        # 'Delete' on target '<file>'" for each file instead of deleting.
        if ($PSCmdlet.ShouldProcess($f.FullName, 'Delete')) {
            try {
                Remove-Item -LiteralPath $f.FullName -Force -ErrorAction Stop
                $deleted++; $bytes += $f.Length
            }
            catch {
                $failed++   # typically a file that is currently in use
            }
        }
    }

    [pscustomobject]@{
        Path         = $full
        FilesMatched = $old.Count
        FilesDeleted = $deleted
        FilesFailed  = $failed
        MBFreed      = [math]::Round($bytes / 1MB, 1)
        WhatIfRun    = [bool]$WhatIfPreference
    }
}
