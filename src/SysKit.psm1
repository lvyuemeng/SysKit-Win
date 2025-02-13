$exportedFunctions = @()

# Load Public
Get-ChildItem "$PSScriptRoot/exec/*.ps1" | ForEach-Object {
    . $_.FullName
    $exportedFunctions += $_.BaseName
}

# Load Private (internal helpers)
Get-ChildItem "$PSScriptRoot/lib/*.ps1" | ForEach-Object {
    . $_.FullName
}

Export-ModuleMember -Function $exportedFunctions