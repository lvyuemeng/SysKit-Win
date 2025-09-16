function Get-TimezoneState {
    $currentTimezone = (Get-Timezone).Id
    return @{ id = $currentTimezone }
}

function Set-TimezoneState {
    param(
        [parameter(Mandatory=$true)]
        [hashtable]$DesiredState
    )

    Write-Host "  Applying new time zone: $($DesiredState.id)"
    Set-Timezone -Id $DesiredState.id
}

function Test-TimezoneState {
    param(
        [parameter(Mandatory=$true)]
        [hashtable]$DesiredState
    )
    $currentState = Get-TimezoneState
    return $currentState.id -eq $DesiredState.id
}