# providers/feature.psm1 - Declarative Windows features provider

# Import dependent modules
Import-Module (Join-Path $PSScriptRoot "..\logging.psm1") -Force

function Get-ProviderInfo {
    return @{
        Name = "Feature"
        Type = "Declarative"
    }
}

function Get-FeatureState {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [string]$FeatureName
    )
    
    try {
        $feature = Get-WindowsOptionalFeature -Online -FeatureName $FeatureName -ErrorAction SilentlyContinue
        if ($feature) {
            return $feature.State
        }
        return $null
    }
    catch {
        return $null
    }
}

function Test-FeatureState {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [hashtable]$Desired
    )
    
    $allInDesiredState = $true
    
    foreach ($featureName in $Desired.Keys) {
        $desiredState = $Desired[$featureName]
        $currentState = Get-FeatureState -FeatureName $featureName
        
        if ($null -eq $currentState) {
            Write-Log -Level "WARN" -Message "Feature not found: $featureName"
            continue
        }
        
        $isDesired = ($desiredState -eq "enabled" -and $currentState -eq "Enabled") -or
                     ($desiredState -eq "disabled" -and $currentState -eq "Disabled")
        
        if (-not $isDesired) {
            $allInDesiredState = $false
        }
    }
    
    return $allInDesiredState
}

function Set-FeatureState {
    [CmdletBinding(SupportsShouldProcess = $true)]
    param (
        [Parameter(Mandatory = $true)]
        [hashtable]$Desired
    )
    
    $results = @{}
    
    foreach ($featureName in $Desired.Keys) {
        $desiredState = $Desired[$featureName]
        $currentState = Get-FeatureState -FeatureName $featureName
        
        if ($null -eq $currentState) {
            Write-Log -Level "ERROR" -Message "Feature not found: $featureName"
            $results[$featureName] = @{ Status = "Error"; Message = "Feature not found" }
            continue
        }
        
        $isDesired = ($desiredState -eq "enabled" -and $currentState -eq "Enabled") -or
                     ($desiredState -eq "disabled" -and $currentState -eq "Disabled")
        
        if ($isDesired) {
            Write-LogOk -Name $featureName -DesiredValue $desiredState
            $results[$featureName] = @{ Status = "AlreadySet"; State = $currentState }
            continue
        }
        
        Write-LogChange -Name $featureName -CurrentValue $currentState -DesiredValue $desiredState
        
        if ($PSCmdlet.ShouldProcess($featureName, "Set state to '$desiredState'")) {
            try {
                if ($desiredState -eq "enabled") {
                    Enable-WindowsOptionalFeature -Online -FeatureName $featureName -NoRestart -All -ErrorAction Stop
                }
                else {
                    Disable-WindowsOptionalFeature -Online -FeatureName $featureName -NoRestart -ErrorAction Stop
                }
                
                Write-LogApplied -Name $featureName -DesiredValue $desiredState
                Write-Log -Level "WARN" -Message "A REBOOT may be required for this change to fully apply."
                $results[$featureName] = @{ Status = "Applied"; State = $desiredState }
            }
            catch {
                Write-LogError -Name $featureName -Details $_.Exception.Message
                $results[$featureName] = @{ Status = "Error"; Message = $_.Exception.Message }
            }
        }
    }
    
    return $results
}

Export-ModuleMember -Function @(
    "Get-ProviderInfo"
    "Get-FeatureState"
    "Test-FeatureState"
    "Set-FeatureState"
)
