$DefaultRegPath = "HKCU\Environment"

function NameCheck {
	param(
		[string]$Name
	)
	$Name = $Name.ToUpper()
	
	if ($Name -eq "PATH") {
		throw "Cannot set PATH directly. Use Add/Remove for modifications"
	}
}

function SetReg {
	[CmdletBinding(SupportsShouldProcess)]
	param (
		[Parameter(Mandatory)]
		[string]$Name,
		[Parameter(Mandatory)]
		[string]$Value,
		[string]$RegPath = $DefaultRegPath
	)
	
	$RegPath = NormalizePath $RegPath
	NameCheck -Name $Name
	
	$regArgs = @(
		"add",
		"`"$RegPath`"",
		"/v",
		"`"$Name`"",
		"/t",
		"REG_SZ",
		"/d",
		"`"$Value`"",
		"/f"
	)
	
	if ($PSCmdlet.ShouldProcess("$RegPath\$Name", "Set Value")) {
		$process = Start-Process reg -ArgumentList $regArgs -Wait -PassThru -NoNewWindow
		if ($process.ExitCode -ne 0) {
			throw "Failed to set environment varable $RegPath\$Name to $Value (Error: $(process.ExitCode))"
		}
	}
}

function RemoveReg {
	[CmdletBinding(SupportsShouldProcess)]
	param(
		[Parameter(Mandatory)]
		[string]$Name,
		[string]$RegPath = $DefaultRegPath
	)

	$RegPath = NormalizePath $RegPath
	
	NameCheck -Name $Name

	$RegArgs = @(
		"delete",
		"`"$RegPath`"",
		"/v",
		"`"$Name`""
	)
	
	if ($PSCmdlet.ShouldProcess("$RegPath\$Name", "Remove")) {
		$process = Start-Process reg -ArgumentList $RegArgs -Wait -PassThru -NoNewWindow
		if ($process.ExitCode -ne 0) {
			throw "Failed to remove environment varable $RegPath\$Name (Error: $(process.ExitCode))"
		}
	}
}

function QueryReg {
	[CmdletBinding(SupportsShouldProcess)]
	param (
		[string]$Name,
		[string]$RegPath = $DefaultRegPath
	)
	
	$RegPath = NormalizePath $RegPath
	
	NameCheck -Name $Name
	$regArgs = @("query", "`"$RegPath`"")
	
	if ($Name) {
		$regArgs += @("/v", "`"$Name`"")
	}
	
	$process = Start-Process reg -ArgumentList $RegArgs -Wait -PassThru -NoNewWindow -RedirectStandardOutput "Out-Null"
	if ($process.ExitCode -ne 0) {
		throw "Failed to query environment varable $RegPath\$Name (Error: $(process.ExitCode))"
	}
	
	$process.StandardOutput | ForEach-Object {
		if ($_ -match "^\s+(\w+)\s+REG_(EXPAND_SZ | SZ)\s+(.*)") {
			[PSCustomObject]@{
				Name  = $Matches[1]
				Value = $Matches[3]
				Path  = $RegPath
			}
		}
	}
}

function AddReg {
	[CmdletBinding(SupportsShouldProcess)]
	param(
		[Parameter(Mandatory)]
		[string]$Name,
		[Parameter(Mandatory)]
		[ValidateScript({ Test-ValidPath -Path $_ })]
		[string]$Value,
		[string]$RegPath = $DefaultRegPath
	)
	
	$RegPath = NormalizePath $RegPath
	$OldValue = (QueryReg -Name $Name -RegPath $RegPath).Value
	
	if ($OldValue -split ";" -contains $Value) {
		Write-Warning "$Value already exists in $RegPath\$Name"
		return
	}

	$NewValue = if ($OldValue) { "$OldValue;$Value" } else { $Value }
	
	$regArgs = @(
		"add",
		"`"$RegPath`"",
		"/v",
		"$Name",
		"/t",
		"REG_SZ",
		"/d",
		"`"$NewValue`"",
		"/f"
	)
	
	if ($PSCmdlet.ShouldProcess("$RegPath\$Name", "Append Value")) {
		$process = Start-Process reg -ArgumentList $RegArgs -Wait -PassThru -NoNewWindow
		if ($process.ExitCode -ne 0) {
			throw "Failed to add environment varable $RegPath\$Name (Error: $(process.ExitCode))"
		}
	}
}

function RemoveReg {
	[CmdletBinding(SupportsShouldProcess)]
	param(
		[Parameter(Mandatory)]
		[string]$Name,
		[Parameter(Mandatory)]
		[string]$Value,
		[string]$RegPath = $DefaultRegPath
	)
	
	$RegPath = NormalizePath $RegPath
	$OldValue = (QueryReg -Name $Name -RegPath $RegPath).Value
	
	if (-not $OldValue -or -not ($OldValue -split ";" -contains $Value)) {
		Write-Warning "$Value does not exist in $RegPath\$Name"
		return
	}
	
	$NewValue = ($OldValue -split ";" | Where-Object { $_ -ne $Value }) -join ";"
	
	$regArgs = @(
		"add",
		"`"$RegPath`"",
		"/v",
		"`"$Name`"",
		"/t",
		"REG_SZ",
		"/d",
		"`"$NewValue`"")
	
	if ($PSCmdlet.ShouldProcess("$RegPath\$Name", "Remove Value")) {
		$process = Start-Process reg -ArgumentList $RegArgs -Wait -PassThru -NoNewWindow
		if ($process.ExitCode -ne 0) {
			throw "Failed to remove environment varable $RegPath\$Name (Error: $(process.ExitCode))"
		}
	}
}