# SysKit

A collection of PowerShell scripts for Windows system management.

**Warning**: Please inspect the code before executing any script.

---

## Quick Start

Execute any script directly:

### System Tools

Gathering several project for simplicity:

```powershell
# Download Office 365 installer
& ([scriptblock]::Create((irm "https://raw.githubusercontent.com/lvyuemeng/SysKit-Win/master/office.ps1"))) -dir C:\Installers

# Execute Windows debloat
& ([scriptblock]::Create((irm "https://raw.githubusercontent.com/lvyuemeng/SysKit-Win/master/debloat.ps1"))) -Silent -CreateRestorePoint

# Activate Windows/Office
& ([scriptblock]::Create((irm "https://raw.githubusercontent.com/lvyuemeng/SysKit-Win/master/activation.ps1")))
```

### Scoop Management

```powershell
# Install Scoop with proxy
& ([scriptblock]::Create((irm "https://raw.githubusercontent.com/lvyuemeng/SysKit-Win/master/scoop-install.ps1"))) -Source proxy

# Resolve bucket references to spc
& ([scriptblock]::Create((irm "https://raw.githubusercontent.com/lvyuemeng/SysKit-Win/master/scoop-resolve.ps1"))) -To spc

# Set bucket proxy
& ([scriptblock]::Create((irm "https://raw.githubusercontent.com/lvyuemeng/SysKit-Win/master/scoop-proxy.ps1"))) -Bucket main -Url https://gh-proxy.org
```

---

## System Tools

### office.ps1

Downloads Microsoft Office 365 PlusRetail installer.

**Parameters**:
- `-dir <path>`: Target directory (default: current directory)
- `-cache`: Download only, do not execute

**Usage**:
```powershell
.\office.ps1 -dir C:\Installers    # Download and execute
.\office.ps1 -cache                # Download only
```

---

### debloat.ps1

Executes Windows debloat script from Win11Debloat.

**Usage**:
```powershell
.\debloat.ps1 -Silent -CreateRestorePoint    # Silent mode with restore point
.\debloat.ps1 -RemoveApps                     # Remove default apps
```

All parameters are passed through to the remote debloat script.

---

### activation.ps1

Activates Windows and/or Office using Microsoft Activation Scripts.

**Usage**:
```powershell
.\activation.ps1              # Default (HWID)
.\activation.ps1 -KMS38       # KMS38 method
```

All arguments are passed through to the remote activation script.

---

## Scoop Management

### scoop-install.ps1

Installs Scoop package manager.

**Parameters**:
- `-Source proxy` (default): Install with proxy configuration
- `-Source native`: Install via official Scoop installer

**Usage**:
```powershell
.\scoop-install.ps1 -Source proxy    # Install with proxy, configure spc bucket
.\scoop-install.ps1 -Source native   # Install natively
```

**Proxy mode**:
- Downloads installer via `https://gh-proxy.org`
- Configures `scoop_repo` with proxy
- Adds `spc` bucket with proxy

---

### scoop-resolve.ps1

Updates bucket references in Scoop `install.json` files.

**Parameters**:
- `-To <bucket>`: Target bucket name (required)
- `-From <bucket[]>`: Source buckets to replace (default: main, extras, versions, nirsoft, etc.)
- `-DryRun`: Preview changes without writing

**Usage**:
```powershell
.\scoop-resolve.ps1 -To spc                    # Resolve all to spc
.\scoop-resolve.ps1 -To spc -DryRun            # Preview only
.\scoop-resolve.ps1 -To spc -From main,extras  # Specific source buckets
```

---

### scoop-proxy.ps1

Configures git proxy for Scoop bucket remotes.

**Parameters**:
- `-Bucket <bucket>`: Bucket name or `*` for all buckets (required)
- `-Url <proxy>`: Proxy URL to prepend (required)
- `-Reset`: Remove proxy, reset to original URL
- `-DryRun`: Preview changes without writing

**Usage**:
```powershell
.\scoop-proxy.ps1 -Bucket main -Url https://gh-proxy.org     # Set proxy
.\scoop-proxy.ps1 -Bucket main -Reset                        # Remove proxy
.\scoop-proxy.ps1 -Bucket * -Url https://gh-proxy.org -DryRun  # Preview all
```

---

## Installation

### Clone Entire Repository

```powershell
git clone https://github.com/lvyuemeng/SysKit-Win.git
```

### Download Individual Script

```powershell
irm https://raw.githubusercontent.com/lvyuemeng/SysKit-Win/master/office.ps1 -OutFile office.ps1
```

### Set Execution Policy

If scripts fail to run, set the execution policy:

```powershell
Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser
```

---

## Mirror URLs

All scripts are available from the following mirrors:

| Platform | URL |
|----------|-----|
| GitHub | `https://github.com/lvyuemeng/SysKit-Win` |
| Codeberg | `https://codeberg.org/nostalgia/SysKit-Win` |
| Gitee | `https://gitee.com/nostalgiaLiquid/SysKit-Win` |

**Raw file URLs**:
- GitHub: `https://raw.githubusercontent.com/lvyuemeng/SysKit-Win/master/<script>.ps1`
- Codeberg: `https://codeberg.org/nostalgia/SysKit-Win/raw/branch/master/<script>.ps1`
- Gitee: `https://gitee.com/nostalgiaLiquid/SysKit-Win/raw/main/<script>.ps1`

---

## License

MIT License - See [LICENSE-MIT](/LICENSE-MIT)
