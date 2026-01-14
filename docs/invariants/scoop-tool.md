# Invariants for Scoop Scripts

This document defines the conditions that must hold for the Scoop management scripts to remain correct and safe.

**Note**: `scoop-tool.ps1` has been split into three purpose-specific scripts:
- `scoop-install.ps1` - Install Scoop
- `scoop-resolve.ps1` - Update bucket references
- `scoop-proxy.ps1` - Configure bucket git proxy

---

## Exit Code Standard (All Scripts)

| Code | Meaning |
|------|---------|
| 0 | Success |
| 1 | General error |
| 2 | Dependency missing (Scoop/Git not found) |
| 3 | Invalid parameters |

---

## Global Invariants

### 1. Dependency Check Before Execution

**Statement**: All scripts MUST fail fast with exit code 2 if required dependencies are missing.

**Implementation**:
- `scoop-install.ps1`: Requires internet access. Proxy mode runs `scoop bucket add` which requires git.
- `scoop-resolve.ps1`: Requires Scoop installed
- `scoop-proxy.ps1`: Requires Scoop and Git installed

**Violation Consequences**:
- Unclear errors from failed commands
- Partial/incomplete operations

---

### 2. Valid Bucket Names

**Statement**: Bucket names MUST be valid directory names and MUST NOT contain path separator characters (`/`, `\`) or reserved characters (`*`, `:`, `"`, `<`, `>`, `|`).

**Rationale**: Bucket names are used in:
- Path construction: `Join-Path $bucketsRoot $bucket`
- Directory existence checks: `Test-Path $bucketPath`

**Violation Consequences**:
- Path traversal attacks
- Invalid path construction
- Directory not found errors

---

### 3. install.json Format Contract

**Statement**: All `install.json` files in `$SCOOP/apps/*/install.json` MUST contain a valid JSON object with a `bucket` string field.

**Rationale**: `scoop-resolve.ps1` performs regex replacement on the `bucket` field:
```powershell
$newContent = $content -replace "`"bucket`": `"(?:$fromRegex)?`"", "`"bucket`": `"$To`""
```

**Violation Consequences**:
- Regex replacement may corrupt non-standard JSON
- Failed file writes
- Partial modifications

---

### 4. Proxy URL Format (Prefix Proxy)

**Statement**: Proxy URLs MUST be valid HTTP/HTTPS URLs without trailing slashes, and MUST be prefix-style proxies (e.g., `https://gh-proxy.org`).

**Rationale**: Proxy URLs are:
- Concatenated with repository URLs: `"$proxy/$baseSource"`
- Stripped of trailing slashes before use

**Violation Consequences**:
- Malformed git remote URLs
- Double-slashes in URLs
- Failed git operations

---

## Script-Specific Invariants

### scoop-install.ps1

**Statement**: `scoop-install.ps1` MUST:

| Mode | Behavior |
|------|----------|
| proxy | 1. Download installer from proxy URL<br>2. Run installer<br>3. Configure `scoop_repo` with proxy<br>4. Add `spc` bucket with proxy |
| native | Run official installer only |

**Guarantees**:
- Idempotent: skips if Scoop already installed
- Uses `$DEFAULT_PROXY = 'https://gh-proxy.org'` for proxy mode

---

### scoop-resolve.ps1

**Statement**: `scoop-resolve.ps1` MUST NOT modify any file if:
- `$To` parameter is `$null` or empty
- No `install.json` files exist in `$scoopDir/apps`
- File is already in desired state (idempotent)

**Guarantees**:
- Idempotent: running on already-converted apps does nothing
- Only modifies files where bucket actually changes
- `-DryRun` shows changes without writing
- `-WhatIf` support via `SupportsShouldProcess`

---

### scoop-proxy.ps1

**Statement**: `scoop-proxy.ps1` MUST NOT modify git remotes if:
- Git is not available (exit code 2)
- Bucket path does not exist
- Current remote URL cannot be read

**Guarantees**:
- Atomic per-bucket operations (one failure doesn't affect others)
- `-Reset` strips proxy prefix to recover original URL
- `-DryRun` shows current and new URLs without executing
- `-WhatIf` support via `SupportsShouldProcess`

**Reset Logic**:
```powershell
if ($Reset) {
    $newSource = $baseSource  # Strip proxy prefix
} else {
    $newSource = "$Url/$baseSource"  # Prepend proxy
}
```

---

## Safety Invariants

### 1. No Automatic System Modification

**Statement**: All scripts MUST NOT modify the system without explicit user action.

**Guarantee**: Scripts only run when invoked explicitly, not on import.

---

### 2. DryRun/Safety Support

**Statement**: `scoop-resolve.ps1` and `scoop-proxy.ps1` MUST support:
- `-DryRun` switch to preview changes
- `-WhatIf` via `SupportsShouldProcess`

**Guarantee**: Users can verify changes before applying.

---

### 3. Read-Modify Pattern

**Statement**: `scoop-resolve.ps1` MUST read the full file content before writing any changes.

**Guarantee**: Prevents data loss from partial writes.

---

## Invariants Currently Not Enforced

1. **install.json JSON validity**: Regex replacement assumes valid JSON format
2. **Proxy URL accessibility**: No validation that proxy URLs are reachable
3. **Git remote URL validity**: No validation that new URLs are valid git repos

---

## References

- **Design Document**: `docs/nix-like.md`
- **Scan Rules**: `docs/ai/scan.md`
- **Code**: `scoop-install.ps1`, `scoop-resolve.ps1`, `scoop-proxy.ps1`
