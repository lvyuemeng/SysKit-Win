<#
.SYNOPSIS
Update bucket references in Scoop install.json files.

.DESCRIPTION
Replaces bucket names in install.json files for apps installed from specified source buckets.

.PARAMETER To
Target bucket name to set.

.PARAMETER From
Source bucket names to replace (default: all official buckets: main, extras, versions, etc.).

.PARAMETER DryRun
Preview changes without writing.

.EXAMPLE
.\scoop-resolve.ps1 -To spc
.EXAMPLE
.\scoop-resolve.ps1 -To spc -DryRun
#>
[CmdletBinding(SupportsShouldProcess)]
param(
    [Parameter(Mandatory)]
    [string]$To,

    [string[]]$From = @('main', 'extras', 'versions', 'nirsoft', 'sysinternals', 'php', 'nerd-fonts', 'nonportable', 'java', 'games'),

    [switch]$DryRun
)

$ErrorActionPreference = 'Stop'

if (-not (Get-Command scoop -ErrorAction SilentlyContinue)) { Write-Error 'Scoop not found.'; exit 2 }
if ($To -match '[\/\\:*?"<>|]') { Write-Error "Invalid bucket: $To"; exit 3 }

$scoopDir = if ($env:SCOOP) { $env:SCOOP } else { "$env:USERPROFILE\scoop" }
$appsPath = Join-Path $scoopDir 'apps'
if (-not (Test-Path $appsPath)) { Write-Host 'No apps installed.'; exit 0 }

$installJsons = Get-ChildItem -Path $appsPath -Recurse -Filter 'install.json' -ErrorAction SilentlyContinue
if (-not $installJsons) { Write-Host 'No install.json files found.'; exit 0 }

$fromRegex = ($From | ForEach-Object { [Regex]::Escape($_) } | Select-Object -Unique) -join '|'
$updated = 0
$skipped = 0

foreach ($file in $installJsons) {
    $content = Get-Content -Path $file.FullName -Raw
    $newContent = $content -replace "`"bucket`": `"(?:$fromRegex)?`"", "`"bucket`": `"$To`""

    if ($content -eq $newContent) { $skipped++; continue }

    $action = if ($DryRun -or -not $PSCmdlet.ShouldProcess($file.FullName, 'Update bucket')) {
        'Would update'
    }
    else {
        Set-Content -Path $file.FullName -Value $newContent -Encoding UTF8
        'Updated'
    }
    Write-Host "$action $($file.Name)" -ForegroundColor $(if ($action -eq 'Updated') { 'Green' } else { 'Yellow' })
    $updated++
}

Write-Host "`nUpdated: $updated, Skipped: $skipped" -ForegroundColor Cyan
