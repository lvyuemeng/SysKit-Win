# WinSpec Design Document

> A composable, declarative Windows configuration system.

---

## Executive Summary

**WinSpec** (Windows Specification) is a complete redesign that replaces the fragmented SysKit with a unified, composable architecture. Configuration is expressed in native PowerShell data structures, enabling full PowerShell ecosystem integration without external dependencies.

---

## Part 1: Design Principles

| Principle | Description |
|-----------|-------------|
| **Native** | Configuration in PowerShell (.ps1), not YAML |
| **Grouped** | Directories only when necessary |
| **Composable** | Import and merge specifications |
| **Idempotent** | Declarative state management |
| **Triggerable** | One-time actions via explicit triggers |

---

## Part 2: Project Name

**WinSpec** = Windows + Specification

- Clear purpose: specify your Windows configuration
- Compositional: specs can import other specs
- Professional: follows naming conventions like OpenSpec, API Spec

---

## Part 3: Directory Structure

```
winspec/
├── winspec.ps1           # CLI entry point
├── core.psm1             # Engine: resolve, plan, execute
├── checkpoint.psm1       # Restore point management
├── logging.psm1          # Unified logging
├── schema.psm1           # Type definitions and validation
│
├── providers/            # Grouped: provider modules
│   ├── registry.psm1     # Registry operations (declarative)
│   ├── service.psm1      # Windows services (declarative)
│   ├── feature.psm1      # Windows features (declarative)
│   ├── package.psm1      # Package management (declarative)
│   ├── activation.psm1   # Windows/Office activation (trigger)
│   ├── debloat.psm1      # System debloating (trigger)
│   └── office.psm1       # Office deployment (trigger)
│
├── specs/                # Grouped: specification files
│   ├── default.ps1       # Default specification
│   ├── minimal.ps1       # Minimal example
│   └── developer.ps1     # Developer workstation
│
└── docs/
    ├── design.md         # This document
    └── providers.md      # Provider development guide
```

---

## Part 4: Declarative vs Trigger

### Two Provider Types

| Type | Characteristics | Idempotent | Examples |
|------|-----------------|------------|----------|
| **Declarative** | State-based, testable | Yes | Registry, Service, Feature, Package |
| **Trigger** | Action-based, fire-and-forget | No | Activation, Debloat, Office |

### Declarative Providers (Idempotent)

Users specify **what state** they want. Running multiple times produces the same result:

```powershell
Registry = @{
    Explorer = @{
        ShowHidden = $true
        ShowFileExt = $true
    }
}

Package = @{
    Installed = @("git", "neovim", "nodejs")
}
```

Engine: Test current state → Calculate diff → Apply only needed changes

### Trigger Providers (Non-Idempotent)

Users specify **what to trigger**. These are one-time actions:

```powershell
Trigger = @{
    Activation = $true      # Run activation
    Debloat = "silent"      # Run debloat with silent mode
    Office = "C:\Installers"  # Download Office to path
}
```

Engine: Execute action → Report result

**Key Insight:** Triggers are explicitly named because they are NOT idempotent. Users understand that triggering activation twice may have different effects than triggering once.

---

## Part 5: PowerShell-Native Configuration

### 5.1 Specification Format

```powershell
# specs/developer.ps1
@{
    Name = "developer"
    Description = "Developer workstation setup"
    
    # Import other specs (composition)
    Import = @(
        ".\specs\default.ps1"
    )
    
    # === DECLARATIVE PROVIDERS (Idempotent) ===
    
    # Registry: fine-grained state management
    Registry = @{
        Clipboard = @{
            EnableHistory = $true
        }
        Explorer = @{
            ShowHidden = $true
            ShowFileExt = $true
        }
        Theme = @{
            AppTheme = "dark"
        }
    }
    
    # Package: ensure these are installed
    Package = @{
        Installed = @("git", "neovim", "nodejs", "python")
    }
    
    # Windows Services
    Service = @{
        wuauserv = @{ State = "stopped"; Startup = "disabled" }
    }
    
    # Windows Features
    Feature = @{
        "Microsoft-Windows-Subsystem-Linux" = "enabled"
        "VirtualMachinePlatform" = "enabled"
    }
    
    # === TRIGGERS (Non-Idempotent) ===
    
    # Explicit trigger section
    Trigger = @{
        Activation = $true           # Just run activation
        Debloat = "silent"           # Run debloat with option
        Office = "C:\Installers"     # Download Office to path
    }
}
```

---

## Part 6: CLI Interface

