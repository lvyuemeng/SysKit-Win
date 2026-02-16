# tests/triggers.Tests.ps1 - Tests for trigger providers with mocked operations

BeforeAll {
    Import-Module "$PSScriptRoot\..\logging.psm1" -Force
    
    # Mock all external network calls and system operations
    Mock Invoke-RestMethod { return "mock script content" }
    Mock Invoke-WebRequest { }
    Mock Start-Process { }
    Mock New-Item { return @{ FullName = "MockPath" } }
    Mock Join-Path { return "MockPath\Officesetup.exe" }
    Mock Test-Path { return $true }
    
    # Import trigger providers with specific prefixes to avoid naming conflicts
    Import-Module "$PSScriptRoot\..\providers\activation.psm1" -Force -Prefix Activation
    Import-Module "$PSScriptRoot\..\providers\debloat.psm1" -Force -Prefix Debloat  
    Import-Module "$PSScriptRoot\..\providers\office.psm1" -Force -Prefix Office
}

Describe "Activation Trigger Provider" {
    Context "Get-ProviderInfo" {
        It "Should return correct provider info" {
            $info = Get-ActivationProviderInfo
            $info.Name | Should -Be "Activation"
            $info.Type | Should -Be "Trigger"
        }
    }
    
    Context "Invoke-ActivationTrigger" {
        It "Should return DryRun status when WhatIf is specified" {
            $result = Invoke-ActivationActivationTrigger -Option $true -WhatIf
            
            $result.Status | Should -Be "DryRun"
            $result.Message | Should -Match "dry run"
        }
        
        It "Should accept boolean option" {
            $result = Invoke-ActivationActivationTrigger -Option $true -WhatIf
            $result | Should -Not -BeNullOrEmpty
        }
        
        It "Should accept string option" {
            $result = Invoke-ActivationActivationTrigger -Option "KMS38" -WhatIf
            $result | Should -Not -BeNullOrEmpty
        }
        
        It "Should accept hashtable option" {
            $result = Invoke-ActivationActivationTrigger -Option @{ Method = "KMS38" } -WhatIf
            $result | Should -Not -BeNullOrEmpty
        }
    }
}

Describe "Debloat Trigger Provider" {
    Context "Get-ProviderInfo" {
        It "Should return correct provider info" {
            $info = Get-DebloatProviderInfo
            $info.Name | Should -Be "Debloat"
            $info.Type | Should -Be "Trigger"
        }
    }
    
    Context "Invoke-DebloatTrigger" {
        It "Should return DryRun status when WhatIf is specified" {
            $result = Invoke-DebloatDebloatTrigger -Option $true -WhatIf
            
            $result.Status | Should -Be "DryRun"
            $result.Message | Should -Match "dry run"
        }
        
        It "Should accept string option" {
            $result = Invoke-DebloatDebloatTrigger -Option "silent" -WhatIf
            $result | Should -Not -BeNullOrEmpty
        }
        
        It "Should accept hashtable option" {
            $result = Invoke-DebloatDebloatTrigger -Option @{ 
                Silent = $true
                RemoveApps = $true
                CreateRestorePoint = $true
            } -WhatIf
            $result | Should -Not -BeNullOrEmpty
        }
        
        It "Should accept default boolean option" {
            $result = Invoke-DebloatDebloatTrigger -Option $true -WhatIf
            $result | Should -Not -BeNullOrEmpty
        }
    }
}

Describe "Office Trigger Provider" {
    Context "Get-ProviderInfo" {
        It "Should return correct provider info" {
            $info = Get-OfficeProviderInfo
            $info.Name | Should -Be "Office"
            $info.Type | Should -Be "Trigger"
        }
    }
    
    Context "Invoke-OfficeTrigger" {
        It "Should return DryRun status when WhatIf is specified" {
            $result = Invoke-OfficeOfficeTrigger -Option $true -WhatIf
            
            $result.Status | Should -Be "DryRun"
            $result.Message | Should -Match "dry run"
        }
        
        It "Should accept path string option" {
            $result = Invoke-OfficeOfficeTrigger -Option "C:\Installers" -WhatIf
            
            $result | Should -Not -BeNullOrEmpty
            $result.Path | Should -Match "Officesetup.exe"
        }
        
        It "Should accept hashtable option with Cache" {
            $result = Invoke-OfficeOfficeTrigger -Option @{ Path = "C:\Installers"; Cache = $true } -WhatIf
            
            $result | Should -Not -BeNullOrEmpty
        }
        
        It "Should use current directory when no path specified" {
            $result = Invoke-OfficeOfficeTrigger -Option $true -WhatIf
            
            $result | Should -Not -BeNullOrEmpty
        }
    }
}
