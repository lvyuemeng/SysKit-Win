Import-Module "logger.psm1"

function Get-RegistryValue {
	param (
		[Parameter(Mandatory)] 
		[string]$Path,
		[Parameter(Mandatory)] 
		[string]$Property,
		[Parameter(Mandatory)] 
		$Default
	)
	(Get-ItemProperty -Path $Path -Name $Property -ErrorAction SilentlyContinue |
	Select-Object -ExpandProperty $Property -ErrorAction SilentlyContinue) ?? $Default
}

function Set-RegistryValue {
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

	if (-not (Test-Path $Path)) {
		New-Item -Path $Path -Force | Out-Null
	}
	Set-ItemProperty -Path $Path -Name $Property -Type $Type -Value $Value -Force
}

function Get-RegistryStateFromMap {
	param (
		[Parameter(Mandatory)] 
		[hashtable]$StateMap,
		[Parameter(Mandatory)] 
		$RegistryValue
	)
	$reverseMap = @{}
	foreach ($key in $StateMap.Keys) { $reverseMap[$StateMap[$key]] = $key }
	return $reverseMap[$RegistryValue]
}

function Sync-Property {
    [CmdletBinding(SupportsShouldProcess = $true)]
    param (
        [Parameter(Mandatory)]
        [string]$Name,
        [Parameter(Mandatory)]
        [string]$RegPath,
        [Parameter(Mandatory)]
        [string]$RegProperty,
        [Parameter(Mandatory)]
        [string]$RegType,
        [Parameter(Mandatory)]
        $DefaultValue,
        [hashtable]$ValueMap,
        [Parameter(Mandatory)]
        $DesiredValue
    )

	Write-LogProcess "$RegProperty"

    $curRaw = Get-RegistryValue -Path $RegPath -Property $RegProperty -Default $DefaultValue

    if ($ValueMap) {
        $curState = Get-RegistryStateFromMap -StateMap $ValueMap -RegistryValue $curRaw
        $valueFor = $ValueMap[$DesiredValue]
    }
    else {
        # If no ValueMap is provided, the DesiredValue is the raw value.
        $curState = $curRaw
        $valueFor = $DesiredValue
    }

    if ($curState -eq $DesiredValue) {
		Write-LogOk -Name $Name -DesiredValue $DesiredValue
        return
    }

	Write-LogChange -Name $Name -CurrentValue $curState -DesiredValue $DesiredValue

    if ($PSCmdlet.ShouldProcess("$RegPath\$RegProperty", "Set to '$DesiredValue'")) {
        try {
            Set-RegistryValue -Path $RegPath -Property $RegProperty -Type $RegType -Value $valueFor
			Write-LogApplied -Name $Name -DesiredValue $DesiredValue
        }
        catch {
			Write-LogError -Name $Name -Exception $_.Exception
        }
    }
}

function Sync-RegistryState {
	[CmdletBinding(SupportsShouldProcess = $true)]
	param (
		[Parameter(Mandatory)] [hashtable]$DesiredState,
		[Parameter(Mandatory)] [hashtable]$Mappings
	)

	$defaults = $Mappings.defaults
	foreach ($prop in $Mappings.property) {
		Sync-Property -Name        $prop.name `
			-RegPath     ($prop.regPath ?? $defaults.regPath) `
			-RegProperty $prop.regProperty `
			-RegType     ($prop.regType ?? $defaults.regType) `
			-DefaultValue $prop.defaultValue `
			-ValueMap    $prop.valueMap `
			-DesiredValue $DesiredState[$prop.name]
	}
}