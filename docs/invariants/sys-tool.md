# Invariants for Sys-Tool Scripts

This document defines the conditions that must hold for the system tool scripts to remain correct and safe.

**Scripts covered**:
- `office.ps1` - Download Microsoft Office 365 installer
- `debloat.ps1` - Execute Windows debloat script
- `activation.ps1` - Execute Windows/Office activation script

---

## Exit Code Standard

| Code | Meaning |
|------|---------|
| 0 | Success (including help display) |
| 1 | General error |
| 3 | Invalid parameters |

---

## Global Invariants

### 1. Help Handling

**Statement**: All scripts SHOULD use PowerShell comment-based help as the canonical approach.

**Implementation**: Use comment-based help blocks with `<#.SYNOPSIS#>`, `<#.DESCRIPTION#>`, `<#.PARAMETER#>`, and `<#.EXAMPLE#>` tags.

**Example**:
```powershell
<#
.SYNOPSIS
    Downloads Microsoft Office 365 installer.

.DESCRIPTION
    This script downloads the PlusRetail online x64 Microsoft 365 installer.

.PARAMETER dir
    Target directory for the installer. Defaults to current directory.

.PARAMETER cache
    Download only, do not execute the installer.

.EXAMPLE
    .\office.ps1 -dir C:\Installers
#>
```

**Fallback**: Scripts MAY support `-?` flag for PowerShell's built-in help display.

**Reference**: `Get-Help about_Comment_Based_Help`

**Violation Consequences**:
- Inconsistent help experience across scripts
- No `Get-Help` integration
- Manual help text maintenance

---

### 2. Remote Source Safety

**Statement**: All scripts MUST use HTTPS for remote URLs and MUST use `ScriptBlock.Create()` for remote script execution when applicable.

**Rationale**:
- Prevents man-in-the-middle attacks
- Isolates remote script execution from immediate invocation

**Implementation**:
- `office.ps1`: HTTPS URL to Microsoft CDN
- `debloat.ps1`: HTTPS URL to debloat.raphi.re, wrapped in `ScriptBlock.Create()`
- `activation.ps1`: HTTPS URL to get.activated.win, piped to `Invoke-Expression`

**Violation Consequences**:
- Unencrypted script download
- Arbitrary remote code execution without isolation

---

### 3. Parameter Passing

**Statement**: Scripts using `[ValueFromRemainingArguments]` MUST safely pass remaining arguments to remote scripts.

**Implementation**:
```powershell
[Parameter(ValueFromRemainingArguments = $true)]
[string[]]$args

$all_args = @($PSBoundParameters.Values + $args)
```

**Violation Consequences**:
- Arguments silently dropped
- Unexpected behavior in remote scripts

---

## Per-Script Invariants

### office.ps1

**Statement**: `office.ps1` MUST:

| Parameter | Behavior |
|-----------|----------|
| `-dir <path>` | Create directory if not exists, save installer to path |
| `-cache` | Download installer without executing |
| (none) | Download to current directory and execute |

**Fixed URL**: `https://c2rsetup.officeapps.live.com/c2r/download.aspx?ProductreleaseID=O365ProPlusRetail&platform=x64&language=en-us&version=O16GA`

**Guarantees**:
- Idempotent: re-downloading overwrites existing installer
- `-cache` prevents automatic execution
- Directory creation uses `-Force` to ensure path exists

**Error Handling**:
- Fails fast on network error (invoke-webrequest -ErrorAction Stop)
- Catches download and execution errors separately
- Reports installation failure with exception message

---

### debloat.ps1

**Statement**: `debloat.ps1` MUST pass all options to the remote debloat script via splatting.

**Remote URL**: `https://debloat.raphi.re/`

**Guarantees**:
- All parameters passed through to remote script
- No local validation (remote script handles validation)
- ScriptBlock isolation for remote execution

**Error Handling**:
- No local error handling
- Relies entirely on remote script for error reporting

---

### activation.ps1

**Statement**: `activation.ps1` MUST pass all arguments to the remote activation script.

**Remote URL**: `https://get.activated.win`

**Guarantees**:
- All arguments passed through to remote script
- No local validation (remote script handles validation)
- Stream-based execution via pipeline

**Error Handling**:
- No local error handling
- Relies entirely on remote script for error reporting

---

## Safety Invariants

### 1. No Automatic System Modification

**Statement**: Scripts MUST NOT modify the system without explicit user action.

**Guarantee**: Scripts only run when invoked explicitly with parameters.

---

### 2. Fixed Remote URLs

**Statement**: Scripts MUST NOT accept remote URLs as parameters.

**Rationale**: Prevents arbitrary remote code execution via user-provided URLs.

**Implementation**:
- `office.ps1`: Hardcoded Microsoft URL
- `debloat.ps1`: Hardcoded debloat.raphi.re URL
- `activation.ps1`: Hardcoded get.activated.win URL

**Violation Consequences**:
- User could redirect to malicious script
- Loss of supply chain integrity

---

### 3. Local Download Before Execution

**Statement**: `office.ps1` MUST download the installer to a local file before execution.

**Guarantee**: User can inspect downloaded file before running.

---

## Invariants Currently Not Enforced

1. **HTTPS certificate validation**: Scripts do not validate SSL certificates
2. **Download integrity**: No checksum verification for downloaded files
3. **Remote script trust**: No verification that remote scripts match expected behavior
4. **Exit code propagation**: Remote script exit codes not captured locally

---

## References

- **Design Document**: `docs/nix-like.md`
- **Scan Rules**: `docs/ai/scan.md`
- **Code**: `office.ps1`, `debloat.ps1`, `activation.ps1`
