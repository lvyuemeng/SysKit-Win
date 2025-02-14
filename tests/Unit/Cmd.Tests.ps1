Import-Module -Name Pester

BeforeDiscovery {
	$modulePath = (Get-Item $PSScriptRoot).Parent.Parent.FullName
	Import-Module $modulePath -Force -ErrorAction Stop
}

InModuleScope SysKit { 
	Describe "Edit" {
		Get-Module SysKit | Should -Not -BeNullOrEmpty
		It "open editor correctly" {
			Get-Config -WhatIf
		}
	}

	Describe "Features" {
		It "enable features correctly" {
			Add-Features -WhatIf
		}
	}
}