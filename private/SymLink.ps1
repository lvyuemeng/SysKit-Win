function NewSymLink {
	[CmdletBinding(SupportsShouldProcess)]
	param (
		[Parameter(Mandatory)]
		[string]$Link,
		[Parameter(Mandatory)]
		[string]$Target,
		[switch]$Force
	)
	
	if (Test-Path $Link) {
		if ($Force) {
			Remove-Item $Link
		}
		else {
			Write-Warning "$Link already exists. Use -Force to overwrite."
			return
		}
	}

	if (-not (Test-Path $Target)) {
		Write-Warning "$Target does not exist."
		return
	}

	if ($PSCmdlet.ShouldProcess($Link, "Create Symbolic Link")) {
		New-Item $Link -ItemType SymbolicLink -Value $Target
	}
}