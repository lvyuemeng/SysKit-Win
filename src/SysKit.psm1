$exportedFunctions = @()

# Load Public
Get-ChildItem "$PSScriptRoot/Public/*.ps1" | ForEach-Object {
    . $_.FullName
    $exportedFunctions += $_.BaseName
}

# Load Private (internal helpers)
Get-ChildItem "$PSScriptRoot/Private/*.ps1" | ForEach-Object {
    . $_.FullName
}

Export-ModuleMember -Function $exportedFunctions