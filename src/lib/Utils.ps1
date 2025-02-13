function Read-Object {
	param (
		[Parameter(Mandatory = $true)]
		[string]$Prompt,
		[Parameter(Mandatory = $true)]
		[scriptblock]$Validator
	)
	while ($true) {
		$object = Read-Host $prompt
		if ($Validator.Invoke($object)) {
			return $object
		}
		else {
			Write-Host "Invalid input. Please try again."
		}
	}
}

function Read-ValidPath {
	(
		[Parameter(Mandatory = $true)]
		[string]$prompt
	)
	return Read-Object -Prompt $prompt -Validator { -not [string]::IsNullOrWhiteSpace($_) -and (Test-Path -Path $_ -IsValid -PathType Container) }
}

function Confirm {
	$choice = Read-Host "Are you sure you want to continue? ([Yy]/[Nn])"
	return $choice -match '^[Yy]$'
}

function New-ValidDir {
	param (
		[Parameter(Mandatory = $true)]
		[string]$Path,
		
		[switch]$Force,
		[switch]$WhatIf
	)
	
	if (-not (Test-Path -Path $Path -PathType Container)) {
		if ($WhatIf) {
			Write-Host "[WhatIf]: Creating path $Path"
		}
		else {
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