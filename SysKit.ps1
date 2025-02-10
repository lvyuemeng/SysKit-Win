[CmdletBinding()]
param(
	[Parameter(Mandatory = $true,Position=0)]
	[string]$Command,

	[switch]$Verbose,
	[switch]$Help
)

Import-Module $PSScriptRoot\src\SysKit -Force

begin {

}

