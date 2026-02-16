# providers/service.psm1 - Declarative Windows services provider

# Import dependent modules
Import-Module (Join-Path $PSScriptRoot "..\logging.psm1") -Force

function Get-ProviderInfo {
    return @{
        Name = "Service"
        Type = "Declarative"
    }
}

function Get-ServiceState {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [string]$ServiceName
    )
    
    try {
        $service = Get-Service -Name $ServiceName -ErrorAction SilentlyContinue
        if ($service) {
            $startup = (Get-WmiObject -Class Win32_Service -Filter "Name='$ServiceName'" -ErrorAction SilentlyContinue).StartMode
            return @{
                State   = $service.Status.ToString().ToLower()
                Startup = $startup.ToLower()
            }
        }
        return $null
    }
    catch {
        return $null
    }
}

function Test-ServiceState {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [hashtable]$Desired
    )
    
    $allInDesiredState = $true
    
    foreach ($serviceName in $Desired.Keys) {
        $desiredConfig = $Desired[$serviceName]
        $currentState = Get-ServiceState -ServiceName $serviceName
        
        if ($null -eq $currentState) {
            Write-Log -Level "WARN" -Message "Service not found: $serviceName"
            continue
        }
        
        if ($desiredConfig.State -and $currentState.State -ne $desiredConfig.State) {
            $allInDesiredState = $false
        }
        
        if ($desiredConfig.Startup -and $currentState.Startup -ne $desiredConfig.Startup) {
            $allInDesiredState = $false
        }
    }
    
    return $allInDesiredState
}

function Set-ServiceState {
    [CmdletBinding(SupportsShouldProcess = $true)]
    param (
        [Parameter(Mandatory = $true)]
        [hashtable]$Desired
    )
    
    $results = @{}
    
    foreach ($serviceName in $Desired.Keys) {
        $desiredConfig = $Desired[$serviceName]
        $currentState = Get-ServiceState -ServiceName $serviceName
        
        if ($null -eq $currentState) {
            Write-Log -Level "ERROR" -Message "Service not found: $serviceName"
            $results[$serviceName] = @{ Status = "Error"; Message = "Service not found" }
            continue
        }
        
        $serviceResults = @{}
        
        # Handle Startup configuration
        if ($desiredConfig.Startup) {
            if ($currentState.Startup -eq $desiredConfig.Startup) {
                Write-LogOk -Name "$serviceName.Startup" -DesiredValue $desiredConfig.Startup
                $serviceResults["Startup"] = @{ Status = "AlreadySet" }
            }
            else {
                Write-LogChange -Name "$serviceName.Startup" -CurrentValue $currentState.Startup -DesiredValue $desiredConfig.Startup
                
                if ($PSCmdlet.ShouldProcess("$serviceName Startup", "Set to '$($desiredConfig.Startup)'")) {
                    try {
                        Set-Service -Name $serviceName -StartupType $desiredConfig.Startup -ErrorAction Stop
                        Write-LogApplied -Name "$serviceName.Startup" -DesiredValue $desiredConfig.Startup
                        $serviceResults["Startup"] = @{ Status = "Applied" }
                    }
                    catch {
                        Write-LogError -Name "$serviceName.Startup" -Details $_.Exception.Message
                        $serviceResults["Startup"] = @{ Status = "Error"; Message = $_.Exception.Message }
                    }
                }
            }
        }
        
        # Handle State configuration
        if ($desiredConfig.State) {
            $desiredState = $desiredConfig.State
            $currentStateValue = $currentState.State
            
            # Map running/stopped to PowerShell service status
            $isRunning = $currentStateValue -eq "running"
            $shouldBeRunning = $desiredState -eq "running"
            
            if ($isRunning -eq $shouldBeRunning) {
                Write-LogOk -Name "$serviceName.State" -DesiredValue $desiredState
                $serviceResults["State"] = @{ Status = "AlreadySet" }
            }
            else {
                Write-LogChange -Name "$serviceName.State" -CurrentValue $currentStateValue -DesiredValue $desiredState
                
                if ($PSCmdlet.ShouldProcess("$serviceName State", "Set to '$desiredState'")) {
                    try {
                        if ($shouldBeRunning) {
                            Start-Service -Name $serviceName -ErrorAction Stop
                        }
                        else {
                            Stop-Service -Name $serviceName -Force -ErrorAction Stop
                        }
                        Write-LogApplied -Name "$serviceName.State" -DesiredValue $desiredState
                        $serviceResults["State"] = @{ Status = "Applied" }
                    }
                    catch {
                        Write-LogError -Name "$serviceName.State" -Details $_.Exception.Message
                        $serviceResults["State"] = @{ Status = "Error"; Message = $_.Exception.Message }
                    }
                }
            }
        }
        
        $results[$serviceName] = $serviceResults
    }
    
    return $results
}

Export-ModuleMember -Function @(
    "Get-ProviderInfo"
    "Get-ServiceState"
    "Test-ServiceState"
    "Set-ServiceState"
)
