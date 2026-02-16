# tests/logging.Tests.ps1 - Tests for logging module (no system changes)

BeforeAll {
    Import-Module "$PSScriptRoot\..\logging.psm1" -Force
}

Describe "Write-Log" {
    It "Should accept valid log levels" {
        { Write-Log -Level "INFO" -Message "Test message" } | Should -Not -Throw
        { Write-Log -Level "OK" -Message "Test message" } | Should -Not -Throw
        { Write-Log -Level "APPLIED" -Message "Test message" } | Should -Not -Throw
        { Write-Log -Level "WARN" -Message "Test message" } | Should -Not -Throw
    }
    
    It "Should require Level parameter" {
        { Write-Log -Message "Test" } | Should -Throw
    }
    
    It "Should require Message parameter" {
        { Write-Log -Level "INFO" } | Should -Throw
    }
    
    It "Should validate Level parameter" {
        { Write-Log -Level "INVALID" -Message "Test" } | Should -Throw
    }
}

Describe "Write-LogProcess" {
    It "Should log process message" {
        { Write-LogProcess -Name "TestItem" } | Should -Not -Throw
    }
    
    It "Should require Name parameter" {
        { Write-LogProcess } | Should -Throw
    }
}

Describe "Write-LogOk" {
    It "Should log OK message with name and value" {
        { Write-LogOk -Name "TestItem" -DesiredValue "TestValue" } | Should -Not -Throw
    }
    
    It "Should require both parameters" {
        { Write-LogOk -Name "Test" } | Should -Throw
        { Write-LogOk -DesiredValue "Test" } | Should -Throw
    }
}

Describe "Write-LogApplied" {
    It "Should log applied message" {
        { Write-LogApplied -Name "TestItem" -DesiredValue "TestValue" } | Should -Not -Throw
    }
}

Describe "Write-LogChange" {
    It "Should log change message with current and desired values" {
        { Write-LogChange -Name "TestItem" -CurrentValue "Old" -DesiredValue "New" } | Should -Not -Throw
    }
    
    It "Should require all three parameters" {
        { Write-LogChange -Name "Test" -CurrentValue "Old" } | Should -Throw
    }
}

Describe "Write-LogError" {
    It "Should log error message" {
        { Write-LogError -Name "TestItem" } | Should -Not -Throw
    }
    
    It "Should accept optional Details parameter" {
        { Write-LogError -Name "TestItem" -Details "Additional info" } | Should -Not -Throw
    }
}

Describe "Write-LogHeader" {
    It "Should log header" {
        { Write-LogHeader -Title "Test Header" } | Should -Not -Throw
    }
}

Describe "Write-LogSection" {
    It "Should log section" {
        { Write-LogSection -Name "TestSection" } | Should -Not -Throw
    }
}
