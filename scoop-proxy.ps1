<#
.SYNOPSIS
Configure git proxy for Scoop buckets.

.DESCRIPTION
Sets or resets the git remote URL prefix for buckets.

.PARAMETER Bucket
Bucket name or '*' for all buckets.

.PARAMETER Url
Proxy URL to prepend.

.PARAMETER Reset
Reset to original URL (remove proxy prefix).

.PARAMETER DryRun
Preview changes without writing.

.EXAMPLE
.\scoop-proxy.ps1 -Bucket main -Url https://gh-proxy.org
.EXAMPLE
.\scoop-proxy.ps1 -Bucket main -Reset
.EXAMPLE
.\scoop-proxy.ps1 -Bucket * -Url https://gh-proxy.org -DryRun
#>
[CmdletBinding(SupportsShouldProcess)]
param(
    [Parameter(Mandatory)]
    [string]$Bucket,

    [Parameter(Mandatory)]
    [string]$Url,

    [switch]$Reset,

    [switch]$DryRun
)

$ErrorActionPreference = 'Stop'

if (-not (Get-Command git -ErrorAction SilentlyContinue)) { Write-Error 'Git not found.'; exit 2 }
if (-not (Get-Command scoop -ErrorAction SilentlyContinue)) { Write-Error 'Scoop not found.'; exit 2 }
if ($Bucket -match '[\/\\:*?"<>|]') { Write-Error "Invalid bucket: $Bucket"; exit 3 }

$proxyUrl = ($null -ne $Url ? $Url : '').TrimEnd('/')
$scoopDir = if ($env:SCOOP) { $env:SCOOP } else { "$env:USERPROFILE\scoop" }
$bucketsRoot = Join-Path $scoopDir 'buckets'

if (-not (Test-Path $bucketsRoot)) { Write-Error 'Buckets directory not found.'; exit 2 }

$bucketsTo = if ($Bucket -eq '*') {
    Get-ChildItem -Path $bucketsRoot -Directory | Select-Object -ExpandProperty Name
    if (-not $bucketsTo) { Write-Host 'No buckets found.'; exit 0 }
}
else {
    $bucketPath = Join-Path $bucketsRoot $Bucket
    if (-not (Test-Path $bucketPath)) { Write-Error "Bucket not found: $Bucket"; exit 2 }
    @($Bucket)
}

$processed = 0
$failed = 0

foreach ($cur in $bucketsTo) {
    $path = Join-Path $bucketsRoot $cur
    Write-Host "`n--- $cur ---" -ForegroundColor Yellow

    try {
        $curSource = git -C $path config --get remote.origin.url -ErrorAction Stop
    }
    catch {
        Write-Warning "Failed to get remote URL: $($_.Exception.Message)"
        $failed++
        continue
    }

    if ([string]::IsNullOrWhiteSpace($curSource)) { Write-Warning 'No remote.'; continue }

    $baseSource = ($curSource -split '(?=https?://)')[-1]
    $newSource = if ($Reset) { $baseSource } else { "$proxyUrl/$baseSource" }

    Write-Host "Current: $curSource"
    Write-Host "New:      $newSource"

    $action = if ($DryRun -or -not $PSCmdlet.ShouldProcess($cur, 'Set proxy')) { 'Would update' }
    else {
        git -C $path remote set-url origin $newSource -ErrorAction Stop
        'Updated'
    }

    Write-Host "$action" -ForegroundColor $(if ($action -eq 'Updated') { 'Green' } else { 'Yellow' })
    if ($action -eq 'Updated') { $processed++ } else { $failed++ }
}

Write-Host "`nProcessed: $processed, Failed: $failed" -ForegroundColor Cyan
