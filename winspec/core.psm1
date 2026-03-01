# core.psm1 - Core engine for WinSpec: resolve, plan, execute

$Script:WinspecRoot = $PSScriptRoot

# Import dependent modules
Import-Module (Join-Path $Script:WinspecRoot "logging.psm1") -Force
Import-Module (Join-Path $Script:WinspecRoot "schema.psm1") -Force
Import-Module (Join-Path $Script:WinspecRoot "checkpoint.psm1") -Force

function Import-Spec {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [string]$Path
    )
    
    if (-not (Test-Path $Path)) {
        Write-Log -Level "ERROR" -Message "Specification file not found: $Path"
        return $null
    }
    
    try {
        $config = & $Path
        
        if ($config -isnot [hashtable]) {
            Write-Log -Level "ERROR" -Message "Specification must return a hashtable: $Path"
            return $null
        }
        
        Write-Log -Level "OK" -Message "Loaded specification: $Path"
        return $config
    }
    catch {
        Write-Log -Level "ERROR" -Message "Failed to parse specification: $Path"
        Write-Log -Level "ERROR" -Message $_.Exception.Message
        return $null
    }
}

function Resolve-Spec {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [hashtable]$Config,
        
        [Parameter(Mandatory = $false)]
        [string]$BasePath = $PWD
    )
    
    $resolved = @{}
    
    # Process imports first (recursive)
    if ($Config.Import) {
        Write-Log -Level "INFO" -Message "Processing imports..."
        
        foreach ($importPath in $Config.Import) {
            $fullPath = if ([System.IO.Path]::IsPathRooted($importPath)) {
                $importPath
            } else {
                Join-Path $BasePath $importPath
            }
            
            $importConfig = Import-Spec -Path $fullPath
            if ($importConfig) {
                $resolvedImport = Resolve-Spec -Config $importConfig -BasePath (Split-Path $fullPath -Parent)
                $resolved = Merge-Hashtables -Base $resolved -Override $resolvedImport
            }
        }
    }
    
    # Merge current config (current takes precedence)
    $resolved = Merge-Hashtables -Base $resolved -Override $Config
    
    # Remove Import key from resolved config
    $resolved.Remove("Import")
    
    return $resolved
}

function Merge-Hashtables {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [hashtable]$Base,
        
        [Parameter(Mandatory = $true)]
        [hashtable]$Override
    )
    
    $result = $Base.Clone()
    
    foreach ($key in $Override.Keys) {
        if ($result.ContainsKey($key) -and $result[$key] -is [hashtable] -and $Override[$key] -is [hashtable]) {
            # Recursively merge nested hashtables
            $result[$key] = Merge-Hashtables -Base $result[$key] -Override $Override[$key]
        }
        elseif ($result.ContainsKey($key) -and $result[$key] -is [array] -and $Override[$key] -is [array]) {
            # Merge arrays (unique values)
            $result[$key] = @($result[$key] + $Override[$key] | Select-Object -Unique)
        }
        else {
            # Override with new value
            $result[$key] = $Override[$key]
        }
    }
    
    return $result
}

function Test-Spec {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [hashtable]$Config
    )
    
    return Test-SpecSchema -Config $Config
}

function Import-Manager {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [string]$Name
    )
    
    $managerPath = Join-Path $Script:WinspecRoot "managers\$Name.psm1"
    
    if (-not (Test-Path $managerPath)) {
        Write-Log -Level "ERROR" -Message "Manager not found: $Name"
        return $null
    }
    
    try {
        Import-Module $managerPath -Force
        Write-Log -Level "OK" -Message "Loaded manager: $Name"
        return $true
    }
    catch {
        Write-Log -Level "ERROR" -Message "Failed to load manager: $Name"
        Write-Log -Level "ERROR" -Message $_.Exception.Message
        return $null
    }
}

# Backward compatibility alias
Set-Alias -Name Import-Provider -Value Import-Manager

