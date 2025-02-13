Import-Module $PSScriptRoot\src\SysKit -Force

$isExe = $MyInvocation.MyCommand.CommandType -ne 'ExternalScript'
$Global:ProjectRoot = if ($isExe) {
	[System.Diagnostics.Process]::GetCurrentProcess().MainModule.FileName | Split-Path -Parent
}
else {
	$PSScriptRoot
}

$Global:ConfigDir = Join-Path $Global:ProjectRoot 'SysKitConfig'

function Main {
	[CmdletBinding()]
	param(
		[Parameter(Mandatory = $true, Position = 0)]
		[string]$Command,

		[switch]$Verbose,
		[switch]$Help
	)
	
	begin {
		
	}
	
	process {
		
	}
	
	end {
		
	}
}
