# Nix-Like on Windows

## Part 1: General Design for a Nix-like Configuration System on Windows
This document outlines the design principles for creating a functional, declarative configuration management system for Windows, inspired by Nix/flakes.

## 1. Core Philosophy
The system will be built on three core principles that mirror the benefits of NixOS:

- Declarative: You define the desired state of your system in configuration files, not the steps to get there. The system's "engine" is responsible for figuring out how to achieve that state.

- Reproducible: A given configuration file should, as much as possible, produce the exact same system state every time it's applied. This is more challenging on Windows than on Linux, but it remains a primary goal.

- Atomic & Recoverable: Configuration changes should be applied in a transactional manner. If a change fails, the system should ideally roll back to the previous known-good state.

## 2. System Architecture
The system can be envisioned as having four main components:

### a. Configuration Files (The "Flake")
This is the user-facing component. It's where you declare what your system should look like.

- Format: A human-readable format like YAML or JSON5 is ideal. It's easy to write and parse. PowerShell's own psd1 file format is also a strong, native candidate.

- Structure: The configuration should be modular. A root file (e.g., system.yaml) would define the overall system and could import other modules (e.g., apps.yaml, dev-tools.yaml, security.yaml). This allows for reusable components.

- Content: The configuration declares resources and their desired state. Examples of resources include:

- Packages (e.g., name: git, state: present)

- Registry Keys (e.g., path: 'HKCU:\Software\MyApp', value: 'Enabled', data: 1)

- Services (e.g., name: 'wuauserv', state: 'stopped', startupType: 'disabled')

- Files/Directories (e.g., path: 'C:\Users\user\Documents\config.ini', content: '...', state: 'present')

Example `system.yaml`:

```yaml
system.yaml
imports:
  - ./apps.yaml
  - ./tweaks.yaml

system:
  hostname: "DEV-MACHINE"
  powerPlan: "High Performance"

services:
  - name: "Spooler"
    state: "stopped"
    startupType: "disabled"
```

### b. The Engine (The "Orchestrator")
This is the core logic, a PowerShell script that acts as the entry point. Its responsibilities are:

- Parse: Read the root configuration file and all its imports.

- Build Dependency Graph: Understand the relationships between resources (e.g., a service configuration might depend on a package being installed first). For simplicity, the initial version might just process resources in a predefined order (Packages -> Files -> Registry -> Services).

- Check Current State: For each resource declared in the configuration, query the live system to determine its current state.

- Calculate Diff: Compare the desired state (from the config) with the current state. This comparison generates a list of actions to take (e.g., "Install package X," "Set registry key Y," "Stop service Z").

Execute Plan: Pass the list of actions to the appropriate "Providers" to apply the changes.

### c. Providers (The "Resource Managers")
Providers are specialized scripts or functions that know how to manage a specific type of resource. This modular approach keeps the engine clean and makes the system extensible.

- `Package.Provider.ps1`: Knows how to install, uninstall, and check the status of packages using a backend like Chocolatey or Winget.

- `Registry.Provider.ps1`: Knows how to create, modify, and delete registry keys.

- `Service.Provider.ps1`: Knows how to start, stop, enable, and disable Windows services.

- `${File.Provider.ps1}`: Manages file and directory presence, content, and permissions.

Each provider would expose a consistent set of functions, for example: `Get-State, Set-State, and Test-State` (for idempotency checks).

### d. State Ledger (The "Journal")
To ensure recoverability and provide an audit trail, the engine logs every action it takes to a local state file (e.g., a JSON or SQLite file). This ledger would record:

- Timestamp of the run.

- The configuration file hash at the time of the run.

- A list of every change made.

- The "before" and "after" state of each modified resource, which is crucial for rollbacks.

- This design separates the what (Configuration Files) from the how (Engine and Providers), creating a flexible and powerful system for managing a Windows environment in a more functional way.

## Part 2: Concrete Implementation, Edge Cases & Recoverability

This document details the practical implementation of the proposed system, focusing on tooling, script structure, and robust error handling.

## 1. Core Technology Stack
Scripting Language: `PowerShell 7+`. It's cross-platform, object-oriented, and has the best native integration with the Windows OS for managing services, registry, and system settings.

Package Management: Currently not supported.

Configuration Format: YAML with the powershell-yaml module for parsing. YAML's syntax is cleaner and more human-friendly for complex configurations than JSON.

## 2. Script Structure (Example)
Your project could be structured like this:

