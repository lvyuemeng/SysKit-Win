function Read-Selection {
	param (
		[Parameter(Mandatory, Position = 0)]
		[array]$matchedValues
	)
	$selection = @()
	if ($matchedValues.Count -gt 1) {
		Write-Host "`nMultiple matches found:" -ForegroundColor Cyan
		$matchedValues | ForEach-Object { 
			"[$($matchedValues.IndexOf($_)+1)] $_" 
		} | Out-Host

		do {
			$Value = Read-Host "`nSelect numbers to delete (comma-separated, 'a' for all, 'q' to quit)" 
			if ($Value -eq 'q') { return }
			if ($Value -eq 'a') { 
				$selection = $matchedValues
				break 
			}
            
			$indexes = $Value -split ',' | ForEach-Object { 
				if ($_ -match '^\d+$') { [int]$_ - 1 }
			} | Where-Object { $_ -ge 0 -and $_ -lt $matchedValues.Count }
            
			$selection = $matchedValues[$indexes] | Select-Object -Unique
		} while (-not $selection)
	}
	else {
		$selection = $matchedValues
	}
	
	return $selection
}
function Read-Object {
	param (
		[Parameter(Mandatory, Position = 0)]
		[string]$Prompt,
		[string]$ErrorMsg = "Invalid input. Please try again.",
		[Parameter(Mandatory)]
		[scriptblock]$Validator
	)
	do {
		$Value = Read-Host $Prompt
		try {
			if ($Validator.InvokeReturnAsIs($Value)) { return $Value }
			Write-Host $ErrorMsg
		}
		catch {
			Write-Host "$_" -ForegroundColor DarkRed
		}
	} while ($true)
}

function Test-ValidPath {
	param (
		[Parameter(Mandatory = $true, Position = 0)]
		[string]$Path
	)
	Test-Path -Path $Path -IsValid -PathType Container
}


function Read-ValidPath {
	param(
		[Parameter(Mandatory = $true, Position = 0)]
		[string]$Prompt
	)
	return Read-Object -Prompt $Prompt -Validator [scriptblock]::Create(
		{ 
			param($Value)
			Test-ValidPath -Path $Value
		}
	)
}


function New-ValidDir {
	[CmdletBinding(SupportsShouldProcess)]
	param (
		[Parameter(Mandatory = $true)]
		[string]$Path,
		
		[switch]$Force,
		[switch]$WhatIf
	)
	
	if (-not (Test-Path -Path $Path -PathType Container)) {
		Write-Verbose "Creating directory: $Path"
		if ($PSCmdlet.ShouldProcess($Path, "Create")) {
			try {
				New-Item -Path $Path -ItemType Directory -Force:$Force -ErrorAction Stop
			}
			catch {
				Write-Error "Failed to create path: $Path"
				return
			}
		}
	}
}

function TraverseJson {
	param (
		[Parameter(Mandatory = $true)]
		[hashtable]$JsonObject,
		[string]$parentPath = "",
		# Action(path, value)
		[Parameter(Mandatory = $true)]
		[scriptblock]$Action
	)

	foreach ($key in $JsonObject.Keys) {
		$curPath = if ($parentPath -eq '') { $key } else { Join-Path $parentPath $key }
		if ($JsonObject[$key] -is [hashtable]) {
			TraverseJson -JsonObject $JsonObject[$key] -parentPath $curPath -Action $Action
		}
		else {
			$Action.Invoke($key, $curPath, $JsonObject[$key])
		}
	}
}