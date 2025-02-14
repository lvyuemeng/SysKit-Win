function Set-MyEnv {
	[CmdletBinding(ConfirmImpact = 'High', SupportsShouldProcess)]
	param (
		[switch]$Stratum,

		[switch]$Force
	)
	
	$Root = Join-Path $HOME $Global:Config.Root

	New-ValidDir -Path $Root -Force:$Force -WhatIf:$WhatIfPreference
	
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
	
	if ($Stratum) {
		Write-Host "Caveat: " -ForegroundColor Red
		Write-Host "Stratum is setting for Downloads, Music, Videos, and Desktop, TEMP, TMP. It will overwrite registry and move existing files."
		
		if ($PSCmdlet.ShouldProcess("Stratum")) {
			$path = if ($Global:Stratum) {
				$Global:Stratum
			}
			else {
				Read-ValidPath "Enter Stratum path"
			}
			Set-Env -VarName "Stratum" -Path $path -WhatIf:$WhatIfPreference -Force:$Force
			Set-SystemFolders -WhatIf:$WhatIfPreference -Force:$Force
			New-Item -Path (Join-Path $Root "Stratum") -ItemType SymbolicLink -Target $path -Force:$Force -WhatIf:$WhatIfPreference
		}
		else {
			Write-Host "Setting Stratum to " -NoNewline
			Write-Host "$Stratum with Downloads, Music, Videos,  TEMP, TMP" -ForegroundColor Green
		}
	}
}