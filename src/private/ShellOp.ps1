$global:ShellCache = $null

function Initialize-Shell {
    if (-not $global:ShellCache) {
        $global:ShellCache = New-Object -ComObject WScript.Shell
    }
    return $global:ShellCache
}

function Set-Reg {
	param(
		[Parameter(Mandatory = $true)]
		[string]$RegPath,
		[Parameter(Mandatory = $true)]
		[string]$target,
		[scriptblock]$Action,
		[switch]$WhatIf
	)
	begin {
		$shell = Initialize-Shell
	}
	process {
		$existingValue = $shell.RegRead($RegPath)
		if ($existingValue -eq $target) {
			Write-Host "$RegPath already exists with value $existingValue. Skipping."
			return
		}
		if ($WhatIf) {
			Write-Host "[WhatIf]: Setting $RegPath to $target"
			return
		}
		$shell.RegWrite($RegPath, $target)
		if ($Action) {
			$Action.Invoke()
		}
		Write-Debug "Setting $RegPath to $target"
	}
}