# providers/Transparency.Provider.ps1
# Manages UI transparency effects.

function Get-TransparencyState {
	$regPath = "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Themes\Personalize"
	# A value of 1 means enabled (default), 0 means disabled (opaque).
	$transparencyValue = Get-ItemProperty -Path $regPath -Name "EnableTransparency" -ErrorAction SilentlyContinue | Select-Object -ExpandProperty EnableTransparency -Default 1
	$isEnabled = ($transparencyValue -eq 1)
	return @{ effects = $isEnabled }
}

function Set-TransparencyState {
	param(
		[parameter(Mandatory = $true)]
		[hashtable]$DesiredState
	)
	$regPath = "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Themes\Personalize"

	$transparencyValue = if ($DesiredState.effects) { 1 } else { 0 }

	Write-Host "  Applying Transparency Effects: $($DesiredState.effects)"
	Set-ItemProperty -Path $regPath -Name "EnableTransparency" -Value $transparencyValue -Type DWord -Force
}

function Test-TransparencyState {
	param(
		[parameter(Mandatory = $true)]
		[hashtable]$DesiredState
	)
	$currentState = Get-TransparencyState
	return $currentState.effects -eq $DesiredState.effects
}
