
function Initialize-Env {
	param (
		[switch]$WhatIf,
		[switch]$Force
	)	

	# Set EnvVars
	Set-MyEnv -WhatIf:$WhatIf -Force:$Force
}