function Invoke-DeclarativeProviders {
    [CmdletBinding(SupportsShouldProcess = $true)]
    param (
        [Parameter(Mandatory = $true)]
        [hashtable]$Config
    )
    
    $results = @{}
    $declarativeProviders = @("Registry", "Package", "Service", "Feature")
    
    foreach ($providerName in $declarativeProviders) {
        if ($Config.$providerName) {
            Write-LogSection -Name $providerName
            
            if (Import-Manager -Name $providerName) {
                $desired = $Config.$providerName
                
                # Get provider functions
                $testStateCmd = Get-Command "Test-$($providerName)State" -ErrorAction SilentlyContinue
                $setStateCmd = Get-Command "Set-$($providerName)State" -ErrorAction SilentlyContinue
                
                if ($testStateCmd -and $setStateCmd) {
                    $inDesiredState = & $testStateCmd -Desired $desired
                    
                    if (-not $inDesiredState) {
                        if ($WhatIf) {
                            Write-Log -Level "INFO" -Message "Would apply $providerName changes (dry run)"
                            $results[$providerName] = @{ Status = "DryRun"; Changes = "Pending" }
                        }
                        else {
                            if ($PSCmdlet.ShouldProcess($providerName, "Apply configuration")) {
                                $results[$providerName] = & $setStateCmd -Desired $desired
                            }
                        }
                    }
                    else {
                        Write-Log -Level "OK" -Message "$providerName is already in desired state"
                        $results[$providerName] = @{ Status = "AlreadyInDesiredState" }
                    }
                }
                else {
                    Write-Log -Level "ERROR" -Message "Provider $providerName is missing required functions"
                    $results[$providerName] = @{ Status = "Error"; Message = "Missing provider functions" }
                }
            }
            else {
                $results[$providerName] = @{ Status = "Error"; Message = "Failed to load provider" }
            }
        }
    }
    
    return $results
}

# Helper function to get provider description
function Get-ProviderDescription {
    param([hashtable]$Info, [string]$Type)
    if ($Info.Description) {
        return $Info.Description
    }
    if ($Type -eq "Declarative") {
        return "Configuration provider"
    }
    elseif ($Type -eq "Trigger") {
        return "Action provider"
    }
    return "Provider"
}

# Helper function to discover providers from a path
function Discover-ProvidersFromPath {
    param(
        [string]$Path,
        [string]$Type,
        [bool]$IsUserProvider = $false
    )
    if (-not (Test-Path $Path)) {
        return
    }
    
    $files = Get-ChildItem -Path $Path -Filter "*.psm1" -ErrorAction SilentlyContinue
    foreach ($file in $files) {
        $providerName = [System.IO.Path]::GetFileNameWithoutExtension($file.Name)
        try {
            Import-Module $file.FullName -Force -ErrorAction SilentlyContinue
            $info = Get-ProviderInfo -ErrorAction SilentlyContinue
            if ($info -and $info.Name -and $info.Type) {
                $description = Get-ProviderDescription -Info $info -Type $info.Type
                $prefix = if ($IsUserProvider) { "[User] " } else { "" }
                Write-Host "  $($prefix)$($info.Name)  - $description"
            }
        }
        catch {
            Write-Verbose "Failed to load provider $($file.Name): $_"
        }
    }
}

# Configuration Location Resolution
function Resolve-ConfigLocation {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $false)]
        [string]$ConfigPath,
        
        [Parameter(Mandatory = $false)]
        [string]$SpecPath
    )
    
    # 1. Explicit argument (highest priority)
    if ($ConfigPath) {
        if (Test-Path $ConfigPath) {
            return $ConfigPath
        }
    }
    
    # 2. Environment variable
    if ($env:WINSPEC_CONFIG -and (Test-Path $env:WINSPEC_CONFIG)) {
        return $env:WINSPEC_CONFIG
    }
    
    # 3. .config/winspec/ directory in user home
    $userConfigPath = Join-Path $env:USERPROFILE ".config\winspec"
    if (Test-Path $userConfigPath) {
        return $userConfigPath
    }
    
    # 4. .winspec.ps1 in current directory (default fallback)
    $defaultPath = Join-Path $PWD ".winspec.ps1"
    if (Test-Path $defaultPath) {
        return $defaultPath
    }
    
    return $null
}

