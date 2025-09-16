# providers/Clipboard.Provider.ps1
# Manages the Clipboard History feature.
# 
$regPath = "HKCU:\Software\Microsoft\Clipboard"

function Get-ClipboardState {
    # A value of 1 means enabled. Default is disabled (or key doesn't exist).
    $historyEnabledValue = Get-ItemProperty -Path $regPath -Name "EnableClipboardHistory" -ErrorAction SilentlyContinue | Select-Object -ExpandProperty EnableClipboardHistory -Default 0
    $isEnabled = ($historyEnabledValue -eq 1)
    return @{ history = $isEnabled }
}

function Set-ClipboardState {
    param(
        [parameter(Mandatory=$true)]
        [hashtable]$DesiredState
    )
    if (-not (Test-Path $regPath)) {
        New-Item -Path $regPath -Force | Out-Null
    }

    $historyValue = if ($DesiredState.history) { 1 } else { 0 }

    Write-Host "  Applying Clipboard History: $($DesiredState.history)"
    Set-ItemProperty -Path $regPath -Name "EnableClipboardHistory" -Value $historyValue -Type DWord -Force
}

function Test-ClipboardState {
    param(
        [parameter(Mandatory=$true)]
        [hashtable]$DesiredState
    )
    $currentState = Get-ClipboardState
    return $currentState.history -eq $DesiredState.history
}