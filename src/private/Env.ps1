Import-Module "$PSScriptRoot/../SysKit.psm1"

function Set-Env {
	param (
		[Parameter(Mandatory = $true)]
		[string]$VarName,

		[Parameter(Mandatory = $true)]
		[string]$Path,

		[ValidateSet('User', 'Machine')]
		[string]$Scope = 'User',

		[switch]$WhatIf
	)


	if (-not (Test-Path -Path $Path -PathType Container)) {
		if ($WhatIf) {
			Write-Host "[WhatIf]: Creating path $Path"
		}
		else {
			try {
				New-Item -Path $Path -ItemType Directory -Force -ErrorAction Stop
			}
			catch {
				Write-Error "Failed to create path: $Path"
				return
			}
		}
	}

	if ($WhatIf) {
		Write-Host "[WhatIf]: Setting environment variable $VarName to $Path"
		return
	}

	Write-Debug "Setting environment variable $VarName to $Path with scope $Scope"
	[Environment]::SetEnvironmentVariable($VarName, $Path, $Scope)
}

function Set-SystemFolders {
	param (
		[ValidateSet('User', 'Machine')]
		[string]$Scope = 'User',
		[switch]$WhatIf,
		[switch]$Temp
	)
	$shell = New-Object -ComObject WScript.Shell
	$stratum = [System.Environment]::GetEnvironmentVariable('Stratum', $Scope)
	
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
		if ($WhatIf) {
			Write-Host "[WhatIf]: Setting $key to $fullPath"
  }
		else {
			$shell.RegWrite("HKCU\Software\Microsoft\Windows\CurrentVersion\Explorer\User Shell Folders\$key", $fullPath)
		}
	}
}