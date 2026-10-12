@{
    Severity     = @('Error', 'Warning')
    # Write-Host is used on purpose in Write-Log: it writes to the
    # information stream so log lines never pollute returned objects.
    ExcludeRules = @('PSAvoidUsingWriteHost')
}
