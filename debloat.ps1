<#
.SYNOPSIS
    Executes Windows debloat script.

.DESCRIPTION
    Downloads and executes the Win11Debloat script from https://debloat.raphi.re/
    All parameters are passed through to the remote script via splatting.

.EXAMPLE
    .\debloat.ps1 -Silent -CreateRestorePoint
    Runs debloat in silent mode with restore point creation

.EXAMPLE
    .\debloat.ps1 -RemoveApps
    Removes default selection of bloatware apps

.NOTES
    Thanks to https://github.com/Raphire/Win11Debloat/ for the script.
    For full documentation, see: https://github.com/Raphire/Win11Debloat/wiki/How-To-Use
#>
param(
    [parameter(ValueFromRemainingArguments = $true)]
    [string[]]$options
)

$ErrorActionPreference = 'Stop'

& ([scriptblock]::Create((Invoke-RestMethod 'https://debloat.raphi.re/'))) @options
