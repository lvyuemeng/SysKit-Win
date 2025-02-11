Import-Module .\src\private\Utils.ps1
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
	$shell = New-Object -ComObject WScript.Shell
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
		New-ValidDir -Path $fullPath -WhatIf:$WhatIf
		if ($WhatIf) {
			Write-Host "[WhatIf]: Setting $key to $fullPath"
		}
		else {
			$regPath = "HKCU\Software\Microsoft\Windows\CurrentVersion\Explorer\User Shell Folders\$key"
			$oldPath = $shell.RegRead($regPath)
			if ($oldPath -ne $fullPath) {
				$shell.RegWrite($regPath, $fullPath)
				Get-ChildItem -Path $oldPath -Recurse | Move-Item -Destination $fullPath
			}
			$shell.RegWrite($regPath, $fullPath)
		}
	}
	
	foreach ($item in $temp) {
		$fullPath = Join-Path $stratum $item
		New-ValidDir -Path $fullPath -WhatIf:$WhatIf
		Set-Env -VarName $item -Path $fullPath -WhatIf:$WhatIf
	}
}