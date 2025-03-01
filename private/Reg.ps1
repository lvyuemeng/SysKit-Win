$DefaultRegPath = "HKCU:\Environment"

function NameCheck {
    param([string]$Name)

	$Name = $Name.toUpper()
    if ($Name -eq "PATH") {
        throw "Use Add/Remove for PATH modifications"
    }
}

function Set-RegistryValue {
    [CmdletBinding(SupportsShouldProcess)]
    param (
        [Parameter(Mandatory)]
        [string]$Name,
        [Parameter(Mandatory)]
        [string]$Value,
        [string]$RegPath = $DefaultRegPath
    )
    
    NameCheck -Name $Name

    if ($PSCmdlet.ShouldProcess("$RegPath\$Name", "Set value")) {
        try {
            Set-ItemProperty -Path "$RegPath" -Name $Name -Value $Value -ErrorAction Stop
        }
        catch {
            throw "Failed to set registry value: $_"
        }
    }
}

function Remove-RegistryValue {
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter(Mandatory)]
        [string]$Name,
        [string]$RegPath = $DefaultRegPath
    )

    NameCheck -Name $Name

    if ($PSCmdlet.ShouldProcess("$RegPath\$Name", "Remove value")) {
        try {
            Remove-ItemProperty -Path "Registry::$RegPath" -Name $Name -ErrorAction Stop
        }
        catch {
            throw "Failed to remove registry value: $_"
        }
    }
}

function Get-RegistryValue {
    [CmdletBinding()]
    param (
        [string]$Name,
        [string]$RegPath = $DefaultRegPath
    )
    try {
        if ($Name) {
            Get-ItemProperty -Path "$RegPath" -Name $Name -ErrorAction Stop
        }
        else {
            Get-ItemProperty -Path "$RegPath" -ErrorAction Stop
        }
    }
    catch {
        Write-Warning "Registry query failed: $_"
        return $null
    }
}

function Add-RegistryPathValue {
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter(Mandatory)]
        [string]$Name,
        [Parameter(Mandatory)]
        [ValidateScript({ Test-ValidPath -Path $_ })]
        [string]$Value,
        [string]$RegPath = $DefaultRegPath
    )
    
    $current = Get-RegistryValue -Name $Name -RegPath $RegPath

    if (-not $current) {
        Set-RegistryValue -Name $Name -Value $Value -RegPath $RegPath
        return
    }

    $values = $current.$Name -split ';'
    if ($values -contains $Value) {
        Write-Warning "'$Value' already exists in $RegPath\$Name"
        return
    }

    $newValue = ($values + $Value) -join ';'
    Set-RegistryValue -Name $Name -Value $newValue -RegPath $RegPath
}

function Remove-RegistryPathValue {
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter(Mandatory)]
        [string]$Name,
        [Parameter(Mandatory)]
        [string]$ValuePattern,
        [string]$RegPath = $DefaultRegPath,
		[switch]$Force
    )
    
    $current = Get-RegistryValue -Name $Name -RegPath $RegPath

    if (-not $current) {
        Write-Warning "Registry value $RegPath\$Name doesn't exist"
        return
    }

    $allValues = $current.$Name -split ';'
    $matchedValues = $allValues | Where-Object { $_ -like "*$ValuePattern*" }

    if (-not $matchedValues) {
        Write-Warning "No values matching pattern '*$ValuePattern*' found in $RegPath\$Name"
        return
    }

    # Interactive selection
    $selection = @()
    if ($matchedValues.Count -gt 1) {
        Write-Host "`nMultiple matches found:" -ForegroundColor Cyan
        $matchedValues | ForEach-Object { 
            "[$($matchedValues.IndexOf($_)+1)] $_" 
        } | Out-Host

        do {
            $input = Read-Host "`nSelect numbers to delete (comma-separated, 'a' for all, 'q' to quit)"
            if ($input -eq 'q') { return }
            if ($input -eq 'a') { 
                $selection = $matchedValues
                break 
            }
            
            $indexes = $input -split ',' | ForEach-Object { 
                if ($_ -match '^\d+$') { [int]$_ - 1 }
            } | Where-Object { $_ -ge 0 -and $_ -lt $matchedValues.Count }
            
            $selection = $matchedValues[$indexes] | Select-Object -Unique
        } while (-not $selection)
    }
    else {
        $selection = $matchedValues
    }

    # Confirmation
    $shouldDelete = $Force
    if (-not $shouldDelete) {
        Write-Host "`nSelected for deletion:" -ForegroundColor Yellow
        $selection | ForEach-Object { "• $_" } | Out-Host
        
        $confirmation = Read-Host "`nConfirm deletion? (y/n)"
        $shouldDelete = $confirmation -eq 'y'
    }

    if ($shouldDelete) {
        $newValue = ($allValues | Where-Object { $selection -notcontains $_ }) -join ';'
        Set-RegistryValue -Name $Name -Value $newValue -RegPath $RegPath
        Write-Host "Successfully removed $($selection.Count) entries." -ForegroundColor Green
    }
    else {
        Write-Host "Deletion canceled." -ForegroundColor Gray
    }
}
