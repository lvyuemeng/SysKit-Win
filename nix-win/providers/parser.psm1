function Import-YamlParser {
	param (
		[string]$Path
	)
	
	if (-Not (Get-Module -ListAvailable -Name "powershell-yaml")) {
		Write-Warning "powershell-yaml module not found. Required to parse files."
		Write-Host "Installing..."

		try {
			Install-Module -Name "powershell-yaml" -Scope CurrentUser -Force -AllowClobber -SkipPublisherCheck
		}
		catch {
			Write-Error "Failed to install powershell-yaml module. $_"
			exit 1
		}
	}

	return ConvertFrom-Yaml (Get-Content $Path -Raw)
}

Export-ModuleMember -Function Import-YamlParser