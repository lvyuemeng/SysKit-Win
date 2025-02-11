Import-Module .\src\private\Env.ps1
Import-Module .\src\private\Utils.ps1
function Set-MyEnv {
	param (
		[string]$EnvListPath = ".\src\static\EnvList.json",
		[ValidateSet('User', 'Machine')]
		[string]$Scope = 'User',
		[switch]$WhatIf
	)
	
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
			Set-Env $key $envTable[$key] -WhatIf:$WhatIf -Scope $Scope
		}
	}
	
	if ($null -ne $Stratum) {
		Write-Host "Caveat: " -ForegroundColor Red
		Write-Host "Stratum is setting for Downloads, Music, Videos, and Desktop, TEMP, TMP."
		
		if ($WhatIf) {
			Write-Host "[WhatIf]: Setting " -NoNewline
			Write-Host "Stratum" -ForegroundColor Yellow -NoNewline
			Write-Host " to " -NoNewline
			Write-Host "$Stratum with Downloads, Music, Videos, Desktop, TEMP, TMP" -ForegroundColor Green
			return
		}
		if (Confirm) {
			Set-Env Stratum $Stratum -WhatIf:$WhatIf -Scope $Scope
			
		}
		else {
			return
		}
	}
}