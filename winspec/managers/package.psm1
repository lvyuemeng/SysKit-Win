# providers/package.psm1 - Declarative package management provider

# Import dependent modules
Import-Module (Join-Path $PSScriptRoot "..\logging.psm1") -Force

function Get-ProviderInfo {
    return @{
        Name = "Package"
        Type = "Declarative"
    }
}

function Test-ScoopInstalled {
    [CmdletBinding()]
    param()
    
    return $null -ne (Get-Command scoop -ErrorAction SilentlyContinue)
}

function Install-ScoopPackage {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $false)]
        [string]$Source = "native"
    )
    
    if (Test-ScoopInstalled) {
        Write-Log -Level "OK" -Message "Scoop is already installed"
        return $true
    }
    
    Write-Log -Level "INFO" -Message "Installing Scoop package manager..."
    
    try {
        if ($Source -eq "proxy") {
            $proxyBase = "https://gh-proxy.org"
            $installScript = "$proxyBase/https://raw.githubusercontent.com/ScoopInstaller/Install/master/install.ps1"
            Invoke-RestMethod -Uri $installScript | Invoke-Expression
            scoop config scoop_repo "$proxyBase/https://github.com/ScoopInstaller/scoop"
            scoop bucket add spc "$proxyBase/https://github.com/lvyuemeng/scoop-cn"
        }
        else {
            Invoke-RestMethod -Uri 'https://get.scoop.sh' | Invoke-Expression
        }
        
        Write-Log -Level "APPLIED" -Message "Scoop installed successfully"
        return $true
    }
    catch {
        Write-Log -Level "ERROR" -Message "Failed to install Scoop: $($_.Exception.Message)"
        return $false
    }
}

function Get-InstalledPackages {
    [CmdletBinding()]
    param()
    
    if (-not (Test-ScoopInstalled)) {
        return @()
    }
    
    try {
        $packages = scoop list 2>$null | Select-Object -ExpandProperty Name -ErrorAction SilentlyContinue
        return @($packages)
    }
    catch {
        return @()
    }
}

function Test-PackageState {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [hashtable]$Desired
    )
    
    if (-not $Desired.Installed) {
        return $true
    }
    
    $installed = Get-InstalledPackages
    
    foreach ($package in $Desired.Installed) {
        if ($package -notin $installed) {
            return $false
        }
    }
    
    return $true
}

function Set-PackageState {
    [CmdletBinding(SupportsShouldProcess = $true)]
    param (
        [Parameter(Mandatory = $true)]
        [hashtable]$Desired
    )
    
    $results = @{}
    
    # Ensure Scoop is installed first
    if (-not (Test-ScoopInstalled)) {
        Write-Log -Level "INFO" -Message "Scoop is required for package management"
        
        if ($PSCmdlet.ShouldProcess("Scoop", "Install package manager")) {
            if (-not (Install-ScoopPackage)) {
                $results["Scoop"] = @{ Status = "Error"; Message = "Failed to install Scoop" }
                return $results
            }
            $results["Scoop"] = @{ Status = "Installed" }
        }
    }
    
    if (-not $Desired.Installed) {
        return $results
    }
    
    $installed = Get-InstalledPackages
    
    foreach ($package in $Desired.Installed) {
        if ($package -in $installed) {
            Write-LogOk -Name $package -DesiredValue "installed"
            $results[$package] = @{ Status = "AlreadyInstalled" }
            continue
        }
        
        Write-LogChange -Name $package -CurrentValue "not installed" -DesiredValue "installed"
        
        if ($PSCmdlet.ShouldProcess($package, "Install package")) {
            try {
                scoop install $package
                Write-LogApplied -Name $package -DesiredValue "installed"
                $results[$package] = @{ Status = "Installed" }
            }
            catch {
                Write-LogError -Name $package -Details $_.Exception.Message
                $results[$package] = @{ Status = "Error"; Message = $_.Exception.Message }
            }
        }
    }
    
    return $results
}

Export-ModuleMember -Function @(
    "Get-ProviderInfo"
    "Test-ScoopInstalled"
    "Install-ScoopPackage"
    "Get-InstalledPackages"
    "Test-PackageState"
    "Set-PackageState"
)
