function Write-Log {
	param (
		[Parameter(Mandatory = $true)]
		[string]$Level,
		[Parameter(Mandatory = $true)]
		[string]$Msg
	)

	$colors = @{
		# "INFO"    = "White";
		"OK"      = "Green";
		"APPLIED" = "Green";
		# "CHANGE" = "Yellow";
		# "ERROR"   = "Red";
	}
	
	switch ($Level) {
		"INFO" {
			# For informational messages.
			Write-Host "[INFO] $Message"
		}
		"OK" {
			# For success messages.
			Write-Host "[OK] $Message" -ForegroundColor $colors[$Level]
		}
		"APPLIED" {
			# For applied changes.
			Write-Host "[APPLIED] $Message" -ForegroundColor $colors[$Level]
		}
		"CHANGE" {
			# For changes that are about to be made.
			Write-Warning "[CHANGE] $Message"
		}
		"ERROR" {
			# For errors. Note: `throw` is handled by the calling script,
			# as a logger's responsibility is to log, not to control flow.
			Write-Error "[ERROR] $Message"
		}
	}
}

function Write-LogProcess {
	[CmdletBinding()]
	param (
		[Parameter(Mandatory = $true)]
		[string]$Name
	)

	Write-Log -Level "INFO" -Msg "Processing property '$Name'..."
}

function Write-LogOk {
	[CmdletBinding()]
	param (
		[Parameter(Mandatory = $true)]
		[string]$Name,
		[Parameter(Mandatory = $true)]
		[string]$DesiredValue
	)
	
	Write-Log -Level "OK" -Msg "'$Name' is already set to '$DesiredValue'."
}

function Write-LogApplied {
	[CmdletBinding()]
	param (
		[Parameter(Mandatory = $true)]
		[string]$Name,
		[Parameter(Mandatory = $true)]
		[string]$DesiredValue
	)
	
	Write-Log -Level "APPLIED" -Msg "'$Name' set to '$DesiredValue'."
}

function Write-LogChange {
	[CmdletBinding()]
	param (
		[Parameter(Mandatory = $true)]
		[string]$Name,
		[Parameter(Mandatory = $true)]
		[string]$CurrentValue,
		[Parameter(Mandatory = $true)]
		[string]$DesiredValue
	)
	
	Write-Log -Level "CHANGE" -Msg "'$Name' needs update from '$CurrentValue' to '$DesiredValue'."
}

function Write-LogError {
	[CmdletBinding()]
	param (
		[Parameter(Mandatory = $true)]
		[string]$Name
	)
	Write-Log -Level "ERROR" -Msg "Failed to set '$Name'."
	if ($PSItem) {
		Write-Log -Level "ERROR" -Msg "$($PSItem.Exception.Message)."
	}
}

Export-ModuleMember Write-LogApplied Write-LogChange Write-LogError Write-LogProcess Write-LogOk