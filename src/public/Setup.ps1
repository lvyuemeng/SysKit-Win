Import-Module .\src\private\Env.ps1
Import-Module .\src\private\Utils.ps1
Import-Module .\src\private\Set.ps1
function Initialize-Env {
	param (
		[switch]$WhatIf,
		[switch]$Force
	)	

	# Set EnvVars
	Set-MyEnv -WhatIf:$WhatIf -Force:$Force
}