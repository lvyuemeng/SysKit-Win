param (
	[CmdletBinding()]
	# auto bucket change.
	[string]$to,
	[string[]]$setBucketProxy,
	[ValidateSet("china", "proxy", "native")]
	[string]$req = "proxy",
	[Parameter(ValueFromRemainingArguments = $true)]
	[string[]]$args
)

# --- Help ---

$help_ctx = @"
This script will install scoop.

Usage: scoop-setup.ps1 [options]

Options:
	-req [native|china|proxy] default: proxy
		'china' will use 'https://c.xrgzs.top/c/scoop' proxy which is china only.
		'proxy' will use 'https://ghfast.top/raw.githubusercontent.com/lzwme/scoop-proxy-cn/main/install.ps1' proxy.
		'native' will use 'https://get.scoop.sh'.
	
	-to <new_bucket_name>
		This will change the bucket name within the install.json files of every legacy bucket apps.
		Suitable for proxy bucket change.

	-SetBucketProxy <proxy_prefix> <bucket>
		This will change the Source of a specific bucket with proxy prefix.
		Requires a valid git client in the PATH.
		List by appending comma ",".
		Example: scoop-setup.ps1 -SetBucketProxy "https://gh-proxy.com", "main"

"@

$scoop_miss = "Please ensure Scoop is installed and available in your environment." 

$may_help = $args | Where-Object {
	$_ -match "^-(h|/?)|--help$"
}

if ($may_help) {
	Write-Host $help_ctx
	exit 0	
}

# --- change bucket ---
function change_bucket {
	param (
		[string]$to
	)

	Write-Host "Changing bucket name to '$to' in all installed apps..."
	try {
		$installJsonFiles = Get-ChildItem -Path "$env:USERPROFILE\scoop\apps" -Recurse -Filter "install.json" -ErrorAction Stop
		if (-not $installJsonFiles) {
			Write-Warning "No install.json files found. This might be normal if no apps are installed yet."
			return
		}
		
		$installJsonFiles | ForEach-Object { 
			$content = Get-Content -Path $_.FullName -Raw
			$replacement = '"bucket": "' + $to + '"'
			$content = $content -replace '"bucket": "(main|extras|versions|nirsoft|sysinternals|php|nerd-fonts|nonportable|java|games|scoop-cn)"', $replacement
			Set-Content -Path $_.FullName -Value $content
		}
		Write-Host "Bucket names updated."
	}
	catch {
		Write-Error "Failed to update certain apps bucket. $_"
		Write-Error $scoop_miss
	}
}

# --- set bucket proxy ---
function set-bucket-proxy {
	param(
		[string]$proxyPrefix,
		[string]$bucketName
	)
	if (-not (Get-Command git -ErrorAction SilentlyContinue)) {
		Write-Error "Git is not installed or not in the PATH. Cannot set bucket proxies."
		return
	}
	
	Write-Host "Setting remote URL for bucket '$bucketName' using proxy: '$proxyPrefix'..."
	
	try {
		$scoopBuckets = scoop bucket list
		$bucketSource = $scoopBuckets | Where-Object { $_.Name -eq $bucketName } | Select-Object -ExpandProperty 'Source'
		if (-not $bucketSource) {
			Write-Error "Bucket '$bucketName' not found. Please ensure the bucket is added to Scoop."
			return
		}
		$bucketPath = "$env:USERPROFILE\scoop\buckets\$bucketName"
		
		if (Test-Path -Path $bucketPath -PathType Container) {
			$newUrl = "$proxyPrefix/$bucketSource"
			Write-Host "Changing '$bucketName' remote to '$newUrl'..."
			& git -C $bucketPath remote set-url origin $newUrl
			Write-Host "Bucket remote URL has been updated."
		} else {
			Write-Warning "Bucket '$bucketName' not found at '$bucketPath'. Please ensure the bucket is added before setting its proxy."
		}
	}
	catch {
		Write-Error "Failed to get Scoop bucket list. $_"
		Write-Error $scoop_miss
	}
}

# --- Install ---
function install_scoop {
	param (
		[ValidateSet("china", "proxy", "native")]
		[string]$req = "proxy"
	)
	
	Write-Host "Installing scoop..."
	if (Get-Command "scoop" -ErrorAction SilentlyContinue) {
		Write-Host "scoop already installed, updating..."
		& scoop update
		& scoop update *
		return
	}

	$exp = switch ($req) {
		"china" {
			"Invoke-WebRequest c.xrgzs.top/c/scoop | Invoke-Expression"
		}
		"proxy" {
			"Invoke-WebRequest https://ghfast.top/raw.githubusercontent.com/lzwme/scoop-proxy-cn/main/install.ps1 | Invoke-Expression"
		}
		"native" {
			"Invoke-RestMethod -Uri https://get.scoop.sh | Invoke-Expression"
		}
	}
	# install scoop
	try {
		Invoke-Expression $exp
	}
	catch {
		Write-Error "Failed to install Scoop: $_"
		exit 1
	}

	# config repo/bucket
	if ($req -eq "proxy") {
		& scoop config scoop_repo "https://gitee.com/scoop-installer/scoop"
		& scoop bucket add spc https://gh-proxy.com/https://github.com/duzyn/scoop-cn

		# replace to spc bucket.
		change_bucket -to "spc"
	}
}

if ($setBucketProxy -and $setBucketProxy.Count -ge 2) {
	$proxyPrefix = $setBucketProxy[0]
	$bucketName = $setBucketProxy[1]
	set-bucket-proxy -proxyPrefix $proxyPrefix -bucketName $bucketName
	exit 0
} elseif ($setBucketProxy) {
	Write-Error "SetBucketProxy requires both proxy prefix and bucket name."
	Write-Host "Usage: scoop-setup.ps1 -SetBucketProxy <proxy_prefix> <bucket_name>"
	exit 1
}

# app bucket change
if ($to) {
	change_bucket -to $to
	exit 0
}

# default install
install_scoop -req $req

