# providers/Wallpaper.Provider.ps1
# Manages the desktop wallpaper and style.

$regPath = "HKCU:\Control Panel\Desktop"
function Get-WallpaperState {
    $currentPath = Get-ItemProperty -Path $regPath -Name "Wallpaper" -ErrorAction SilentlyContinue | Select-Object -ExpandProperty Wallpaper
    # Style: 0=Center, 2=Stretch, 6=Fit, 10=Fill, 22=Span
    $currentStyleValue = Get-ItemProperty -Path $regPath -Name "WallpaperStyle" -ErrorAction SilentlyContinue | Select-Object -ExpandProperty WallpaperStyle -Default 2

    $styleMap = @{
        'fill' = 10;
        'fit' = 6;
        'stretch' = 2;
        'center' = 0;
        'span' = 22;
    }
    # Invert map for lookup
    $styleName = $styleMap.GetEnumerator() | Where-Object { $_.Value -eq $currentStyleValue } | Select-Object -First 1 | ForEach-Object { $_.Name }

    return @{ path = $currentPath; style = $styleName }
}

function Set-WallpaperState {
    param(
        [parameter(Mandatory=$true)]
        [hashtable]$DesiredState
    )
    $styleMap = @{
        'fill' = 10;
        'fit' = 6;
        'stretch' = 2;
        'center' = 0;
        'span' = 22;
    }
    if (-not $styleMap.ContainsKey($DesiredState.style)) { throw "Invalid wallpaper style '$($DesiredState.style)'." }
    $styleValue = $styleMap[$DesiredState.style]

    Write-Host "  Applying Wallpaper Path: $($DesiredState.path)"
    Set-ItemProperty -Path $regPath -Name "Wallpaper" -Value $DesiredState.path

    Write-Host "  Applying Wallpaper Style: $($DesiredState.style)"
    Set-ItemProperty -Path $regPath -Name "WallpaperStyle" -Value $styleValue -Type String

    # Changes require a system call to take effect immediately.
    RUNDLL32.EXE user32.dll,UpdatePerUserSystemParameters 1, True
}

function Test-WallpaperState {
    param(
        [parameter(Mandatory=$true)]
        [hashtable]$DesiredState
    )
    $currentState = Get-WallpaperState
    # Normalize paths for comparison
    $desiredFullPath = (Resolve-Path $DesiredState.path).Path
    $currentFullPath = (Resolve-Path $currentState.path).Path
    return ($currentFullPath -eq $desiredFullPath) -and ($currentState.style -eq $DesiredState.style)
}