# Find trigger script in multiple locations
function Find-TriggerScript {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$Name,
        
        [Parameter(Mandatory = $false)]
        [string]$Path,
        
        [Parameter(Mandatory = $false)]
        [string]$SpecPath,
        
        [Parameter(Mandatory = $false)]
        [string]$ConfigPath
    )
    
    # 1. Check for explicit path first
    if ($Path) {
        # Resolve relative to spec directory
        if (-not [System.IO.Path]::IsPathRooted($Path) -and $SpecPath) {
            $specDir = Split-Path $SpecPath -Parent
            $Path = Join-Path $specDir $Path
        }
        
        if (Test-Path $Path) {
            return $Path
        }
    }
    
    # 2. Check for built-in trigger in winspec/triggers/
    $builtinPath = Join-Path $Script:WinspecRoot "triggers\$Name.psm1"
    if (Test-Path $builtinPath) {
        return $builtinPath
    }
    
    # 3. Check for trigger in spec directory (triggers/ subdirectory)
    if ($SpecPath) {
        $specDir = Split-Path $SpecPath -Parent
        $specTriggerPath = Join-Path $specDir "triggers\$Name.ps1"
        if (Test-Path $specTriggerPath) {
            return $specTriggerPath
        }
    }
    
    # 4. Check for trigger in config directory (triggers/ subdirectory)
    if ($ConfigPath) {
        $configTriggerPath = Join-Path $ConfigPath "triggers\$Name.ps1"
        if (Test-Path $configTriggerPath) {
            return $configTriggerPath
        }
    }
    
    return $null
}

# Execute custom trigger script
function Invoke-CustomTrigger {
    [CmdletBinding(SupportsShouldProcess = $true)]
    param(
        [Parameter(Mandatory = $true)]
        [string]$ScriptPath,
        
        [Parameter(Mandatory = $false)]
        $Value = $true
    )
    
    if (-not (Test-Path $ScriptPath)) {
        return @{ Status = "Error"; Message = "Trigger script not found: $ScriptPath" }
    }
    
    if ($WhatIf) {
        Write-Log -Level "INFO" -Message "Would execute custom trigger: $ScriptPath"
        return @{ Status = "DryRun"; ScriptPath = $ScriptPath }
    }
    
    try {
        Write-Log -Level "INFO" -Message "Executing custom trigger: $([System.IO.Path]::GetFileName($ScriptPath))"
        
        # Load and execute the script with parameters
        $result = & $ScriptPath -Value $Value -WhatIf:$WhatIf
        
        if (-not $result) {
            return @{ Status = "Success"; Message = "Custom trigger executed" }
        }
        
        return $result
    }
    catch {
        Write-Log -Level "ERROR" -Message "Custom trigger failed: $_"
        return @{ Status = "Error"; Message = $_.Exception.Message }
    }
}

# Import built-in trigger module
function Import-BuiltInTrigger {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$Name
    )
    
    $triggerPath = Join-Path $Script:WinspecRoot "triggers\$Name.psm1"
    
    if (-not (Test-Path $triggerPath)) {
        return $null
    }
    
    try {
        Import-Module $triggerPath -Force
        return $true
    }
    catch {
        Write-Log -Level "ERROR" -Message "Failed to load trigger: $Name"
        return $null
    }
}

