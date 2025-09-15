function Get-RegistryState {
	param (
		[parameter(Mandatory = $true)]
		[string]$Path,
		[parameter(Mandatory = $true)]
		[string]$Property,
		[parameter(Mandatory = $true)]
		$Default
	)
	
	$state = Get-ItemProperty -Path $Path -Name $Property -ErrorAction SilentlyContinue | Select-Object -ExpandProperty $Property
	
	if (-Not $state) {
		return $Default
	}
 else {
		return $state
	}
}

function Set-RegistryState {
	param(
		[parameter(Mandatory = $true)]
		[string]$Path,
		[parameter(Mandatory = $true)]
		[string]$Property,
		[parameter(Mandatory = $true)]
		[string]$Type,
		[parameter(Mandatory = $true)]
		$Value
	)

	Set-ItemProperty -Path $Path -Name $Property -Type $Type -Value $Value -Force
}

function Test-RegistryState {
	param (
		[parameter(Mandatory = $true)]
		[string]$Path,
		[parameter(Mandatory = $true)]
		[string]$Property,
		[parameter(Mandatory = $true)]
		$Default,
		[parameter(Mandatory = $true)]
		$Expected
	)

	$cur_state = Get-RegistryState -Path $Path -Property $Property -Default $Default
	
	return ($cur_state -eq $Expected)
}

Export-ModuleMember -Function Get-RegistryState, Set-RegistryState, Test-RegistryState