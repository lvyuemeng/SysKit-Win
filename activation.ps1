# Thanks to `https://github.com/massgravel/Microsoft-Activation-Scripts` Support this script
param (
	[Parameter(ValueFromRemainingArguments = $true)]
	[string[]]$args
)

# --- Help ---

$HELP_MSG = """
This script will activate windows/office.

Sincerely thanks to https://massgrave.dev Support. You may refer to it for more information.

Activation-Type	Supported-Product	Activation-Period	Is-Internet-Needed?

HWID			Windows-10-11		Permanent			Yes

Ohook			Office				Permanent			No

TSforge			Windows/ESU/Office	Permanent			Yes, needed on build 19041 and later

KMS38			Windows-10-11		Till the Year 2038	No

Online KMS		Windows/Office		180 Days			Yes
"""

$all_args = @($PSBoundParameters.Values + $args)

if ($all_args -match '^(?:-h|-\?|/\?|--help)$') {
	Write-Host $HELP_MSG
	exit 0
}

Invoke-RestMethod https://get.activated.win | Invoke-Expression
