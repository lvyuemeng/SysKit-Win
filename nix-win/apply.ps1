[CmdletBinding(SupportsShouldProcess=$true)]
param (
	[parameter(Mandatory = $false)]
	[string]$Config = ".\profiles.yml",
	[parameter(Mandatory = $false)]
	[switch]$SkipCheckpoint
)

