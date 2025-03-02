Import-Module -Name Pester

BeforeDiscovery {
	$modulePath = (Get-Item $PSScriptRoot).Parent.Parent.FullName
	Import-Module $modulePath -Force -ErrorAction Stop
}

InModuleScope SysKit { 
	Describe "Get-RegistryValue" {
		It "Query Reg default" {
			$res = QueryReg 
			$res | Format-Table -AutoSize -Wrap | Out-String | Write-Host
		}
		It "Query Reg with fuzzyName" {
			$res = QueryReg "path"
			$res | Format-Table -AutoSize -Wrap | Out-String | Write-Host
		}
	}
	Describe "Reg" {
		It "Ops" {
			SetReg -Name "Tst" -Value "123"
			$res = QueryReg -Name "Tst"
			$res.Tst | Should -Be "123"

			AddReg -Name "Tst" -Value "456"
			$res = QueryReg -Name "Tst"
			$res.Tst | Should -Be "123;456"

			DeleteReg -Name "Tst" -Value "456"
			$res = QueryReg -Name "Tst"
			$res.Tst | Should -Be "123"

			DeleteReg -Name "Tst" -Value "123"
			$res = QueryReg -Name "Tst"
			$res.Tst | Should -Be ""

			RemoveReg -Name "Tst"
		}
	}
	Describe "Reg Null" {
		It "Set" {
			SetReg -Name "Tst_" -Value ""
			$res = QueryReg -Name "Tst_"
			$res.Tst_ | Should -Be ""

			RemoveReg -Name "Tst_"
			$res = QueryReg -Name "Tst_"
			$res.Tst_ | Should -BeNullOrEmpty
		}
	}
	Describe "Reg Path" {
		It "Set Path with Error" {
			try { SetReg -Name "Path" -Value "!" }
			catch {
				$_.Exception.Message | Should -Be "Use Add/Remove for PATH modifications"
			}
		}
	}
}