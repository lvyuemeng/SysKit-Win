function Invoke-WindowsFeature {
	[CmdletBinding(SupportsShouldProcess = $true)]
	param(
		[parameter(Mandatory = $true)]
		[System.Collections.ArrayList]$DesiredStates
	)

	Write-Host "`nProcessing Resource: Windows Features" -ForegroundColor Cyan

	foreach ($feature in $DesiredStates) {
		$featureName = $feature.name
		$desiredState = [bool]$feature.state # "enabled" or "disabled"
		Write-Debug "Checking feature: $featureName"

		$curFeature = Get-WindowsOptionalFeature -Online -FeatureName $featureName -ErrorAction SilentlyContinue
		if (-not $curFeature) {
			Write-Error "Feature '$featureName' not found."
			continue
		}

		$isDesired = ($desiredState -eq ($curFeature.State -eq "Enabled"))

		if ($isDesired) {
			Write-Host "Feature is already $($desiredState)."
		}
		else {
			Write-Warning "Feature '$featureName' is not in the desired state of '$($desiredState)'."
			Write-Debug "Current: $($curFeature.State)"
			Write-Debug "Desired: $($desiredState)"

			if ($PSCmdlet.ShouldProcess($featureName, "Set state to '$desiredState'")) {
				try {
					if ($desiredState) {
						Enable-WindowsOptionalFeature -Online -FeatureName $featureName -NoRestart -All
					}
					else {
						Disable-WindowsOptionalFeature -Online -FeatureName $featureName -NoRestart
					}
					Write-Host "Successfully set '$featureName' to '$($desiredState)'." -ForegroundColor Green
					Write-Warning "A REBOOT may be required for this change to fully apply."
				}
				catch {
					Write-Error "Failed to change state for '$featureName'. Error: $($_.Exception.Message)"
				}
			}
		}
	}
}