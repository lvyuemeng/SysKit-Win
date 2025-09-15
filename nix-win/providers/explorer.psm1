Import-Module $PSScriptRoot/registry.psm1

$regPath = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced"

function Get-ExplorerState {
	$hidden = Get-RegistryState -Path $regPath -Property "Hidden" -Default 2
	$fileExt = Get-RegistryState -Path $regPath -Property "HideFileExt" -Default 0
	
	# convert to bool
	$showHidden = $hidden -eq 1
	$showFileExt = $fileExt -eq 0
	
	return $showHidden, $showFileExt
}

function Set-ExplorerState {
	param (
		[parameter(Mandatory = $true)]
		[hashtable]$DesiredState
	)

	$hidden = if ($DesiredState.showHidden) { 1 } else { 2 }
	$fileExt = if ($DesiredState.showFileExt) { 0 } else { 1 }
	
	Write-Debug "Applying show hidden: $($DesiredState.showHidden), file ext: $($DesiredState.showFileExt)"
	Set-RegistryState -Path $regPath -Property "Hidden" -Type "DWORD" -Value $hidden
	Set-RegistryState -Path $regPath -Property "HideFileExt" -Type "DWORD" -Value $fileExt
}

function Test-ExplorerState {
	param (
		[parameter(Mandatory = $true)]
		[hashtable]$DesiredState
	)

	$showHidden, $showFileExt = Get-ExplorerState
	return $showHidden -eq $DesiredState.showHidden -and $showFileExt -eq $DesiredState.showFileExt
}
