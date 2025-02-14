function Get-Config {
	[CmdletBinding(SupportsShouldProcess)]
	param ()

	$Editors = @(
		'code',
		'nvim',
		'notepad'
	)

	if ($Env:Shell) {
		$Editors = @($Env:Editor) + $Editors
	}
	
	foreach ($editor in $Editors) {
		$editorPath = Get-Command $editor -ErrorAction SilentlyContinue
		if ($editorPath) {
			if ($PSCmdlet.ShouldProcess($editor)) {
				& $editor $Global:ConfigPath
			}
			else {
				Write-Host "Editing by $editor" 
			}
			return
		}
	}

	Write-Warning "Editor not found"
}