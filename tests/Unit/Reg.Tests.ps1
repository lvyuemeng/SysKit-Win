Import-Module -Name Pester

BeforeDiscovery {
	$modulePath = (Get-Item $PSScriptRoot).Parent.Parent.FullName
	Import-Module $modulePath -Force -ErrorAction Stop
}

InModuleScope SysKit { 
	Describe "Get-RegistryValue" {
		It "Query Reg default" {
			$res = Get-RegistryValue
			Write-Host $res
		}
	}
	Describe "Reg" {
		It "Ops" {
			Set-RegistryValue -Name "Tst" -Value "123"
			$res = Get-RegistryValue -Name "Tst"
			$res.Tst | Should -Be "123"
			Add-RegistryPathValue -Name "Tst" -Value "456"
			$res = Get-RegistryValue -Name "Tst"
			$res.Tst | Should -Be "123;456"
			Remove-RegistryPathValue -Name "Tst" -Value "456"
			$res = Get-RegistryValue -Name "Tst"
			$res.Tst | Should -Be "123"
		}
	}
}