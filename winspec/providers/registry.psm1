# providers/registry.psm1 - Declarative registry provider

# Import dependent modules
Import-Module (Join-Path $PSScriptRoot "..\logging.psm1") -Force
Import-Module (Join-Path $PSScriptRoot "..\schema.psm1") -Force

function Get-ProviderInfo {
    return @{
        Name = "Registry"
        Type = "Declarative"
    }
}

function Get-RegistryValue {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [string]$Path,
        
        [Parameter(Mandatory = $true)]
        [string]$Property,
        
        [Parameter(Mandatory = $false)]
        $Default = $null
    )
    
    try {
        $result = Get-ItemProperty -Path $Path -Name $Property -ErrorAction SilentlyContinue
        if ($result) {
            return $result.$Property
        }
        return $Default
    }
    catch {
        return $Default
    }
}

function Set-RegistryValue {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [string]$Path,
        
        [Parameter(Mandatory = $true)]
        [string]$Property,
        
        [Parameter(Mandatory = $true)]
        [string]$Type,
        
        [Parameter(Mandatory = $true)]
        $Value
    )
    
    # Create path if it doesn't exist
    if (-not (Test-Path $Path)) {
        New-Item -Path $Path -Force | Out-Null
    }
    
    Set-ItemProperty -Path $Path -Name $Property -Type $Type -Value $Value -Force
}

function Get-RegistryStateFromMap {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [hashtable]$StateMap,
        
        [Parameter(Mandatory = $true)]
        $RegistryValue
    )
    
    $reverseMap = @{}
    foreach ($key in $StateMap.Keys) {
        $reverseMap[$StateMap[$key]] = $key
    }
    
    return $reverseMap[$RegistryValue]
}

function Test-RegistryState {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [hashtable]$Desired
    )
    
    $registryMap = Get-RegistryMap
    $allInDesiredState = $true
    
    foreach ($category in $Desired.Keys) {
        $catConfig = $registryMap[$category]
        if (-not $catConfig) {
            Write-Log -Level "WARN" -Message "Unknown registry category: $category"
            continue
        }
        
        foreach ($propName in $Desired[$category].Keys) {
            $propConfig = $catConfig.Properties[$propName]
            if (-not $propConfig) {
                Write-Log -Level "WARN" -Message "Unknown property: $propName in $category"
                continue
            }
            
            $currentValue = Get-RegistryValue -Path $catConfig.Path -Property $propConfig.Name -Default $propConfig.Default
            
            if ($propConfig.Map) {
                $currentState = Get-RegistryStateFromMap -StateMap $propConfig.Map -RegistryValue $currentValue
            }
            else {
                $currentState = $currentValue
            }
            
            $desiredValue = $Desired[$category][$propName]
            
            if ($currentState -ne $desiredValue) {
                $allInDesiredState = $false
            }
        }
    }
    
    return $allInDesiredState
}

function Set-RegistryState {
    [CmdletBinding(SupportsShouldProcess = $true)]
    param (
        [Parameter(Mandatory = $true)]
        [hashtable]$Desired
    )
    
    $results = @{}
    $registryMap = Get-RegistryMap
    
    foreach ($category in $Desired.Keys) {
        $catConfig = $registryMap[$category]
        if (-not $catConfig) {
            Write-Log -Level "WARN" -Message "Unknown registry category: $category"
            $results[$category] = @{ Status = "Error"; Message = "Unknown category" }
            continue
        }
        
        Write-Log -Level "INFO" -Message "Processing category: $category"
        $categoryResults = @{}
        
        foreach ($propName in $Desired[$category].Keys) {
            $propConfig = $catConfig.Properties[$propName]
            if (-not $propConfig) {
                Write-Log -Level "WARN" -Message "Unknown property: $propName in $category"
                $categoryResults[$propName] = @{ Status = "Error"; Message = "Unknown property" }
                continue
            }
            
            $desiredValue = $Desired[$category][$propName]
            $currentRaw = Get-RegistryValue -Path $catConfig.Path -Property $propConfig.Name -Default $propConfig.Default
            
            if ($propConfig.Map) {
                $currentState = Get-RegistryStateFromMap -StateMap $propConfig.Map -RegistryValue $currentRaw
                $valueToSet = $propConfig.Map[$desiredValue]
            }
            else {
                $currentState = $currentRaw
                $valueToSet = $desiredValue
            }
            
            if ($currentState -eq $desiredValue) {
                Write-LogOk -Name "$category.$propName" -DesiredValue $desiredValue
                $categoryResults[$propName] = @{ Status = "AlreadySet"; Value = $desiredValue }
                continue
            }
            
            Write-LogChange -Name "$category.$propName" -CurrentValue $currentState -DesiredValue $desiredValue
            
            if ($PSCmdlet.ShouldProcess("$($catConfig.Path)\$($propConfig.Name)", "Set to '$desiredValue'")) {
                try {
                    Set-RegistryValue -Path $catConfig.Path -Property $propConfig.Name -Type $propConfig.Type -Value $valueToSet
                    Write-LogApplied -Name "$category.$propName" -DesiredValue $desiredValue
                    $categoryResults[$propName] = @{ Status = "Applied"; Value = $desiredValue }
                }
                catch {
                    Write-LogError -Name "$category.$propName" -Details $_.Exception.Message
                    $categoryResults[$propName] = @{ Status = "Error"; Message = $_.Exception.Message }
                }
            }
        }
        
        $results[$category] = $categoryResults
    }
    
    return $results
}

Export-ModuleMember -Function @(
    "Get-ProviderInfo"
    "Get-RegistryValue"
    "Set-RegistryValue"
    "Get-RegistryStateFromMap"
    "Test-RegistryState"
    "Set-RegistryState"
)
