Import-Module .\src\private\Env.ps1
Import-Module .\src\private\Utils.ps1
function Set-MyEnv {
	param (
		[switch]$Stratum,
		[switch]$Force,
		[switch]$WhatIf
	)
	
	$Unified = "$HOME\Unified"

	New-ValidDir -Path $Unified -Force:$Force -WhatIf:$WhatIf
	
	TraverseJson -JsonObject $Global:Schema -Action {
		param(
			$key,
			$path,
			$value
		)
		if (-not $value) {
			$path = Read-ValidPath "Empty. Please Enter path for $key"
		}
		if ($WhatIf) {
			Write-Host "[WhatIf]: Setting " -NoNewline
			Write-Host "$key" -ForegroundColor Yellow -NoNewline
			Write-Host " to " -NoNewline
			Write-Host "$value" -ForegroundColor Green
		}
		else {
			Set-Env $key $value -WhatIf:$WhatIf -Force:$Force
			New-ValidDir -Path $value -Force:$Force -WhatIf:$WhatIf
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
			New-ValidDir -Path $Unified -WhatIf:$WhatIf
		}
	}
}