function Invoke-Triggers {
    [CmdletBinding(SupportsShouldProcess = $true)]
    param (
        [Parameter(Mandatory = $true)]
        [array]$TriggerConfig,
        
        [Parameter(Mandatory = $false)]
        [string]$SpecPath,
        
        [Parameter(Mandatory = $false)]
        [string]$ConfigPath
    )
    
    $results = @{}
    
    foreach ($trigger in $TriggerConfig) {
        # Validate trigger entry
        if ($trigger -isnot [hashtable]) {
            Write-Log -Level "ERROR" -Message "Invalid trigger entry: must be a hashtable"
            continue
        }
        
        # Check required Name field
        if (-not $trigger.Name) {
            Write-Log -Level "ERROR" -Message "Trigger entry missing required 'Name' field"
            continue
        }
        
        $triggerName = $trigger.Name
        $triggerValue = if ($trigger.ContainsKey('Value')) { $trigger.Value } else { $true }
        $triggerPath = $trigger.Path
        $enabled = if ($trigger.ContainsKey('Enabled')) { $trigger.Enabled } else { $true }
        
        Write-LogSection -Name "Trigger: $triggerName"
        
        # Skip if disabled
        if (-not $enabled) {
            Write-Log -Level "INFO" -Message "Trigger '$triggerName' is disabled"
            $results[$triggerName] = @{ Status = "Skipped"; Reason = "Disabled" }
            continue
        }
        
        # Find trigger script
        $scriptPath = Find-TriggerScript -Name $triggerName -Path $triggerPath -SpecPath $SpecPath -ConfigPath $ConfigPath
        
        if ($scriptPath -and $scriptPath.EndsWith('.psm1')) {
            # Built-in trigger
            if (Import-BuiltInTrigger -Name $triggerName) {
                $invokeTriggerCmd = Get-Command "Invoke-$($triggerName)Trigger" -ErrorAction SilentlyContinue
                
                if ($invokeTriggerCmd) {
                    if ($WhatIf) {
                        Write-Log -Level "INFO" -Message "Would trigger $triggerName (dry run)"
                        $results[$triggerName] = @{ Status = "DryRun"; Value = $triggerValue }
                    }
                    else {
                        if ($PSCmdlet.ShouldProcess($triggerName, "Execute trigger")) {
                            $results[$triggerName] = & $invokeTriggerCmd -Option $triggerValue
                        }
                    }
                }
                else {
                    Write-Log -Level "ERROR" -Message "Trigger $triggerName is missing Invoke-Trigger function"
                    $results[$triggerName] = @{ Status = "Error"; Message = "Missing trigger function" }
                }
            }
            else {
                $results[$triggerName] = @{ Status = "Error"; Message = "Failed to load trigger" }
            }
        }
        elseif ($scriptPath -and $scriptPath.EndsWith('.ps1')) {
            # Custom trigger script
            if ($WhatIf) {
                Write-Log -Level "INFO" -Message "Would execute custom trigger: $triggerName"
                $results[$triggerName] = @{ Status = "DryRun"; Value = $triggerValue }
            }
            else {
                if ($PSCmdlet.ShouldProcess($triggerName, "Execute custom trigger")) {
                    $results[$triggerName] = Invoke-CustomTrigger -ScriptPath $scriptPath -Value $triggerValue -WhatIf:$WhatIf
                }
            }
        }
        else {
            Write-Log -Level "ERROR" -Message "Trigger '$triggerName' not found in any location"
            $results[$triggerName] = @{ Status = "Error"; Message = "Trigger not found" }
        }
    }
    
    return $results
}

function Write-Report {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [hashtable]$Results
    )
    
    Write-LogHeader -Title "Execution Report"
    
    foreach ($provider in $Results.Keys) {
        $result = $Results[$provider]
        $status = if ($result.Status) { $result.Status } else { "Completed" }
        
        $level = switch ($status) {
            "AlreadyInDesiredState" { "OK" }
            "DryRun"                { "INFO" }
            "Error"                 { "ERROR" }
            default                 { "APPLIED" }
        }
        
        Write-Log -Level $level -Message "$provider : $status"
        
        if ($result.Message) {
            Write-Log -Level "INFO" -Message "  Message: $($result.Message)"
        }
        if ($result.Changes) {
            Write-Log -Level "INFO" -Message "  Changes: $($result.Changes)"
        }
    }
}

