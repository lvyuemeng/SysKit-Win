# schema.psm1 - Type definitions and validation for WinSpec

# Provider type enumeration
enum ProviderType {
    Declarative
    Trigger
}

# Specification schema definition
$Script:SpecSchema = @{
    Name        = @{ Type = "string"; Required = $false }
    Description = @{ Type = "string"; Required = $false }
    Import      = @{ Type = "array"; Required = $false }
    Registry    = @{ Type = "hashtable"; Required = $false }
    Package     = @{ Type = "hashtable"; Required = $false }
    Service     = @{ Type = "hashtable"; Required = $false }
    Feature     = @{ Type = "hashtable"; Required = $false }
    Trigger     = @{ Type = "hashtable"; Required = $false }
}

# Registry configuration maps
$Script:RegistryMaps = @{
    Clipboard = @{
        Path = "HKCU:\Software\Microsoft\Clipboard"
        Properties = @{
            EnableHistory = @{ 
                Name = "EnableClipboardHistory"
                Type = "DWord"
            }
        }
    }
    
    Explorer = @{
        Path = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced"
        Properties = @{
            ShowHidden = @{ 
                Name    = "Hidden"
                Type    = "DWord"
                Map     = @{ $true = 1; $false = 2 }
            }
            ShowFileExt = @{ 
                Name    = "HideFileExt"
                Type    = "DWord"
                Map     = @{ $true = 0; $false = 1 }
            }
        }
    }
    
    Theme = @{
        Path = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Themes\Personalize"
        Properties = @{
            AppTheme = @{ 
                Name    = "AppsUseLightTheme"
                Type    = "DWord"
                Map     = @{ "light" = 1; "dark" = 0 }
            }
            SystemTheme = @{ 
                Name    = "SystemUsesLightTheme"
                Type    = "DWord"
                Map     = @{ "light" = 1; "dark" = 0 }
            }
        }
    }
    
    Desktop = @{
        Path = "HKCU:\Control Panel\Desktop"
        Properties = @{
            MenuShowDelay = @{
                Name = "MenuShowDelay"
                Type = "String"
            }
        }
    }
}

function Get-RegistryMap {
    param (
        [Parameter(Mandatory = $false)]
        [string]$Category
    )
    
    if ($Category) {
        return $Script:RegistryMaps[$Category]
    }
    return $Script:RegistryMaps
}

function Get-SpecSchema {
    return $Script:SpecSchema
}

function Test-SpecSchema {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [hashtable]$Config
    )
    
    $errors = @()
    
    # Validate known keys
    $validKeys = $Script:SpecSchema.Keys
    foreach ($key in $Config.Keys) {
        if ($key -notin $validKeys) {
            $errors += "Unknown specification key: '$key'"
        }
    }
    
    # Validate Registry keys are known categories
    if ($Config.Registry) {
        $validCategories = $Script:RegistryMaps.Keys
        foreach ($category in $Config.Registry.Keys) {
            if ($category -notin $validCategories) {
                $errors += "Unknown Registry category: '$category'. Valid: $($validCategories -join ', ')"
            }
        }
    }
    
    # Validate Package structure
    if ($Config.Package) {
        if ($Config.Package.Installed -and -not ($Config.Package.Installed -is [array])) {
            $errors += "Package.Installed must be an array"
        }
    }
    
    # Validate Feature structure
    if ($Config.Feature) {
        foreach ($feature in $Config.Feature.Keys) {
            $value = $Config.Feature[$feature]
            if ($value -notin @("enabled", "disabled")) {
                $errors += "Feature '$feature' has invalid value '$value'. Must be 'enabled' or 'disabled'"
            }
        }
    }
    
    # Validate Service structure
    if ($Config.Service) {
        foreach ($service in $Config.Service.Keys) {
            $svcConfig = $Config.Service[$service]
            if ($svcConfig.State -and $svcConfig.State -notin @("running", "stopped")) {
                $errors += "Service '$service' has invalid State '$($svcConfig.State)'. Must be 'running' or 'stopped'"
            }
            if ($svcConfig.Startup -and $svcConfig.Startup -notin @("automatic", "manual", "disabled")) {
                $errors += "Service '$service' has invalid Startup '$($svcConfig.Startup)'. Must be 'automatic', 'manual', or 'disabled'"
            }
        }
    }
    
    # Validate Trigger structure
    if ($Config.Trigger) {
        $validTriggers = @("Activation", "Debloat", "Office")
        foreach ($trigger in $Config.Trigger.Keys) {
            if ($trigger -notin $validTriggers) {
                $errors += "Unknown Trigger: '$trigger'. Valid: $($validTriggers -join ', ')"
            }
        }
    }
    
    if ($errors.Count -gt 0) {
        Write-Log -Level "ERROR" -Message "Specification validation failed:"
        foreach ($err in $errors) {
            Write-Log -Level "ERROR" -Message "  - $err"
        }
        return $false
    }
    
    return $true
}

function Get-ProviderInfo {
    param (
        [Parameter(Mandatory = $true)]
        [string]$Name
    )
    
    $declarativeProviders = @("Registry", "Package", "Service", "Feature")
    $triggerProviders = @("Activation", "Debloat", "Office")
    
    if ($Name -in $declarativeProviders) {
        return @{
            Name = $Name
            Type = [ProviderType]::Declarative
        }
    }
    elseif ($Name -in $triggerProviders) {
        return @{
            Name = $Name
            Type = [ProviderType]::Trigger
        }
    }
    
    return $null
}

Export-ModuleMember -Function @(
    "Get-RegistryMap"
    "Get-SpecSchema"
    "Test-SpecSchema"
    "Get-ProviderInfo"
)
