Import-Module -Name Pester

BeforeDiscovery {
	$modulePath = (Get-Item $PSScriptRoot).Parent.Parent.FullName
	Import-Module $modulePath -Force -ErrorAction Stop
}


InModuleScope SysKit {
	Describe "Read-Object" {
		It "Read correctly" {
			$Prompt = "Enter name"
			$Validator = { param($Value)
    -not [string]::IsNullOrWhiteSpace($Value) }

			$object = Read-Object -Prompt $Prompt -Validator $Validator
			$object | Should -Not -BeNullOrEmpty
		}
	}

	Describe "TraverseJson" {
		It "traverse correctly" {
			Get-Module SysKit | Should -Not -BeNullOrEmpty
			$JsonObject = @{
				"a" = 1
				"b" = @{
					"c" = 3
					"d" = 4
				}
				"e" = 5
			}

			TraverseJson -JsonObject $JsonObject -Action { param($key, $path, $value) Write-Host "path: $path, value: $value" }
		}
	}
}