# WinSpec Refactor Plan

## Executive Summary

This document identifies critical bugs, architectural issues, and inconsistencies in the WinSpec codebase, and proposes simple, robust fixes prioritizing maintainability over boilerplate.

---

## Critical Issues (Bugs)

### 1. Broken Provider Discovery Call Pattern
**Location**: `winspec/winspec.ps1:159`

**Current Code**:
```powershell
$info = & "$providerName\Get-ProviderInfo" -ErrorAction SilentlyContinue
```

**Problem**: PowerShell does not use backslash for command invocation. This creates invalid command names like `"Registry\Get-ProviderInfo"`.

**Fix**:
```powershell
$info = Get-ProviderInfo -ErrorAction SilentlyContinue
```
After importing the module, the function is available in the session.

---

### 2. `Invoke-Triggers` Called with Missing Parameters
**Location**: `winspec/winspec.ps1:242`

**Current Code**:
```powershell
$results = Invoke-Triggers -TriggerConfig $triggerConfig
```

**Problem**: The function requires `$SpecPath` and `$ConfigPath` for proper trigger script discovery (see `core.psm1:365-379`). Without these, custom triggers in spec/config directories are never found.

**Fix**:
```powershell
$results = Invoke-Triggers -TriggerConfig $triggerConfig -SpecPath $Spec -ConfigPath $ConfigPath
```

---

### 3. Inconsistent `$ConfigPath` Propagation
**Locations**:
- Line 254: `$result = Invoke-WinSpec -Spec $Spec ...` - missing `-ConfigPath $ConfigPath`
- Line 262: `Invoke-TriggerCommand -TriggerName $Name ...` - missing `-ConfigPath $ConfigPath`
- Line 288: `$valid = Invoke-Validate -SpecPath $Spec` - missing `-ConfigPath $ConfigPath`

**Problem**: User provider/trigger directories are never searched despite being documented.

**Fix**: Add `-ConfigPath $ConfigPath` to all three calls.

---

## Architecture Issues

### 4. Nested Functions in `Show-Providers`
**Location**: `winspec/winspec.ps1:129-170`

**Problem**: `Get-ProviderDescription` and `Discover-ProvidersFromPath` are defined inside `Show-Providers`, hurting:
- Testability (cannot test independently)
- Reusability
- Performance (new function instances on every call)

**Fix**: Move to module level in `core.psm1` or create a new `providers.psm1` module.

---

### 5. Hardcoded Provider Lists in Multiple Places

| File | Line | Hardcoded List |
|------|------|----------------|
| `schema.psm1` | 136-137 | `$declarativeProviders`, `$triggerProviders` |
| `core.psm1` | 160 | `@("Registry", "Package", "Service", "Feature")` |
| `winspec.ps1` | 174-198 | Discovery logic for managers/triggers |

**Problem**: Adding a provider requires editing 3+ files. Violates DRY.

**Fix**: Dynamic discovery from filesystem:
```powershell
function Get-DiscoveredProviders {
    param([string]$Path, [string]$Type)
    Get-ChildItem -Path $Path -Filter "*.psm1" | ForEach-Object {
        Import-Module $_.FullName -Force
        Get-ProviderInfo | Where-Object { $_.Type -eq $Type }
    }
}
```

---

### 6. Duplicate Registry Map Functions
**Locations**:
- `registry-maps.ps1:62-73`: `Get-RegistryMaps`
- `registry-maps.ps1:75-83`: `Get-RegistryMap` (just calls `Get-RegistryMaps`)
- `schema.psm1:26-35`: Another `Get-RegistryMap` wrapper

**Fix**: Remove redundant wrappers, keep only `Get-RegistryMaps`.

---

### 7. Unused Parameter in `Resolve-ConfigLocation`
**Location**: `core.psm1:206-242`

**Current Code**:
```powershell
function Resolve-ConfigLocation {
    param(
        [string]$ConfigPath,
        [string]$SpecPath  # ← Never used
    )
```

**Fix**: Either use `$SpecPath` to check for `.winspec.ps1` next to spec file, or remove the parameter.

---

## Inconsistencies

### 8. Command Naming Inconsistency
**Location**: `winspec/winspec.ps1:8`

**Problem**: `providers` is the only plural command. Others are singular/imperative: `apply`, `trigger`, `status`, `rollback`, `validate`, `help`.

**Fix**: Change to `provider` for consistency.

---

### 9. Trigger Option Type Handling Inconsistency
- `winspec.ps1:27`: `$Option` is untyped
- `activation.psm1:16-17`: Accepts `$Option = $true` (bool default)
- `core.psm1:397`: Checks `if ($trigger.ContainsKey('Value'))`

**Problem**: Inconsistent handling of trigger options/values.

**Fix**: Standardize on `[object]$Option` with proper type checking in trigger implementations.

---

### 10. `$Script:WinspecRoot` Redefinition
**Locations**:
- `winspec.ps1:40`: `$Script:WinspecRoot = $PSScriptRoot`
- `core.psm1:3`: `$Script:WinspecRoot = $PSScriptRoot`

**Problem**: Both define the same script-scope variable. Works by coincidence but fragile.

**Fix**: Use `$PSScriptRoot` directly where needed, or define once in entry point and pass as parameter to functions.

---

## Code Quality Issues

### 11. Silent Error Swallowing
**Location**: `winspec/winspec.ps1:166-168`

**Current Code**:
```powershell
catch {
    # Skip providers that fail to load
}
```

**Problem**: Debugging impossible when providers silently fail.

**Fix**:
```powershell
catch {
    Write-Verbose "Failed to load provider $($file.Name): $_"
}
```

---

### 12. `Invoke-ActivationTrigger` Double ShouldProcess
**Location**: `triggers/activation.psm1:22-46`

**Problem**: Two `ShouldProcess` calls for the same operation is confusing. First one is dead code.

**Fix**: Remove first `ShouldProcess` block, keep only the second one that actually gates execution.

---

## Proposed Implementation Order

### Phase 1: Fix Critical Bugs (Immediate)
1. Fix provider discovery call pattern (Issue #1)
2. Fix `$ConfigPath` propagation (Issues #2, #3)

### Phase 2: Simplify Architecture
1. Extract nested functions from `Show-Providers` (Issue #4)
2. Implement dynamic provider discovery (Issue #5)
3. Remove duplicate registry map functions (Issue #6)

### Phase 3: Clean Up
1. Fix naming inconsistencies (Issue #8)
2. Add error logging (Issue #11)
3. Fix ShouldProcess duplication (Issue #12)

---

## Design Principles

1. **Discover over configure**: Scan filesystem instead of hardcoding lists
2. **Fail visible**: Log warnings instead of silent failures
3. **Single source of truth**: Provider metadata comes from provider files
4. **Simple over robust**: Prefer straightforward code over complex abstractions
