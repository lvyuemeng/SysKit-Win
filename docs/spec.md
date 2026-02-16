# WinSpec Specification Guide

This document describes the specification format and available configuration options.

---

## Specification Format

A specification is a PowerShell `.ps1` file that returns a hashtable with configuration settings:

```powershell
# specs/example.ps1
@{
    Name = "example"
    Description = "Example specification"
    
    # Import other specs (composition)
    Import = @(
        ".\specs\default.ps1"
    )
    
    # Declarative providers (idempotent)
    Registry = @{ ... }
    Package = @{ ... }
    Service = @{ ... }
    Feature = @{ ... }
    
    # Triggers (non-idempotent)
    Trigger = @{ ... }
}
```

---

## Specification Fields

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `Name` | string | No | Specification name for logging |
| `Description` | string | No | Human-readable description |
| `Import` | array | No | Paths to other specs to import |
| `Registry` | hashtable | No | Registry configuration |
| `Package` | hashtable | No | Package management configuration |
| `Service` | hashtable | No | Windows services configuration |
| `Feature` | hashtable | No | Windows features configuration |
| `Trigger` | hashtable | No | Trigger actions to execute |

---

## Declarative Providers

### Registry Provider

The Registry provider manages Windows registry settings with predefined categories.

#### Categories

| Category | Properties | Description |
|----------|------------|-------------|
| `Clipboard` | `EnableHistory` | Clipboard history settings |
| `Explorer` | `ShowHidden`, `ShowFileExt` | File Explorer settings |
| `Theme` | `AppTheme`, `SystemTheme` | Windows theme settings |
| `Desktop` | `MenuShowDelay` | Desktop behavior settings |

#### Property Details

**Clipboard**
| Property | Type | Values | Registry Path |
|----------|------|--------|---------------|
| `EnableHistory` | bool | `$true`, `$false` | `HKCU:\Software\Microsoft\Clipboard` |

**Explorer**
| Property | Type | Values | Registry Path |
|----------|------|--------|---------------|
| `ShowHidden` | bool | `$true`, `$false` | `HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced` |
| `ShowFileExt` | bool | `$true`, `$false` | `HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced` |

**Theme**
| Property | Type | Values | Registry Path |
|----------|------|--------|---------------|
| `AppTheme` | string | `"dark"`, `"light"` | `HKCU:\Software\Microsoft\Windows\CurrentVersion\Themes\Personalize` |
| `SystemTheme` | string | `"dark"`, `"light"` | `HKCU:\Software\Microsoft\Windows\CurrentVersion\Themes\Personalize` |

**Desktop**
| Property | Type | Values | Registry Path |
|----------|------|--------|---------------|
| `MenuShowDelay` | int | milliseconds | `HKCU:\Control Panel\Desktop` |

#### Example

```powershell
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
    Desktop = @{
        MenuShowDelay = 0
    }
}
```

---

### Package Provider

The Package provider ensures specified packages are installed using Scoop.

#### Configuration

| Field | Type | Description |
|-------|------|-------------|
| `Installed` | array | List of package names to ensure installed |

#### Example

```powershell
Package = @{
    Installed = @("git", "neovim", "nodejs", "python", "7zip")
}
```

The provider automatically installs Scoop if not present.

---

### Service Provider

The Service provider manages Windows services.

#### Configuration

Each key is a service name (short name, not display name).

| Field | Type | Values | Description |
|-------|------|--------|-------------|
| `State` | string | `"running"`, `"stopped"` | Desired service state |
| `Startup` | string | `"automatic"`, `"manual"`, `"disabled"` | Startup type |

#### Example

```powershell
Service = @{
    wuauserv = @{ State = "stopped"; Startup = "disabled" }
    WinDefend = @{ State = "running"; Startup = "automatic" }
}
```

---

### Feature Provider

The Feature provider manages Windows optional features.

#### Configuration

Each key is a feature name. The value is the desired state:

| Value | Description |
|-------|-------------|
| `"enabled"` | Enable the feature |
| `"disabled"` | Disable the feature |

#### Example

```powershell
Feature = @{
    "Microsoft-Windows-Subsystem-Linux" = "enabled"
    "VirtualMachinePlatform" = "enabled"
}
```

---

## Trigger Providers

Trigger providers execute one-time, non-idempotent actions. They are explicitly separated from declarative providers to make it clear that running them multiple times may have different effects.

### Activation Trigger

Activates Windows and/or Office.

| Option | Description |
|--------|-------------|
| `$true` | Run activation with default settings |

#### Example

```powershell
Trigger = @{
    Activation = $true
}
```

---

### Debloat Trigger

Removes bloatware and unwanted Windows components.

| Option | Type | Description |
|--------|------|-------------|
| `"silent"` | string | Run in silent mode |
| `@{ Silent = $true; RemoveApps = $true }` | hashtable | Advanced options |

#### Example

```powershell
Trigger = @{
    Debloat = "silent"
}
```

---

### Office Trigger

Downloads the Office installer.

| Option | Type | Description |
|--------|------|-------------|
| `"C:\Path"` | string | Target directory for installer |

#### Example

```powershell
Trigger = @{
    Office = "C:\Installers"
}
```

---

## Composition

Specifications can import other specifications using the `Import` field. Later specifications override earlier ones for conflicting keys.

```powershell
# specs/base.ps1
@{
    Name = "base"
    Registry = @{
        Theme = @{ AppTheme = "light" }
    }
}

# specs/custom.ps1
@{
    Name = "custom"
    Import = @(".\specs\base.ps1")
    
    Registry = @{
        Theme = @{ AppTheme = "dark" }  # Overrides base
    }
    Package = @{
        Installed = @("git")  # Merged with base (if any)
    }
}
```

---

## Validation

Validate a specification without applying:

```powershell
.\winspec\winspec.ps1 validate -Spec .\winspec\specs\developer.ps1
```

This checks:
- Valid PowerShell syntax
- Required field types
- Provider-specific schema validation

---

*WinSpec Specification Guide v1.0*
