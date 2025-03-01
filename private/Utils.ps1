function Read-Object {
	param (
		[Parameter(Mandatory = $true)]
		[string]$Prompt,
		[Parameter(Mandatory = $true)]
		[scriptblock]$Validator
	)
	while ($true) {
		$object = Read-Host $Prompt
		if ($Validator.InvokeReturnAsIs(($object))) {
			return $object
		}
		else {
			Write-Host "Invalid input. Please try again."
		}
	}
}

function Test-ValidPath {
	param (
		[Parameter(Mandatory = $true, Position = 0)]
		[string]$Path
	)
	if ([string]::IsNullOrWhiteSpace($Path)) { return $false }
	Test-Path -Path $Path -IsValid -PathType Container
}


function Read-ValidPath {
	param(
		[Parameter(Mandatory = $true, Position = 0)]
		[string]$Prompt
	)
	return Read-Object -Prompt $Prompt -Validator { 
		param($Value)
		Test-ValidPath -Path $Value
	}
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

function NormalizePath {
	param (
		[string]$Path
	)

	return $Path.Replace('/','\').Trim('\')
}