```bash
/MyNixForWindows
|-- apply.ps1             # The main engine/entry point
|-- config/
|   |-- system.yaml       # Main configuration file
|   |-- apps.yaml
|   |-- tweaks.yaml
|-- providers/
|   |-- Package.Provider.ps1
|   |-- Registry.Provider.ps1
|   |-- Service.Provider.ps1
|-- state/
|   |-- ledger.json       # The state journal
|-- lib/
    |-- Logger.ps1        # Helper for structured logging
```

Example: `Package.Provider.ps1`

```pwsh
# providers/package.provider.ps1

# Function to get the current state of a package
function Get-PackageState {
    param($Name)
    $package = choco list --local-only --exact $Name
    if ($package) {
        return @{ Name = $Name; State = "present"; Version = ($package -split '\|')[1] }
    }
    return @{ Name = $Name; State = "absent" }
}

# Function to enforce the desired state
function Set-PackageState {
    param($DesiredState)

    $currentState = Get-PackageState -Name $DesiredState.Name

    if ($DesiredState.State -eq "present" -and $currentState.State -ne "present") {
        Write-Host "Installing package: $($DesiredState.Name)"
        # Note: The '--yes' flag is crucial for automation
        choco install $DesiredState.Name --yes --no-progress
    }
    elseif ($DesiredState.State -eq "absent" -and $currentState.State -ne "absent") {
        Write-Host "Uninstalling package: $($DesiredState.Name)"
        choco uninstall $DesiredState.Name --yes
    }
}

# Function to test if the state is already correct (for idempotency)
function Test-PackageState {
    param($DesiredState)
    $currentState = Get-PackageState -Name $DesiredState.Name
    return $currentState.State -eq $DesiredState.State
}
```

The main `apply.ps1` engine would loop through the YAML config and call these functions for each package resource.

## 3. Recoverability Strategy (Crucial for Safety)

True atomic transactions are nearly impossible in Windows. We must simulate them and prioritize recoverability.

Pre-run Checkpoint: Before applying any changes, the engine should programmatically create a `Windows System Restore Point`. This is the most powerful "undo" button available.

Checkpoint-Computer -Description `Pre-MyNix run on $(Get-Date)`

Transactional Logic: The `apply.ps1` script should wrap its execution block in a try...catch block.

- On Success: At the end of a successful run, write the new state to the ledger.

- On Failure: The catch block is triggered. The script should immediately halt execution and report the error. It should then offer the user a guided rollback.

Guided Rollback: A failed run could trigger a separate `rollback.ps1` script or mode. This script would:

- Read the last known-good state from the ledger.

- Read the "before" states of the changes made during the failed run.

- Attempt to revert the failed changes in reverse order. For example, if it set a registry key and then failed to install a package, it would first revert the registry key.

- If the automated rollback fails, it should instruct the user on how to use the System Restore Point created earlier.

## 4. Invariance (Idempotency)

Your system must be idempotent. Running `apply.ps1` on an already-configured system should result in zero changes.

This is achieved by the `Test-State` function in each provider. The engine's logic should be:

```pwsh
# Inside the engine's loop for each resource
$isStateCorrect = Test-ResourceState -DesiredState $resource
if (-not $isStateCorrect) {
    # Only log the "before" state and call Set-State if a change is needed
    Log-Change -Resource $resource -BeforeState (Get-ResourceState $resource)
    Set-ResourceState -DesiredState $resource
} else {
    Write-Verbose "Resource $($resource.Name) is already in the desired state."
}
```

This prevents redundant work and makes the script's output clean and predictable.

## 5. Handling Edge Cases & User Readability

Required Reboots: Package installations (like dotnet-sdk) can trigger a pending reboot. The Chocolatey provider should detect this (e.g., using Test-PendingReboot from the PowerShell Gallery) and warn the user at the end of the run. The script should not reboot automatically.

GUI Application Settings: Managing settings for GUI apps is notoriously difficult. Many store settings in AppData in non-standard formats (.xml, .json, binary files). The best approach is a File.Provider that can place a known-good configuration file into AppData\Roaming\AppName. This is a "brute force" approach but is often the only reliable one.

Secrets Management: Do not store passwords or API keys in the YAML files. Integrate with Windows Credential Manager or use environment variables that the script can read at runtime.

User Readability:

- Verbose Logging: Use Write-Verbose, Write-Warning, and Write-Error extensively. The apply.ps1 should have a -Verbose switch.

- Dry Run Mode: Add a -WhatIf or -DryRun switch to the engine. This will run the entire "Check" and "Diff" process and print a report of what would change, without actually applying anything. This is invaluable for user confidence.

- Clear Output: Use color-coded output to distinguish between checks, changes, warnings, and errors. A final summary ("2 packages installed, 1 registry key modified, 57 resources already correct") is very helpful.