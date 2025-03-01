function New-MyEnv {
	[CmdletBinding(ConfirmImpact = 'High', SupportsShouldProcess)]
	param (
		[switch]$Schema,
		[switch]$Stratum,
		[switch]$Temp,

		[switch]$Force
	)
	
	$Root = Join-Path $HOME $Global:Config.Root

	New-ValidDir -Path $Root -Force:$Force -WhatIf:$WhatIfPreference

	if ($Schema) {
		New-Schema -Force:$Force -WhatIf:$WhatIfPreference
	}
	
	if ($Stratum) {
		Write-Host "Caveat: " -ForegroundColor Red
		Write-Host "Stratum will be the root of Download, Music, Video. It will overwrite registry and move existing files."

		New-Stratum -Force:$Force -WhatIf:$WhatIfPreference
	}
}

function New-Schema {
	[CmdletBinding(SupportsShouldProcess)]
	param (
		[switch]$Force
	)
	
	TraverseJson -JsonObject $Global:Schema -Action {
		param(
			$key,
			$path,
			$value
		)
		if (-not $value) {
			$path = Read-ValidPath "Empty. Please Enter path for $key"
		}
		if ($PSCmdlet.ShouldProcess($key)) {
			Set-Env $key $value -WhatIf:$WhatIfPreference -Force:$Force
			New-Item -Path (Join-Path $Root $key) -ItemType SymbolicLink -Target $value -Force:$Force -WhatIf:$WhatIfPreference
		}
		else {
			Write-Host "Setting " -NoNewline
			Write-Host "$key" -ForegroundColor Yellow -NoNewline
			Write-Host " to " -NoNewline
			Write-Host "$value" -ForegroundColor Green
		}
	}
}

function New-Stratum {
	[CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'High')]
	param (
		[switch]$Force
	)
	
	$Path = if ($Global:Stratum) {
		$Global:Stratum
	}
	else {
		Read-ValidPath -Prompt "Enter Stratum path"
	}

	if ($PSCmdlet.ShouldProcess("Setting Stratum to $Path with Download, Music, Video.", "$Path", "Setting Stratum")) {
		Set-Env -VarName "Stratum" -Path $Path -WhatIf:$WhatIfPreference -Force:$Force
		Set-SystemFolders -WhatIf:$WhatIfPreference -Force:$Force
		New-Item -Path (Join-Path $Root "Stratum") -ItemType SymbolicLink -Target $Path -Force:$Force -WhatIf:$WhatIfPreference
	}
}