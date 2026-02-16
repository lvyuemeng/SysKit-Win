# tests/schema.Tests.ps1 - Tests for schema module (no system changes)

BeforeAll {
    Import-Module "$PSScriptRoot\..\schema.psm1" -Force
}

Describe "Get-RegistryMap" {
    It "Should return registry maps" {
        $maps = Get-RegistryMap
        $maps | Should -Not -BeNullOrEmpty
    }
    
    It "Should contain expected categories" {
        $maps = Get-RegistryMap
        $maps.Keys | Should -Contain "Clipboard"
        $maps.Keys | Should -Contain "Explorer"
        $maps.Keys | Should -Contain "Theme"
    }
    
    It "Should return specific category when requested" {
        $explorer = Get-RegistryMap -Category "Explorer"
        $explorer | Should -Not -BeNullOrEmpty
        $explorer.Path | Should -Be "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced"
    }
}

Describe "Get-SpecSchema" {
    It "Should return specification schema" {
        $schema = Get-SpecSchema
        $schema | Should -Not -BeNullOrEmpty
    }
    
    It "Should contain expected keys" {
        $schema = Get-SpecSchema
        $schema.Keys | Should -Contain "Name"
        $schema.Keys | Should -Contain "Registry"
        $schema.Keys | Should -Contain "Package"
        $schema.Keys | Should -Contain "Service"
        $schema.Keys | Should -Contain "Feature"
        $schema.Keys | Should -Contain "Trigger"
    }
}

Describe "Test-SpecSchema" {
    It "Should validate correct specification" {
        $validSpec = @{
            Name = "test"
            Registry = @{
                Explorer = @{ ShowHidden = $true }
            }
            Package = @{
                Installed = @("git", "nodejs")
            }
        }
        
        Test-SpecSchema -Config $validSpec | Should -Be $true
    }
    
    It "Should reject unknown registry category" {
        $invalidSpec = @{
            Registry = @{
                UnknownCategory = @{ SomeProp = $true }
            }
        }
        
        Test-SpecSchema -Config $invalidSpec | Should -Be $false
    }
    
    It "Should reject invalid feature value" {
        $invalidSpec = @{
            Feature = @{
                "SomeFeature" = "invalid"
            }
        }
        
        Test-SpecSchema -Config $invalidSpec | Should -Be $false
    }
    
    It "Should accept valid feature values" {
        $validSpec = @{
            Feature = @{
                "TestFeature" = "enabled"
            }
        }
        
        Test-SpecSchema -Config $validSpec | Should -Be $true
    }
    
    It "Should reject invalid service state" {
        $invalidSpec = @{
            Service = @{
                "TestService" = @{ State = "invalid" }
            }
        }
        
        Test-SpecSchema -Config $invalidSpec | Should -Be $false
    }
    
    It "Should accept valid service configuration" {
        $validSpec = @{
            Service = @{
                "TestService" = @{ 
                    State = "stopped"
                    Startup = "disabled"
                }
            }
        }
        
        Test-SpecSchema -Config $validSpec | Should -Be $true
    }
    
    It "Should reject unknown trigger" {
        $invalidSpec = @{
            Trigger = @{
                "UnknownTrigger" = $true
            }
        }
        
        Test-SpecSchema -Config $invalidSpec | Should -Be $false
    }
    
    It "Should accept valid triggers" {
        $validSpec = @{
            Trigger = @{
                Activation = $true
                Debloat = "silent"
                Office = "C:\Installers"
            }
        }
        
        Test-SpecSchema -Config $validSpec | Should -Be $true
    }
}

Describe "Get-ProviderInfo" {
    It "Should return info for declarative providers" {
        $info = Get-ProviderInfo -Name "Registry"
        $info | Should -Not -BeNullOrEmpty
        $info.Name | Should -Be "Registry"
        $info.Type | Should -Be "Declarative"
    }
    
    It "Should return info for trigger providers" {
        $info = Get-ProviderInfo -Name "Activation"
        $info | Should -Not -BeNullOrEmpty
        $info.Name | Should -Be "Activation"
        $info.Type | Should -Be "Trigger"
    }
    
    It "Should return null for unknown provider" {
        $info = Get-ProviderInfo -Name "UnknownProvider"
        $info | Should -BeNullOrEmpty
    }
}
