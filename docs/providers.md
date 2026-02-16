# WinSpec Provider Development Guide

This document describes how to develop custom providers for WinSpec.

---

## Provider Types

WinSpec supports two types of providers:

| Type | Characteristics | Idempotent | Examples |
|------|-----------------|------------|----------|
| **Declarative** | State-based, testable | Yes | Registry, Service, Feature, Package |
| **Trigger** | Action-based, fire-and-forget | No | Activation, Debloat, Office |

---

## Declarative Provider Contract

Declarative providers must implement these functions:

```powershell
# providers/example.psm1

function Get-ProviderInfo {
    return @{
        Name = "Example"
        Type = "Declarative"
    }
}

function Test-ExampleState {
    param ([hashtable]$Desired)
    
    # Check if current state matches desired
    # Returns: $true if in desired state
}

function Set-ExampleState {
    param (
        [hashtable]$Desired,
        [switch]$WhatIf
    )
    
    # Apply desired state (only changes needed)
    # Returns: hashtable with results
}

Export-ModuleMember Get-ProviderInfo, Test-ExampleState, Set-ExampleState
```

### Function Naming Convention

Functions must follow the naming pattern:
- `Test-{ProviderName}State` - Test current state
- `Set-{ProviderName}State` - Apply desired state

---

## Trigger Provider Contract

Trigger providers must implement these functions:

```powershell
# providers/example-trigger.psm1

function Get-ProviderInfo {
    return @{
        Name = "ExampleTrigger"
        Type = "Trigger"
    }
}

function Invoke-ExampleTriggerTrigger {
    param (
        $Option,         # Can be: $true, string, or hashtable
        [switch]$WhatIf
    )
    
    # Execute the trigger action
    # Returns: hashtable with results
}

Export-ModuleMember Get-ProviderInfo, Invoke-ExampleTriggerTrigger
```

### Function Naming Convention

Trigger functions must follow the naming pattern:
- `Invoke-{ProviderName}Trigger` - Execute trigger

---

## Provider Template

### Declarative Provider Template

```powershell
# providers/myprovider.psm1

using module "..\logging.psm1"

function Get-ProviderInfo {
    return @{
        Name = "MyProvider"
        Type = "Declarative"
    }
}

function Get-MyProviderState {
    param ([string]$ItemName)
    # Get current state for an item
}

function Test-MyProviderState {
    [CmdletBinding()]
    param ([hashtable]$Desired)
    
    $allInDesiredState = $true
    
    foreach ($item in $Desired.Keys) {
        $currentState = Get-MyProviderState -ItemName $item
        $desiredState = $Desired[$item]
        
        if ($currentState -ne $desiredState) {
            $allInDesiredState = $false
        }
    }
    
    return $allInDesiredState
}

function Set-MyProviderState {
    [CmdletBinding(SupportsShouldProcess = $true)]
    param (
        [hashtable]$Desired,
        [switch]$WhatIf
    )
    
    $results = @{}
    
    foreach ($item in $Desired.Keys) {
        $desiredState = $Desired[$item]
        $currentState = Get-MyProviderState -ItemName $item
        
        if ($currentState -eq $desiredState) {
            Write-LogOk -Name $item -DesiredValue $desiredState
            $results[$item] = @{ Status = "AlreadySet" }
            continue
        }
        
        Write-LogChange -Name $item -CurrentValue $currentState -DesiredValue $desiredState
        
        if ($PSCmdlet.ShouldProcess($item, "Set state")) {
            try {
                # Apply the change here
                Write-LogApplied -Name $item -DesiredValue $desiredState
                $results[$item] = @{ Status = "Applied" }
            }
            catch {
                Write-LogError -Name $item -Details $_.Exception.Message
                $results[$item] = @{ Status = "Error"; Message = $_.Exception.Message }
            }
        }
    }
    
    return $results
}

Export-ModuleMember -Function @(
    "Get-ProviderInfo"
    "Test-MyProviderState"
    "Set-MyProviderState"
)
```

### Trigger Provider Template

```powershell
# providers/mytrigger.psm1

using module "..\logging.psm1"

function Get-ProviderInfo {
    return @{
        Name = "MyTrigger"
        Type = "Trigger"
    }
}

function Invoke-MyTriggerTrigger {
    [CmdletBinding(SupportsShouldProcess = $true)]
    param (
        $Option = $true,
        [switch]$WhatIf
    )
    
    Write-Log -Level "INFO" -Message "Triggering MyTrigger..."
    
    if ($WhatIf) {
        Write-Log -Level "INFO" -Message "Would trigger MyTrigger (dry run)"
        return @{
            Status = "DryRun"
            Message = "Would execute trigger"
        }
    }
    
    if ($PSCmdlet.ShouldProcess("MyTrigger", "Execute")) {
        try {
            # Execute the trigger action here
            
            Write-Log -Level "APPLIED" -Message "MyTrigger executed"
            return @{
                Status = "Success"
                Message = "Trigger executed successfully"
            }
        }
        catch {
            Write-Log -Level "ERROR" -Message "MyTrigger failed: $($_.Exception.Message)"
            return @{
                Status = "Error"
                Message = $_.Exception.Message
            }
        }
    }
    
    return @{
        Status = "Skipped"
        Message = "User declined"
    }
}

Export-ModuleMember -Function @(
    "Get-ProviderInfo"
    "Invoke-MyTriggerTrigger"
)
```

---

## Best Practices

### 1. Use Logging Module

Always import and use the logging module for consistent output:

```powershell
using module "..\logging.psm1"

Write-Log -Level "INFO" -Message "Processing..."
Write-LogOk -Name $item -DesiredValue $value
Write-LogChange -Name $item -CurrentValue $current -DesiredValue $desired
Write-LogApplied -Name $item -DesiredValue $value
Write-LogError -Name $item -Details $error
```

### 2. Support ShouldProcess

For providers that make changes, support `-WhatIf` and confirmation:

```powershell
[CmdletBinding(SupportsShouldProcess = $true)]
param (...)

if ($PSCmdlet.ShouldProcess($target, $action)) {
    # Make changes
}
```

### 3. Return Consistent Results

Always return a hashtable with at minimum a `Status` key:

```powershell
@{
    Status = "Applied"  # or "AlreadySet", "Error", "DryRun", "Skipped"
    # Additional context as needed
}
```

### 4. Handle Errors Gracefully

Use try/catch and provide meaningful error messages:

```powershell
try {
    # Operation
}
catch {
    Write-LogError -Name $item -Details $_.Exception.Message
    $results[$item] = @{ Status = "Error"; Message = $_.Exception.Message }
}
```

---

## Registering Providers

Providers are automatically discovered when placed in the `providers/` directory. The naming convention is:

- File: `providers/{name}.psm1`
- Functions: `Test-{Name}State`, `Set-{Name}State`, or `Invoke-{Name}Trigger`

---

## Testing Providers

Test your provider manually:

```powershell
# Import the provider
Import-Module .\winspec\providers\myprovider.psm1 -Force

# Test Get-ProviderInfo
Get-ProviderInfo

# Test state checking
Test-MyProviderState -Desired @{ item1 = "value1" }

# Test state setting (dry run)
Set-MyProviderState -Desired @{ item1 = "value1" } -WhatIf
```

---

## Schema Validation

To add validation for your provider, extend the schema in `schema.psm1`:

```powershell
$Script:SpecSchema = @{
    # ... existing schemas ...
    MyProvider = @{ Type = "hashtable"; Required = $false }
}
```

---

*WinSpec Provider Development Guide v1.0*
