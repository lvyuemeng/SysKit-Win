function Initialize-Features {
	param (
		[string]$Path = "$PSScriptRoot\..\static\Features.json",
		[switch]$WhatIf
	)
	
	if (-not (Test-Path $Path)) {
		Write-Error "Features.json not found at $Path"
		return
	}
	
	$features = Get-Json $Path

	foreach ($feature in $features) {
		$featureState = Get-WindowsOptionalFeature -Online -FeatureName $feature
		if ($null -eq $featureState) {
			Write-Error "$feature not found"
			continue
		}

		if ($featureState.State -ne "Enabled") {
			if ($WhatIf) {
				Write-Host "[WhatIf]: Enabling " -NoNewline
				Write-Host "$feature" -ForegroundColor Yellow
			}
			else {
				Enable-WindowsOptionalFeature -Online -FeatureName $feature -All -NoRestart
			}
		}
		else {
			Write-Host "$feature is already enabled" -ForegroundColor Green
		}
	}
}