function Invoke-WinSpec {
    [CmdletBinding(SupportsShouldProcess = $true)]
    param (
        [Parameter(Mandatory = $true)]
        [string]$Spec,
        
        [Parameter(Mandatory = $false)]
        [string]$ConfigPath,
        
        [Parameter(Mandatory = $false)]
        [switch]$DryRun,
        
        [Parameter(Mandatory = $false)]
        [switch]$Checkpoint,
        
        [Parameter(Mandatory = $false)]
        [switch]$WithTriggers
    )
    
    Write-LogHeader -Title "WinSpec Execution"
    
    # 1. Parse specification
    $config = Import-Spec -Path $Spec
    if (-not $config) {
        Write-Log -Level "ERROR" -Message "Failed to load specification"
        return @{ Success = $false; Error = "Failed to load specification" }
    }
    
    # 2. Resolve imports (recursive merge)
    Write-Log -Level "INFO" -Message "Resolving specification..."
    $resolved = Resolve-Spec -Config $config -BasePath (Split-Path $Spec -Parent)
    
    # 3. Validate against schemas
    Write-Log -Level "INFO" -Message "Validating specification..."
    if (-not (Test-Spec -Config $resolved)) {
        Write-Log -Level "ERROR" -Message "Specification validation failed"
        return @{ Success = $false; Error = "Validation failed" }
    }
    
    # 4. Resolve configuration location
    $configLocation = Resolve-ConfigLocation -ConfigPath $ConfigPath -SpecPath $Spec
    if ($configLocation) {
        Write-Log -Level "INFO" -Message "Using configuration location: $configLocation"
    }
    
    # 5. Create checkpoint if requested
    if ($Checkpoint -and -not $DryRun) {
        $checkpointResult = New-Checkpoint -Name "WinSpec-$(Get-Date -Format 'yyyyMMdd-HHmmss')"
        if (-not $checkpointResult.Success) {
            Write-Log -Level "WARN" -Message "Checkpoint creation failed, continuing anyway..."
        }
    }
    
    # 6. Execute declarative providers (idempotent)
    $results = Invoke-DeclarativeProviders -Config $resolved -WhatIf:$DryRun
    
    # 7. Execute triggers if requested (non-idempotent)
    if ($WithTriggers -and $resolved.Trigger) {
        $results.Triggers = Invoke-Triggers `
            -TriggerConfig $resolved.Trigger `
            -SpecPath $Spec `
            -ConfigPath $configLocation `
            -WhatIf:$DryRun
    }
    
    # 8. Report
    Write-Report -Results $results
    
    $results.Success = $true
    return $results
}

function Get-SystemStatus {
    [CmdletBinding()]
    param()
    
    Write-LogHeader -Title "System Status"
    
    # Registry status
    Write-LogSection -Name "Registry"
    $registryMap = Get-RegistryMaps
    foreach ($category in $registryMap.Keys) {
        Write-Log -Level "INFO" -Message "Category: $category"
        $catConfig = $registryMap[$category]
        foreach ($prop in $catConfig.Properties.Keys) {
            $propConfig = $catConfig.Properties[$prop]
            $value = Get-ItemProperty -Path $catConfig.Path -Name $propConfig.Name -ErrorAction SilentlyContinue
            if ($value) {
                Write-Log -Level "INFO" -Message "  $($propConfig.Name) = $($value.$($propConfig.Name))"
            }
        }
    }
    
    # Package status
    Write-LogSection -Name "Packages"
    if (Get-Command scoop -ErrorAction SilentlyContinue) {
        $installed = scoop list | Select-Object -ExpandProperty Name
        Write-Log -Level "INFO" -Message "Scoop packages: $($installed -join ', ')"
    }
    else {
        Write-Log -Level "WARN" -Message "Scoop not installed"
    }
    
    # Checkpoint status
    Write-LogSection -Name "Checkpoints"
    $checkpoints = Get-Checkpoints
    if ($checkpoints) {
        foreach ($cp in $checkpoints) {
            Write-Log -Level "INFO" -Message "$($cp.Description) - $($cp.CreationTime)"
        }
    }
    else {
        Write-Log -Level "INFO" -Message "No WinSpec checkpoints found"
    }
}

Export-ModuleMember -Function @(
    "Import-Spec"
    "Resolve-Spec"
    "Merge-Hashtables"
    "Test-Spec"
    "Import-Manager"
    "Import-Provider"  # Backward compatibility alias
    "Import-BuiltInTrigger"
    "Invoke-DeclarativeProviders"
    "Invoke-Triggers"
    "Invoke-CustomTrigger"
    "Resolve-ConfigLocation"
    "Find-TriggerScript"
    "Write-Report"
    "Invoke-WinSpec"
    "Get-SystemStatus"
    "Get-ProviderDescription"
    "Discover-ProvidersFromPath"
)