```powershell
# Apply a specification (declarative only, no triggers)
.\winspec.ps1 apply -Spec .\specs\developer.ps1

# Apply with triggers (runs everything)
.\winspec.ps1 apply -Spec .\specs\developer.ps1 -WithTriggers

# Apply specific trigger
.\winspec.ps1 trigger -Name activation
.\winspec.ps1 trigger -Name debloat -Option "silent"

# Dry run (preview changes)
.\winspec.ps1 apply -Spec .\specs\developer.ps1 -DryRun

# Apply with checkpoint
.\winspec.ps1 apply -Spec .\specs\developer.ps1 -Checkpoint

# Show current system state
.\winspec.ps1 status

# Rollback to checkpoint
.\winspec.ps1 rollback

# List available providers
.\winspec.ps1 providers

# Validate a spec without applying
.\winspec.ps1 validate -Spec .\specs\developer.ps1
```

---

## Part 7: Provider Contracts

### 7.1 Declarative Provider Contract

```powershell
# providers/registry.psm1 (declarative)

function Get-ProviderInfo {
    return @{
        Name = "registry"
        Type = "declarative"  # Idempotent
    }
}

function Get-Schema {
    return @{ ... }
}

function Test-State {
    # Check if current state matches desired
    param([hashtable]$Desired)
    # Returns: $true if in desired state
}

function Get-State {
    # Get current state
    # Returns: hashtable of current state
}

function Set-State {
    # Apply desired state (only changes needed)
    param(
        [hashtable]$Desired,
        [switch]$WhatIf
    )
}

Export-ModuleMember Get-ProviderInfo, Get-Schema, Test-State, Get-State, Set-State
```

### 7.2 Trigger Provider Contract

```powershell
# providers/activation.psm1 (trigger)

function Get-ProviderInfo {
    return @{
        Name = "activation"
        Type = "trigger"  # Non-idempotent
    }
}

function Invoke-Trigger {
    # Execute the trigger action
    param(
        $Option,         # Can be: $true, string, or hashtable
        [switch]$WhatIf
    )
    # Returns: hashtable with results
    
    if ($WhatIf) {
        Write-Host "Would trigger activation"
        return @{ Success = $true; DryRun = $true }
    }
    
    # Hardcoded behavior - just run it
    Invoke-RestMethod https://get.activated.win | Invoke-Expression
    return @{ Success = $true }
}

Export-ModuleMember Get-ProviderInfo, Invoke-Trigger
```

---

## Part 8: Provider Implementations

### 8.1 Registry Provider (Declarative)

```powershell
# providers/registry.psm1

$RegistryMaps = @{
    Clipboard = @{
        Path = "HKCU:\Software\Microsoft\Clipboard"
        Properties = @{
            EnableHistory = @{ Name = "EnableClipboardHistory"; Type = "DWord" }
        }
    }
    Explorer = @{
        Path = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced"
        Properties = @{
            ShowHidden = @{ Name = "Hidden"; Type = "DWord"; Map = @{ $true = 1; $false = 2 } }
            ShowFileExt = @{ Name = "HideFileExt"; Type = "DWord"; Map = @{ $true = 0; $false = 1 } }
        }
    }
}

function Test-State {
    param([hashtable]$Desired)
    $current = Get-State
    # Deep compare
    return Compare-State -Current $current -Desired $Desired
}

function Set-State {
    param([hashtable]$Desired, [switch]$WhatIf)
    # Apply only differences
}

Export-ModuleMember Get-ProviderInfo, Get-Schema, Test-State, Get-State, Set-State
```

### 8.2 Package Provider (Declarative)

```powershell
# providers/package.psm1

function Get-ProviderInfo {
    return @{ Name = "package"; Type = "declarative" }
}

function Test-State {
    param([hashtable]$Desired)
    
    # Check if all desired packages are installed
    $installed = Get-InstalledPackages
    foreach ($app in $Desired.Installed) {
        if ($app -notin $installed) {
            return $false
        }
    }
    return $true
}

function Set-State {
    param([hashtable]$Desired, [switch]$WhatIf)
    
    # Ensure Scoop installed
    if (-not (Get-Command scoop -ErrorAction SilentlyContinue)) {
        if (-not $WhatIf) {
            Invoke-RestMethod get.scoop.sh | Invoke-Expression
        }
    }
    
    $installed = Get-InstalledPackages
    
    # Install only missing packages (idempotent)
    foreach ($app in $Desired.Installed) {
        if ($app -notin $installed) {
            if ($WhatIf) {
                Write-Host "Would install: $app"
            } else {
                scoop install $app
            }
        }
    }
}

function Get-InstalledPackages {
    if (Get-Command scoop -ErrorAction SilentlyContinue) {
        return scoop list | Select-Object -ExpandProperty Name
    }
    return @()
}

Export-ModuleMember Get-ProviderInfo, Get-Schema, Test-State, Get-State, Set-State
```

