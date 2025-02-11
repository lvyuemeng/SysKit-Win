Import-Module .\src\private\Env.ps1
Import-Module .\src\private\Utils.ps1
function Set-MyEnv {
	param (
		[string]$EnvListPath = "$PSScriptRoot\..\static\EnvList.json",
		[switch]$Stratum,
		[switch]$Force,
		[switch]$WhatIf
	)
	
	if (-not (Test-Path $EnvListPath)) {
		Write-Error "EnvList.json not found at $EnvListPath"
		return
	}
	$envTable = Get-Json $EnvListPath
	
	foreach ($key in $envTable.Keys) {
		if (-not $envTable[$key]) {
			$path = Read-ValidPath "Empty. Please Enter path for $key"
			$envTable[$key] = $path
		}
		if ($WhatIf) {
			Write-Host "[WhatIf]: Setting " -NoNewline
			Write-Host "$key" -ForegroundColor Yellow -NoNewline
			Write-Host " to " -NoNewline
			Write-Host "$($envTable[$key])" -ForegroundColor Green
		}
		else {
			Set-Env $key $envTable[$key] -WhatIf:$WhatIf -Force:$Force
		}
	}
	
	if ($Stratum) {
		Write-Host "Caveat: " -ForegroundColor Red
		Write-Host "Stratum is setting for Downloads, Music, Videos, and Desktop, TEMP, TMP. It will overwrite registry and move existing files."
		
		if ($WhatIf) {
			Write-Host "[WhatIf]: Setting " -NoNewline
			Write-Host "Stratum" -ForegroundColor Yellow -NoNewline
			Write-Host " to " -NoNewline
			Write-Host "$Stratum with Downloads, Music, Videos, Desktop, TEMP, TMP" -ForegroundColor Green
			return
		}
		if (Confirm) {
			$path = Read-ValidPath "Enter Stratum path"
			Set-Env -VarName "Stratum" -Path $path -WhatIf:$WhatIf
			Set-SystemFolders -WhatIf:$WhatIf
		}
	}
}