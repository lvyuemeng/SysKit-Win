function Invoke-WindowsFeatureProvider {
	[CmdletBinding(SupportsShouldProcess = $true)]
	param(
		[parameter(Mandatory = $true)]
		[System.Collections.ArrayList]$DesiredStates
	)

	Write-Host "`nProcessing Resource: Windows Features" -ForegroundColor Cyan

	foreach ($feature in $DesiredStates) {
		$featureName = $feature.name
		$desiredState = $feature.state # "enabled" or "disabled"
		Write-Host "  Checking feature: $featureName"

		$currentFeature = Get-WindowsOptionalFeature -Online -FeatureName $featureName -ErrorAction SilentlyContinue
		if (-not $currentFeature) {
			Write-Error "    [ERROR] Feature '$featureName' not found."
			continue
		}

		# State can be 'Enabled' or 'Disabled'
		$isCorrectState = ($currentFeature.State.ToString().ToLower() -eq $desiredState)

		if ($isCorrectState) {
			Write-Host "    [OK] Feature is already $($desiredState)."
		}
		else {
			Write-Warning "    [CHANGE] Feature '$featureName' is not in the desired state of '$($desiredState)'."
			Write-Host "      Current: $($currentFeature.State)"
			Write-Host "      Desired: $($desiredState)"

			if ($PSCmdlet.ShouldProcess($featureName, "Set state to '$desiredState'")) {
				try {
					if ($desiredState -eq "enabled") {
						Enable-WindowsOptionalFeature -Online -FeatureName $featureName -NoRestart -All
					}
					else {
						Disable-WindowsOptionalFeature -Online -FeatureName $featureName -NoRestart
					}
					Write-Host "    [APPLIED] Successfully set '$featureName' to '$($desiredState)'." -ForegroundColor Green
					Write-Warning "    A REBOOT may be required for this change to fully apply."
				}
				catch {
					throw "Failed to change state for '$featureName'. Error: $($_.Exception.Message)"
				}
			}
		}
	}
}