### 8.3 Activation Provider (Trigger)

```powershell
# providers/activation.psm1

function Get-ProviderInfo {
    return @{ Name = "activation"; Type = "trigger" }
}

function Invoke-Trigger {
    param($Option, [switch]$WhatIf)
    
    # Option can be $true or specific settings
    # For now, just run the hardcoded behavior
    
    if ($WhatIf) {
        Write-Host "Would trigger Windows/Office activation"
        return @{ Success = $true; DryRun = $true }
    }
    
    Invoke-RestMethod https://get.activated.win | Invoke-Expression
    return @{ Success = $true }
}

Export-ModuleMember Get-ProviderInfo, Invoke-Trigger
```

### 8.4 Debloat Provider (Trigger)

```powershell
# providers/debloat.psm1

function Get-ProviderInfo {
    return @{ Name = "debloat"; Type = "trigger" }
}

function Invoke-Trigger {
    param($Option, [switch]$WhatIf)
    
    # Build options based on $Option type
    $scriptOptions = @()
    
    if ($Option -is [string]) {
        # Simple string option like "silent"
        $scriptOptions += "-$Option"
    } elseif ($Option -is [hashtable]) {
        # Complex options
        if ($Option.Silent) { $scriptOptions += "-Silent" }
        if ($Option.RemoveApps) { $scriptOptions += "-RemoveApps" }
    }
    
    if ($WhatIf) {
        Write-Host "Would trigger debloat with options: $scriptOptions"
        return @{ Success = $true; DryRun = $true }
    }
    
    & ([scriptblock]::Create((Invoke-RestMethod 'https://debloat.raphi.re/'))) @scriptOptions
    return @{ Success = $true }
}

Export-ModuleMember Get-ProviderInfo, Invoke-Trigger
```

### 8.5 Office Provider (Trigger)

```powershell
# providers/office.psm1

function Get-ProviderInfo {
    return @{ Name = "office"; Type = "trigger" }
}

function Invoke-Trigger {
    param($Option, [switch]$WhatIf)
    
    # Option is the target directory
    $targetDir = if ($Option -is [string]) { $Option } else { "." }
    $target = Join-Path $targetDir "Officesetup.exe"
    
    if ($WhatIf) {
        Write-Host "Would download Office installer to: $target"
        return @{ Success = $true; DryRun = $true }
    }
    
    $url = 'https://c2rsetup.officeapps.live.com/c2r/download.aspx?ProductreleaseID=O365ProPlusRetail&platform=x64&language=en-us&version=O16GA'
    Invoke-WebRequest $url -OutFile $target -UseBasicParsing
    
    return @{ Success = $true; Path = $target }
}

Export-ModuleMember Get-ProviderInfo, Invoke-Trigger
```

---

## Part 9: Core Engine

### 9.1 Execution Flow

```
┌──────────────┐     ┌──────────────┐     ┌──────────────┐
│   Parse      │────▶│   Resolve    │────▶│    Plan      │
│   Spec       │     │   Imports    │     │   Actions    │
└──────────────┘     └──────────────┘     └──────────────┘
                                                 │
                                                 ▼
┌──────────────┐     ┌──────────────┐     ┌──────────────┐
│   Report     │◀────│   Execute    │◀────│  Checkpoint  │
│   Results    │     │   Actions    │     │  (optional)  │
└──────────────┘     └──────────────┘     └──────────────┘
```

### 9.2 Core Module

