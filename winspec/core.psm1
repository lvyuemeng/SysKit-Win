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

function Import-Provider {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [string]$Name
    )
    
    $providerPath = Join-Path $Script:WinspecRoot "providers\$Name.psm1"
    
    if (-not (Test-Path $providerPath)) {
        Write-Log -Level "ERROR" -Message "Provider not found: $Name"
        return $null
    }
    
    try {
        Import-Module $providerPath -Force
        Write-Log -Level "OK" -Message "Loaded provider: $Name"
        return $true
    }
    catch {
        Write-Log -Level "ERROR" -Message "Failed to load provider: $Name"
        Write-Log -Level "ERROR" -Message $_.Exception.Message
        return $null
    }
}

function Invoke-DeclarativeProviders {
    [CmdletBinding(SupportsShouldProcess = $true)]
    param (
        [Parameter(Mandatory = $true)]
        [hashtable]$Config,
        
        [Parameter(Mandatory = $false)]
        [switch]$WhatIf
    )
    
    $results = @{}
    $declarativeProviders = @("Registry", "Package", "Service", "Feature")
    
    foreach ($providerName in $declarativeProviders) {
        if ($Config.$providerName) {
            Write-LogSection -Name $providerName
            
            if (Import-Provider -Name $providerName) {
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

function Invoke-Triggers {
    [CmdletBinding(SupportsShouldProcess = $true)]
    param (
        [Parameter(Mandatory = $true)]
        [hashtable]$TriggerConfig,
        
        [Parameter(Mandatory = $false)]
        [switch]$WhatIf
    )
    
    $results = @{}
    
    foreach ($triggerName in $TriggerConfig.Keys) {
        Write-LogSection -Name "Trigger: $triggerName"
        
        if (Import-Provider -Name $triggerName) {
            $option = $TriggerConfig[$triggerName]
            
            $invokeTriggerCmd = Get-Command "Invoke-$($triggerName)Trigger" -ErrorAction SilentlyContinue
            
            if ($invokeTriggerCmd) {
                if ($WhatIf) {
                    Write-Log -Level "INFO" -Message "Would trigger $triggerName (dry run)"
                    $results[$triggerName] = @{ Status = "DryRun"; Option = $option }
                }
                else {
                    if ($PSCmdlet.ShouldProcess($triggerName, "Execute trigger")) {
                        $results[$triggerName] = & $invokeTriggerCmd -Option $option
                    }
                }
            }
            else {
                Write-Log -Level "ERROR" -Message "Trigger $triggerName is missing Invoke-Trigger function"
                $results[$triggerName] = @{ Status = "Error"; Message = "Missing trigger function" }
            }
        }
        else {
            $results[$triggerName] = @{ Status = "Error"; Message = "Failed to load trigger provider" }
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
    
    # 4. Create checkpoint if requested
    if ($Checkpoint -and -not $DryRun) {
        $checkpointResult = New-Checkpoint -Name "WinSpec-$(Get-Date -Format 'yyyyMMdd-HHmmss')"
        if (-not $checkpointResult.Success) {
            Write-Log -Level "WARN" -Message "Checkpoint creation failed, continuing anyway..."
        }
    }
    
    # 5. Execute declarative providers (idempotent)
    $results = Invoke-DeclarativeProviders -Config $resolved -WhatIf:$DryRun
    
    # 6. Execute triggers if requested (non-idempotent)
    if ($WithTriggers -and $resolved.Trigger) {
        $results.Triggers = Invoke-Triggers -TriggerConfig $resolved.Trigger -WhatIf:$DryRun
    }
    
    # 7. Report
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
    $registryMap = Get-RegistryMap
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
    "Import-Provider"
    "Invoke-DeclarativeProviders"
    "Invoke-Triggers"
    "Write-Report"
    "Invoke-WinSpec"
    "Get-SystemStatus"
)
