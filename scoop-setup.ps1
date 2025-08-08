param (
	[CmdletBinding()]
	[ValidateSet("china", "proxy", "native")]
	[string]$req = "proxy",
	[Parameter(ValueFromRemainingArguments = $true)]
	[string[]]$args
)

# --- Help ---

$help_ctx = """
This script will install scoop.

Usage: scoop-setup.ps1 [options]

Options:
	-req [native|china|proxy] default: proxy
"""

$may_help = $args | Where-Object {
	$_ -match "-(h|/?)|--help"
}

if ($may_help) {
	Write-Host $help_ctx
	exit 0	
}

# --- Install ---

Write-Host "Installing scoop..."
if (Get-Command "scoop" -ErrorAction SilentlyContinue) {
	Write-Host "scoop already installed, updating..."
	& scoop update
	exit 0
}

$exp = switch ($req) {
	"china" {
		"Invoke-WebRequest -useb scoop.201704.xyz | Invoke-Expression"
	}
	"proxy" {
		"Invoke-WebRequest https://ghfast.top/raw.githubusercontent.com/lzwme/scoop-proxy-cn/main/install.ps1 | Invoke-Expression"
	}
	"native" {
		"Invoke-RestMethod -Uri https://get.scoop.sh | Invoke-Expression"
	}
}
# install scoop
# unrecover
Invoke-Expression $exp -ErrorAction Stop

# config repo/bucket
& scoop config SCOOP_REPO "https://gitee.com/scoop-installer/scoop"
& scoop bucket add spc "https://gitee.com/wlzwme/scoop-proxy-cn.git"

# update bucket spc
& Set-Location "$env:USERPROFILE\scoop\buckets\spc"
& git fetch -all && git checkout -b main origin/main

