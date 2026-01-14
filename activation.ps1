<#
.SYNOPSIS
    Activates Windows and/or Office.

.DESCRIPTION
    Downloads and executes the Microsoft Activation Scripts from https://get.activated.win
    All arguments are passed through to the remote activation script.

.PARAMETER args
    Additional arguments passed to the remote activation script.

.EXAMPLE
    .\activation.ps1
    Runs the default activation method (HWID)

.EXAMPLE
    .\activation.ps1 -KMS38
    Uses KMS38 activation method

.NOTES
    Thanks to https://massgrave.dev for the activation scripts.
#>
param(
    [Parameter(ValueFromRemainingArguments = $true)]
    [string[]]$args
)

$ErrorActionPreference = 'Stop'

Invoke-RestMethod https://get.activated.win | Invoke-Expression
