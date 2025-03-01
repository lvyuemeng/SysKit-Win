Import-Module -Name Pester

BeforeDiscovery {
	$modulePath = (Get-Item $PSScriptRoot).Parent.Parent.FullName
	Import-Module $modulePath -Force -ErrorAction Stop
}

InModuleScope SysKit { 
	Describe "Reg" {
		It "Query Reg default" {
			QueryReg > $null
		}
		It "Query Reg Check Output" {
			$res = QueryReg
			$res | Should -Not -BeNullOrEmpty
			Write-Output "Name: $($res.Name)"
			Write-Output "Value: $($res.Value)"
			Write-Output "Path: $($res.Path)"
		}
	}
}