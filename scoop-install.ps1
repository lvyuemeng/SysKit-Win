<#
.SYNOPSIS
Install Scoop package manager.

.DESCRIPTION
Installs Scoop with optional proxy configuration.

.PARAMETER Source
Installation source: 'proxy' (default) or 'native'.

.EXAMPLE
.\scoop-install.ps1 -Source proxy
.EXAMPLE
.\scoop-install.ps1 -Source native
#>
[CmdletBinding()]
param(
    [ValidateSet('proxy', 'native')]
    [string]$Source = 'proxy'
)

$ErrorActionPreference = 'Stop'
$DEFAULT_PROXY = 'https://gh-proxy.org'

if (Get-Command scoop -ErrorAction SilentlyContinue) {
    Write-Host 'Scoop already installed.' -ForegroundColor Yellow
    exit 0
}

if ($Source -eq 'proxy') {
    $proxyBase = $DEFAULT_PROXY.TrimEnd('/')
    $installScript = "$proxyBase/https://raw.githubusercontent.com/ScoopInstaller/Install/master/install.ps1"
    Write-Host "Installing Scoop with proxy..." -ForegroundColor Cyan
    Write-Host "Downloading from: $installScript"

    try {
        Invoke-RestMethod -Uri $installScript | Invoke-Expression
        Write-Host 'Configuring proxy settings...' -ForegroundColor Cyan
        scoop config scoop_repo "$proxyBase/https://github.com/ScoopInstaller/scoop"
        scoop bucket add spc "$proxyBase/https://github.com/lvyuemeng/scoop-cn"
        Write-Host 'Scoop installed and configured successfully!' -ForegroundColor Green
    }
    catch { Write-Error "Failed: $_"; exit 1 }
}
else {
    Write-Host 'Installing Scoop (native)...' -ForegroundColor Cyan
    try {
        Invoke-RestMethod -Uri 'https://get.scoop.sh' | Invoke-Expression
        Write-Host 'Scoop installed successfully!' -ForegroundColor Green
    }
    catch { Write-Error "Failed: $_"; exit 1 }
}
