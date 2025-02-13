Import-Module -Name Pester

BeforeAll {
	$modulePath = (Get-Item $PSScriptRoot).Parent.FullName
	Import-Module $modulePath\SysKit.psd1 -Force -ErrorAction Stop
}

Describe "TraverseJson" {
	It "traverse correctly" {
		$JsonObject = @{
			"a" = 1
			"b" = @{
				"c" = 3
				"d" = 4
			}
			"e" = 5
		}
		
		$keys = @(
			"a"
			"b\c"
			"b\d"
			"e"
		)

		Write-Debug "tst"

		TraverseJson -JsonObject $JsonObject -Action { param($key, $path, $value) Write-Information "path: $path, value: $value" $key | Should -Be $keys[$key] }
	}
}