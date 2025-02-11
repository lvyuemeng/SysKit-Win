function Read-ValidPath {
	(
		[Parameter(Mandatory = $true)]
		[string]$prompt
	)
	while ($true) {
		$path = Read-Host $prompt
		if (-not [string]::IsNullOrWhiteSpace($path) -and (Test-Path -Path $path -IsValid -PathType Container)) {
			return $path
		}
		else {
			Write-Host "Invalid path. Please enter a valid directory path."
		}
	}
}

function Confirm {
    $choice = Read-Host "Are you sure you want to continue? ([Yy]/[Nn])"
    return $choice -match '^[Yy]$'
}
