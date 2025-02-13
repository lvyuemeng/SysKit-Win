function Get-Config {
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
			& $editor $Global:ConfigPath
		}
	}
}