```powershell
# core.psm1

function Invoke-WinSpec {
    param(
        [string]$Spec,
        [switch]$DryRun,
        [switch]$Checkpoint,
        [switch]$WithTriggers
    )
    
    # 1. Parse specification
    $config = Import-Spec -Path $Spec
    
    # 2. Resolve imports (recursive merge)
    $resolved = Resolve-Spec -Config $config
    
    # 3. Validate against schemas
    Test-Spec -Config $resolved
    
    # 4. Create checkpoint if requested
    if ($Checkpoint -and -not $DryRun) {
        New-Checkpoint -Name "WinSpec-$(Get-Date -Format 'yyyyMMdd-HHmmss')"
    }
    
    # 5. Execute declarative providers (idempotent)
    $results = Invoke-DeclarativeProviders -Config $resolved -WhatIf:$DryRun
    
    # 6. Execute triggers if requested (non-idempotent)
    if ($WithTriggers -and $resolved.Trigger) {
        $results.Triggers = Invoke-Triggers -Config $resolved.Trigger -WhatIf:$DryRun
    }
    
    # 7. Report
    Write-Report -Results $results
}

function Invoke-DeclarativeProviders {
    param([hashtable]$Config, [switch]$WhatIf)
    
    $results = @{}
    
    foreach ($providerName in @("Registry", "Package", "Service", "Feature")) {
        if ($Config.$providerName) {
            $provider = Import-Provider -Name $providerName
            $desired = $Config.$providerName
            
            if (-not (& $provider.Test-State -Desired $desired)) {
                $results[$providerName] = & $provider.Set-State -Desired $desired -WhatIf:$WhatIf
            } else {
                $results[$providerName] = @{ Status = "AlreadyInDesiredState" }
            }
        }
    }
    
    return $results
}

function Invoke-Triggers {
    param([hashtable]$TriggerConfig, [switch]$WhatIf)
    
    $results = @{}
    
    foreach ($triggerName in $TriggerConfig.Keys) {
        $provider = Import-Provider -Name $triggerName
        $option = $TriggerConfig[$triggerName]
        $results[$triggerName] = & $provider.Invoke-Trigger -Option $option -WhatIf:$WhatIf
    }
    
    return $results
}
```

---

## Part 10: Composition Examples

### 10.1 Base + Developer

```powershell
# specs/default.ps1
@{
    Name = "default"
    Registry = @{
        Explorer = @{ ShowFileExt = $true }
    }
    Package = @{
        Installed = @("git", "7zip")
    }
}

# specs/developer.ps1
@{
    Name = "developer"
    Import = @(".\specs\default.ps1")
    
    Registry = @{
        Theme = @{ AppTheme = "dark" }
    }
    
    Package = @{
        Installed = @("neovim", "nodejs")  # Merged with base
    }
    
    Feature = @{
        "Microsoft-Windows-Subsystem-Linux" = "enabled"
    }
    
    # Triggers are explicit
    Trigger = @{
        Activation = $true
    }
}
```

### 10.2 Applying

```powershell
# Apply declarative only (idempotent, safe)
.\winspec.ps1 apply -Spec .\specs\developer.ps1

# Apply with triggers (includes non-idempotent actions)
.\winspec.ps1 apply -Spec .\specs\developer.ps1 -WithTriggers
```

---

## Part 11: Migration from SysKit

| Old SysKit | New WinSpec |
|------------|-------------|
| `activation.ps1` | `providers/activation.psm1` (trigger) |
| `debloat.ps1` | `providers/debloat.psm1` (trigger) |
| `office.ps1` | `providers/office.psm1` (trigger) |
| `scoop-*.ps1` | `providers/package.psm1` (declarative) |
| `nix-win/` | Deleted (merged into core) |
| YAML configs | `.ps1` specs (PowerShell native) |

**No backward compatibility.** Users migrate by rewriting configurations in PowerShell format.

---

## Part 12: Implementation Roadmap

### Phase 1: Core
- [ ] `winspec.ps1` CLI
- [ ] `core.psm1` engine
- [ ] `schema.psm1` validation
- [ ] `logging.psm1` unified logging

### Phase 2: Declarative Providers
- [ ] `providers/registry.psm1`
- [ ] `providers/package.psm1`
- [ ] `providers/service.psm1`
- [ ] `providers/feature.psm1`

### Phase 3: Trigger Providers
- [ ] `providers/activation.psm1`
- [ ] `providers/debloat.psm1`
- [ ] `providers/office.psm1`

### Phase 4: Safety
- [ ] `checkpoint.psm1`
- [ ] Rollback functionality

---

## Summary

| Aspect | Decision |
|--------|----------|
| **Name** | WinSpec (Windows Specification) |
| **Config Format** | PowerShell `.ps1` (native) |
| **Layout** | Grouped: `providers/`, `specs/` |
| **Provider Types** | Declarative (idempotent) + Trigger (explicit) |
| **Package** | Declarative: `Installed = @(...)` |
| **Activation** | Trigger: `Trigger = @{ Activation = $true }` |
| **Debloat** | Trigger: `Trigger = @{ Debloat = "silent" }` |
| **Compatibility** | None (clean break) |

---

*WinSpec Design v4.0 - 2026-02-16*
