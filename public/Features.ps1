function Add-Features {
	[CmdletBinding(SupportsShouldProcess)]
	param ()

	$features = $Global:Features

	foreach ($feature in $features) {
		$featureState = Get-WindowsOptionalFeature -Online -FeatureName $feature
		if ($null -eq $featureState) {
			Write-Warning "$feature not found"
			continue
		}

		if ($featureState.State -ne "Enabled") {
			if ($PSCmdlet.ShouldProcess($feature)) {
				Enable-WindowsOptionalFeature -Online -FeatureName $feature -All -NoRestart
			}
			else {
				Write-Host "$feature" -ForegroundColor Yellow
			}
		}
		else {
			Write-Host "$feature is already enabled" -ForegroundColor Green
		}
	}
}