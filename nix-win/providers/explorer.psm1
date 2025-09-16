Import-Module $PSScriptRoot/registry.psm1

$regPath = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced"
	
$taskbarSizeMap = @{
	'Small'  = 0;
	'Medium' = 1;
	'Large'  = 2;		
}

function Get-ExplorerState {
	$hidden = Get-RegistryState -Path $regPath -Property "Hidden" -Default 2
	$fileExt = Get-RegistryState -Path $regPath -Property "HideFileExt" -Default 0
	$classicStart = Get-RegistryState -Path $regPath -Property "Start_ShowClassicMode" -Default 0
	$taskbarSize = Get-RegistryState -Path $regPath -Property "TaskBarSi" -Default 0
	
	# convert to bool
	$showHidden = $hidden -eq 1
	$showFileExt = $fileExt -eq 0
	$classicStart = $classicStart -eq 0
	$taskbarSize = $taskbarSizeMap.GetEnumerator() | Where-Object { $_.Value -eq $taskbarSize } | Select-Object -First 1 | ForEach-Object { $_.Name }
	
	return $showHidden, $showFileExt, $classicStart, $taskbarSize
}

function Set-ExplorerState {
	param (
		[parameter(Mandatory = $true)]
		[hashtable]$DesiredState
	)

	$hidden = if ($DesiredState.showHidden) { 1 } else { 2 }
	$fileExt = if ($DesiredState.showFileExt) { 0 } else { 1 }
	$classicStart = if ($DesiredState.classicStart) { 0 } else { 1 }
	$taskbarSize = if (-not $taskbarSizeMap.ContainsKey($DesiredState.taskbarSize)) { 0 } else { $taskbarSizeMap[$DesiredState.taskbarSize] }

	
	Write-Debug "Applying show hidden: $($DesiredState.showHidden), file ext: $($DesiredState.showFileExt)"
	Set-RegistryState -Path $regPath -Property "Hidden" -Type "DWORD" -Value $hidden
	Set-RegistryState -Path $regPath -Property "HideFileExt" -Type "DWORD" -Value $fileExt
	Set-RegistryState -Path $regPath -Property "Start_ShowClassicMode" -Type "DWORD" -Value $classicStart
	Set-RegistryState -Path $regPath -Property "TaskBarSi" -Type "DWORD" -Value $taskbarSize
}

function Test-ExplorerState {
	param (
		[parameter(Mandatory = $true)]
		[hashtable]$DesiredState
	)

	$showHidden, $showFileExt = Get-ExplorerState
	return $showHidden -eq $DesiredState.showHidden -and $showFileExt -eq $DesiredState.showFileExt
}
