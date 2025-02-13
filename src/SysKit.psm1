$exportedFunctions = @()

$isExe = $MyInvocation.MyCommand.CommandType -ne 'ExternalScript'
$Global:ProjectRoot = if ($isExe) {
	[System.Diagnostics.Process]::GetCurrentProcess().MainModule.FileName | Split-Path -Parent
}
else {
	"$PSScriptRoot\..\"
}

$Global:ConfigDir = Join-Path $Global:ProjectRoot 'SysKitConfig'

# Load Public
Get-ChildItem "$PSScriptRoot\public\*.ps1" | ForEach-Object {
    . $_.FullName
    $exportedFunctions += $_.BaseName
}

# Load Private (internal helpers)
Get-ChildItem "$PSScriptRoot\private\*.ps1" | ForEach-Object {
    . $_.FullName
}

Export-ModuleMember -Function $exportedFunctions