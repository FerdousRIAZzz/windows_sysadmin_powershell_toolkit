<#
.SYNOPSIS
    Creates AD users in bulk from a CSV file.

.DESCRIPTION
    Expected CSV columns: FirstName, LastName, Username, Department, OU
    (OU is a full distinguished name). Existing usernames are skipped, so
    the script is safe to re-run. Returns one result object per row.
    Supports -WhatIf: ALWAYS preview first.

.PARAMETER CsvPath
    Path to the input CSV (see samples/new-users-sample.csv).

.PARAMETER DefaultPassword
    Temporary password as a SecureString. Users must change it at first logon.

.EXAMPLE
    $pw = Read-Host -AsSecureString 'Temporary password'
    .\New-BulkADUsers.ps1 -CsvPath ..\..\samples\new-users-sample.csv -DefaultPassword $pw -WhatIf
#>
#Requires -Modules ActiveDirectory
[CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'Medium')]
param(
    [Parameter(Mandatory)][ValidateScript({ Test-Path -LiteralPath $_ })][string]$CsvPath,
    [Parameter(Mandatory)][securestring]$DefaultPassword
)

. (Join-Path $PSScriptRoot '..\..\lib\Common.ps1')

$rows = @(Import-Csv -Path $CsvPath)
if ($rows.Count -eq 0) { throw 'The CSV file contains no rows.' }

# Fail early if the CSV does not have the columns we need.
$required = 'FirstName', 'LastName', 'Username', 'Department', 'OU'
$missing  = $required | Where-Object { $_ -notin $rows[0].PSObject.Properties.Name }
if ($missing) { throw "CSV is missing column(s): $($missing -join ', ')" }

$domain = (Get-ADDomain).DNSRoot

$results = foreach ($u in $rows) {

    # Validate the username before it is used in an AD filter string.
    if ($u.Username -notmatch '^[A-Za-z0-9._-]{1,20}$') {
        Write-Log "Invalid username '$($u.Username)', skipping" -Level ERROR
        [pscustomobject]@{ Username = $u.Username; Action = 'Failed'; Detail = 'Invalid username format' }
        continue
    }

    if (Get-ADUser -Filter "SamAccountName -eq '$($u.Username)'" -ErrorAction SilentlyContinue) {
        Write-Log "$($u.Username) already exists, skipping" -Level WARN
        [pscustomobject]@{ Username = $u.Username; Action = 'Skipped'; Detail = 'Already exists' }
        continue
    }

    if ($PSCmdlet.ShouldProcess($u.Username, 'Create AD user')) {
        try {
            New-ADUser -Name "$($u.FirstName) $($u.LastName)" `
                       -GivenName $u.FirstName `
                       -Surname $u.LastName `
                       -SamAccountName $u.Username `
                       -UserPrincipalName "$($u.Username)@$domain" `
                       -Department $u.Department `
                       -Path $u.OU `
                       -AccountPassword $DefaultPassword `
                       -ChangePasswordAtLogon $true `
                       -Enabled $true -ErrorAction Stop
            Write-Log "Created $($u.Username)"
            [pscustomobject]@{ Username = $u.Username; Action = 'Created'; Detail = $null }
        }
        catch {
            Write-Log "Failed to create $($u.Username) : $($_.Exception.Message)" -Level ERROR
            [pscustomobject]@{ Username = $u.Username; Action = 'Failed'; Detail = $_.Exception.Message }
        }
    }
    else {
        [pscustomobject]@{ Username = $u.Username; Action = 'Skipped'; Detail = '-WhatIf or declined' }
    }
}

$results
