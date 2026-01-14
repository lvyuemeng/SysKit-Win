<#
.SYNOPSIS
    Downloads Microsoft Office 365 PlusRetail installer.

.DESCRIPTION
    This script downloads the online x64 Microsoft 365 installer from Microsoft CDN.
    Supports downloading to a custom directory and caching without execution.

.PARAMETER dir
    Target directory for the installer. Defaults to current directory.

.PARAMETER cache
    Download only, do not execute the installer.

.EXAMPLE
    .\office.ps1 -dir C:\Installers
    Downloads Office installer to C:\Installers\Officesetup.exe

.EXAMPLE
    .\office.ps1 -cache
    Downloads Office installer to current directory without executing

.NOTES
    Thanks to https://massgrave.dev/office_c2r_links for the installer support.
#>
param(
    [string]$dir,
    [switch]$cache,
    [Parameter(ValueFromRemainingArguments = $true)]
    [string[]]$args
)

$ErrorActionPreference = 'Stop'

$url = 'https://c2rsetup.officeapps.live.com/c2r/download.aspx?ProductreleaseID=O365ProPlusRetail&platform=x64&language=en-us&version=O16GA'

try {
    $target = if ($dir) {
        New-Item $dir -ItemType Directory -Force | Out-Null
        Join-Path $dir 'Officesetup.exe'
    }
    else {
        'Officesetup.exe'
    }

    Invoke-WebRequest $url -OutFile $target -UseBasicParsing -ErrorAction Stop
    if (-not $cache) { & $target }
}
catch {
    Write-Error "Installation failed: $_"
    exit 1
}
