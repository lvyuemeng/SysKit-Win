$DefaultRegPath = "HKCU:\Environment"
$UserShellFolders = "HKCU:\Software\Microsoft\windows\CurrentVersion\Explorer\User Shell Folders"
$User
function NameCheck {
    param([string]$Name)

    $Name = $Name.toUpper()
    if ($Name -eq "PATH") {
        throw "Use Add/Remove for PATH modifications"
    }
}

function SetReg {
    [CmdletBinding(SupportsShouldProcess, ConfirmImpact = "High")]
    param (
        [Parameter(Mandatory)]
        [string]$Name,
        [string]$Value,
        [string]$RegPath = $DefaultRegPath
    )
    
    NameCheck -Name $Name

    if ($PSCmdlet.ShouldProcess("$RegPath\$Name", "Set value")) {
        try {
            Set-ItemProperty -Path "$RegPath" -Name $Name -Value $Value -ErrorAction Stop -Confirm:$false -WhatIf:$WhatIfPreference
        }
        catch {
            throw "Failed to set registry value: $_"
        }
    }
}

function RemoveReg {
    [CmdletBinding(SupportsShouldProcess, ConfirmImpact = "High")]
    param(
        [Parameter(Mandatory)]
        [string]$Name,
        [string]$RegPath = $DefaultRegPath
    )

    NameCheck -Name $Name

    if ($PSCmdlet.ShouldProcess("$RegPath\$Name", "Remove value")) {
        try {
            Remove-ItemProperty -Path "$RegPath" -Name $Name -ErrorAction Stop -Confirm:$false -WhatIf:$WhatIfPreference
        }
        catch {
            throw "Failed to remove registry value: $_"
        }
    }
}

function QueryReg {
    [CmdletBinding()]
    param(
        [Parameter(Position = 0)]
        [string]$NamePattern = "*",
        [Parameter(Position = 1)]
        [string]$ValuePattern = "*",

        [string]$RegPath = $DefaultRegPath
    )

    try {
        $rawProperties = Get-ItemProperty -Path $RegPath -ErrorAction Stop
        
        $results = $rawProperties.PSObject.Properties | Where-Object {
            $_.Name -like $NamePattern -and 
            $_.Value -like $ValuePattern -and
            $_.Name -notmatch '^PS'
        } | Select-Object Name, Value, TypeNameofValue

        return $results
    }
    catch [System.Management.Automation.ItemNotFoundException] {
        Write-Warning "Registry path $RegPath does not exist"
    }
    catch [System.UnauthorizedAccessException] {
        Write-Error "Access denied to registry path $RegPath"
    }
    catch {
        Write-Error "Unexpected error: $_"
    }
}

function AddReg {
    [CmdletBinding(SupportsShouldProcess, ConfirmImpact = "High")]
    param(
        [Parameter(Mandatory)]
        [string]$Name,
        [Parameter(Mandatory)]
        [ValidateScript({ Test-ValidPath -Path $_ })]
        [string]$Value,
        [string]$RegPath = $DefaultRegPath
    )
    
    $current = QueryReg $Name -RegPath $RegPath

    if (-not $current) {
        SetReg -Name $Name -Value $Value -RegPath $RegPath -WhatIf:$WhatIfPreference -Confirm:$false
        return
    }

    $values = $current.$Name -split ';'
    if ($values -contains $Value) {
        Write-Warning "'$Value' already exists in $RegPath\$Name"
        return
    }

    $newValue = ($values + $Value) -join ';'
    if ($PSCmdlet.ShouldProcess("$RegPath\$Name", "Add value $Value")) {
        SetReg -Name $Name -Value $newValue -RegPath $RegPath -WhatIf:$WhatIfPreference -Confirm:$false
    }
}

function DeleteReg {
    [CmdletBinding(SupportsShouldProcess, ConfirmImpact = "High")]
    param(
        [Parameter(Mandatory)]
        [string]$Name,
        [Parameter(Mandatory)]
        [string]$ValuePattern,
        [string]$RegPath = $DefaultRegPath,
        [switch]$Force
    )
    
    $current = QueryReg $Name -RegPath $RegPath

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

    $selection = Read-Selection -matchedValues $matchedValues

    $displayed = $selection | ForEach-Object { "• $_" } | Out-String
    if ($PSCmdlet.ShouldProcess("$RegPath\$Name", "Remove value $displayed")) {
        $remainingValues = ($allValues | Where-Object { $selection -notcontains $_ });
        $newValue = if ($remainingValues.Count -gt 0) { 
            $remainingValues -join ';' 
        }
        else { 
            $null
        }
        SetReg -Name $Name -Value $newValue -RegPath $RegPath -WhatIf:$WhatIfPreference -Confirm:$false
        $statusMessage = if ($null -eq $newValue) {
            "with value deletion"
        }
        else {
            "retaining $($remainingValues.Count) entries"
        }
        Write-Host "Successfully removed $($selection.Count) entries ($statusMessage)." -ForegroundColor Green
    }
    else {
        Write-Host "Deletion canceled." -ForegroundColor Gray
    }
}
