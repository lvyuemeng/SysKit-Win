param (
	[string]$dir,
	[switch]$cache,
	[Parameter(ValueFromRemainingArguments = $true)]
	[string[]]$args
)

# --- Help ---
#
$HELP_MSG = """
This script will download **PlusRetail** online x64 Microsoft 365 installer.

Thanks to `https://github.com/gravesoft` Support this script.

Usuage: .\activation.ps1 [Options]

Options:
	-dir 	[path]								  default: current dir
	-cache	[switch] Don't execute the installer. default: false

Included Apps: Access, Excel, Lync, OneNote, Outlook, PowerPoint, Publisher, Word, OneDrive.

Office Installer:

Microsoft publishes updates in these same links, which means there isn't any need to update the links.

File size: C2R office installer files are unified. It means that for example, Office 2021 ProPlus, Excel, and OneNote, will all have the same size. Online installer consumes less data because it downloads files for only one system architecture whereas Offline file contain both architectures.

File version: Online installer always installs the latest Office version whereas the Offline version is often 5-6 months old and Office will need updates once installed.
"""

$all_args = @($PSBoundParameters.Values + $args)

if ($all_args -match '^(?:-h|-\?|/\?|--help)$') {
	Write-Host $HELP_MSG
	exit 0
}

# --- installation ---
# 
$url = "https://c2rsetup.officeapps.live.com/c2r/download.aspx?ProductreleaseID=O365ProPlusRetail&platform=x64&language=en-us&version=O16GA"

try {
	# $dir: Maybe<string> -> Maybe<Path>
	$target = if ($dir) {
		New-Item $dir -ItemType Directory -Force
		Join-Path $dir "Officesetup.exe"
	}
 else {
		"Officesetup.exe"
	}

	Invoke-WebRequest $url -OutFile $target -UseBasicParsing -ErrorAction Stop
	if (-not $cache) { & $target }
}
catch {
	Write-Error "Installation failed: $_"
	exit 1
}