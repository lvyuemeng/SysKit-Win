#!/usr/bin/env pwsh
# run-tests.ps1 - Run all WinSpec tests with Pester

[CmdletBinding()]
param (
    [Parameter(Mandatory = $false)]
    [AllowEmptyString()]
    [string]$TestPath = ""
)

$ErrorActionPreference = 'Stop'

# Determine test path
if ([string]::IsNullOrEmpty($TestPath)) {
    $TestPath = $PSScriptRoot
    if ([string]::IsNullOrEmpty($TestPath)) {
        $TestPath = Split-Path -Parent $MyInvocation.MyCommand.Path
    }
    if ([string]::IsNullOrEmpty($TestPath)) {
        $TestPath = $PWD
    }
}

# Check if Pester is available
if (-not (Get-Module -ListAvailable -Name Pester)) {
    Write-Host "Installing Pester module..." -ForegroundColor Yellow
    Install-Module -Name Pester -Force -Scope CurrentUser -SkipPublisherCheck
}

# Import Pester
Import-Module Pester -MinimumVersion 5.0

# Configure Pester
$config = New-PesterConfiguration
$config.Run.Path = $TestPath
$config.Output.Verbosity = if ($VerbosePreference -eq 'Continue') { "Detailed" } else { "Normal" }
$config.TestResult.Enabled = $true
$config.TestResult.OutputPath = Join-Path $TestPath "test-results.xml"

# Run tests
Write-Host "Running WinSpec tests..." -ForegroundColor Cyan
Write-Host "Test path: $TestPath" -ForegroundColor Gray
Write-Host ""

$result = Invoke-Pester -Configuration $config

# Summary
Write-Host ""
Write-Host "=== Test Summary ===" -ForegroundColor Cyan
Write-Host "Total tests:  $($result.TotalCount)" -ForegroundColor White
Write-Host "Passed:       $($result.PassedCount)" -ForegroundColor Green
Write-Host "Failed:       $($result.FailedCount)" -ForegroundColor $(if ($result.FailedCount -gt 0) { "Red" } else { "Green" })
Write-Host "Skipped:      $($result.SkippedCount)" -ForegroundColor Yellow
Write-Host "Duration:     $($result.Duration.TotalSeconds.ToString('0.00'))s" -ForegroundColor White

# Exit with appropriate code
if ($result.FailedCount -gt 0) {
    Write-Host ""
    Write-Host "Some tests failed!" -ForegroundColor Red
    exit 1
}

Write-Host ""
Write-Host "All tests passed!" -ForegroundColor Green
exit 0
