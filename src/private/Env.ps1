Import-Module .\src\private\Utils.ps1
Import-Module .\src\private\ShellOp.ps1
function Set-Env {
	param (
		[Parameter(Mandatory = $true)]
		[string]$VarName,

		[Parameter(Mandatory = $true)]
		[string]$Path,

		[ValidateSet('User', 'Machine')]
		[string]$Scope = 'User',

		[switch]$Force,
		[switch]$WhatIf
	)

	New-ValidDir -Path $Path -Force:$Force -WhatIf:$WhatIf

	if ($WhatIf) {
		Write-Host "[WhatIf]: Setting environment variable $VarName to $Path"
		return
	}

	Write-Debug "Setting environment variable $VarName to $Path with scope $Scope"

	$existingValue = [Environment]::GetEnvironmentVariable($VarName, $Scope)
	if ($existingValue -and -not $Force) {
		Write-Host "$VarName already exists with value $existingValue. Use -Force to overwrite."
		return
	}
	[Environment]::SetEnvironmentVariable($VarName, $Path, $Scope)
}

function Set-SystemFolders {
	param (
		[switch]$WhatIf
	)
	$stratum = [System.Environment]::GetEnvironmentVariable("Stratum", "User")
	if (-not $stratum) {
		Write-Error "Stratum is not set. Please set it first."
		return
	}
	
	$folders = @{}
	$folders["My Pictures"] = "Pictures"
	$folders["My Music"] = "Music"
	$folders["My Video"] = "Videos"
	$folders["My Desktop"] = "Desktop"
	
	$temp = @(
		"TEMP",
		"TMP"
	)
	
	foreach ($key in $folders.Keys) {
		$fullPath = Join-Path $stratum $folders[$key]
		$regPath = "HKCU\Software\Microsoft\Windows\CurrentVersion\Explorer\User Shell Folders\$key"

		New-ValidDir -Path $fullPath -WhatIf:$WhatIf
		Set-Reg -RegPath $regPath -target $fullPath -Action {
			Get-ChildItem -Path $oldPath -Recurse | Move-Item -Destination $fullPath
		} -WhatIf:$WhatIf
	}
	
	foreach ($item in $temp) {
		$fullPath = Join-Path $stratum $item
		New-ValidDir -Path $fullPath -WhatIf:$WhatIf
		Set-Env -VarName $item -Path $fullPath -WhatIf:$WhatIf
	}
}