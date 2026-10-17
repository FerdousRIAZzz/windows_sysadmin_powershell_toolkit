<#
.SYNOPSIS
    Backs up a folder with robocopy into a new timestamped folder.

.DESCRIPTION
    Each run creates Backup_<timestamp> inside the destination, so nothing
    is ever overwritten or deleted. This script deliberately does NOT use
    robocopy /MIR or /PURGE, which can delete files at the destination.

    Safeguards: the destination may not be the source or inside it, and a
    whole drive root cannot be used as the source.

    robocopy exit codes are a bitmask, not simple success/failure:
    0-7 = completed (possibly with extra/changed files), 8+ = copy errors,
    16 = fatal error.

.PARAMETER Source
    Folder to back up.

.PARAMETER Destination
    Folder that will receive the Backup_<timestamp> folder.

.EXAMPLE
    .\Backup-Folder.ps1 -Source C:\Data -Destination D:\Backups -WhatIf

.EXAMPLE
    .\Backup-Folder.ps1 -Source C:\Data -Destination D:\Backups
#>
[CmdletBinding(SupportsShouldProcess)]
param(
    [Parameter(Mandatory)]
    [ValidateScript({ Test-Path -LiteralPath $_ -PathType Container })]
    [string]$Source,

    [Parameter(Mandatory)][string]$Destination
)

. (Join-Path $PSScriptRoot '..\..\lib\Common.ps1')

# Resolve to full paths relative to the PowerShell location (not the
# process working directory) so the safety checks compare like with like.
$srcFull = (Resolve-Path -LiteralPath $Source).ProviderPath.TrimEnd('\')
$dstFull = $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($Destination).TrimEnd('\')

if ($srcFull -match '^[A-Za-z]:$') {
    throw 'Backing up an entire drive root is not supported by this script.'
}
if ($dstFull -eq $srcFull -or $dstFull.StartsWith("$srcFull\", [System.StringComparison]::OrdinalIgnoreCase)) {
    throw 'Destination must not be the source folder or a folder inside it.'
}

$stamp   = Get-Date -Format 'yyyyMMdd_HHmmss'
$target  = Join-Path $dstFull "Backup_$stamp"
$logFile = Join-Path $dstFull "Backup_$stamp.log"

if ($PSCmdlet.ShouldProcess("$srcFull -> $target", 'Back up')) {
    New-Item -ItemType Directory -Path $target -Force | Out-Null

    # /E copy subfolders (including empty ones), /R:2 /W:5 retry twice and
    # wait 5s, /NP no per-file progress, /LOG robocopy's own detailed log.
    robocopy $srcFull $target /E /R:2 /W:5 /NP /LOG:$logFile | Out-Null
    $code = $LASTEXITCODE

    $result = if     ($code -ge 16) { 'Fatal' }
              elseif ($code -ge 8)  { 'Failed' }
              else                  { 'Success' }

    if ($result -eq 'Success') { Write-Log "Backup complete: $target (robocopy exit code $code)" }
    else                       { Write-Log "Backup $result (robocopy exit code $code). See $logFile" -Level ERROR }

    [pscustomobject]@{
        Source   = $srcFull
        Target   = $target
        ExitCode = $code
        Result   = $result
        LogFile  = $logFile
    }
}
