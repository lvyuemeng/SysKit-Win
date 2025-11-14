param (
	[CmdletBinding()]
	[Parameter(Position = 0)]
	[string]$command,
	[Parameter(ValueFromRemainingArguments = $true)]
	[string[]]$args
)

# --- Helper ---
$DEFAULT_PROXY = "https://gh-proxy.org"

$HELP_MSG = @"
Scoop Setup and Management Tool

Usage: scoop-tool.ps1 <command> [options]

Commands:
  install    Install or update Scoop with specified source
  bucket     Manage bucket configurations
  help       Show this help message

Examples:
  scoop-setup.ps1 install --source proxy
  scoop-setup.ps1 bucket resolve --to spc
  scoop-setup.ps1 bucket proxy --name main --url https://gh-proxy.com

Install Options:
  --source, -s <source>    Installation source (proxy|china|native) [default: proxy]
    'proxy'   - Use proxy ($DEFAULT_PROXY/https://raw.githubusercontent.com/ScoopInstaller/Install/master/install.ps1)
    'native'  - Use native source (https://get.scoop.sh)

Bucket Options:
  resolve --to <bucket> --from <bucket>  Change bucket resolution for installed apps
  proxy <bucket> --url <proxy>   Set proxy for specific bucket
"@
$SCOOP_MISS_MSG = "Please ensure Scoop is installed and available in your environment." 

function parse {
	param([string[]]$Flows)
	$res = @{}
	$position = 0

	for ($i = 0; $i -lt $Flows.Length; $i++) {
		$arg = $Flows[$i]
		switch -Regex ($arg) {
			'^-{1,2}' {
				$param = $arg -replace '^-{1,2}'
				# parameter values
				if ($i + 1 -lt $Flows.Length -and $Flows[$i + 1] -notmatch '^-') {
					$res[$param] = $Flows[$i + 1]
					$i++
				}
				else {
					$res[$param] = $true
				}
			}
			default {
				$res["_$position"] = $arg
				$position++
			}
		}
	}
	return $res
}

function may_scoop_dir {
	param ()
	
	if (-Not (Get-Command scoop -ErrorAction SilentlyContinue)) {
		Write-Error $SCOOP_MISS_MSG
		return $null
	}

	if (Test-Path $env:SCOOP -ErrorAction SilentlyContinue) {
		return $env:SCOOP
	}
 else {
		return "$env:USERPROFILE\scoop"
	}
}

function resolve_bucket {
	param(
		[string]$bucketsRoot,
		[string]$bucket
	)
	$bucketsTo = @()
	Write-Debug "Resolving bucket: $bucket"
	if ($bucket -eq '*') {
		# Get all bucket directory names
		Write-Host "Processing proxy for ALL installed buckets..." -ForegroundColor Yellow
		$bucketsTo = Get-ChildItem -Path $bucketsRoot -Directory | Select-Object -ExpandProperty Name
		if (-not $bucketsTo) {
			Write-Warning "No buckets found in '$bucketsRoot'. Exiting."
			return $null
		}
	}
 else {
		# Process a single specified bucket
		$bucketPath = Join-Path $bucketsRoot $bucket
		if (-not (Test-Path $bucketPath)) {
			Write-Error "Bucket '$bucket' not found at: $bucketPath"
			return
		}
		$bucketsTo = @($bucket)
	}
	
	return $bucketsTo
}

function Install-Scoop {
	param([string]$source = "proxy")
    
	if (Get-Command "scoop" -ErrorAction SilentlyContinue) {
		Write-Host "Scoop already installed." -ForegroundColor Yellow
		return
	}

	Write-Host "Installing Scoop with source: $source..." -ForegroundColor Cyan

	$installScript = switch ($source) {
		"proxy" { 
			"$DEFAULT_PROXY/https://raw.githubusercontent.com/ScoopInstaller/Install/master/install.ps1"
		}
		"native" {
			"https://get.scoop.sh"
		}
	}

	try {
		Write-Host "Downloading installation script from: $installScript"
		Invoke-RestMethod -Uri $installScript | Invoke-Expression
		Write-Host "Scoop installed successfully!" -ForegroundColor Green
	}
	catch {
		Write-Error "Failed to install Scoop: $_"
		exit 1
	}

	# Post-install configuration
	if ($source -eq "proxy") {
		Write-Host "Configuring proxy settings..." -ForegroundColor Cyan
		scoop config scoop_repo "$DEFAULT_PROXY/https://github.com/ScoopInstaller/scoop"
		scoop bucket add spc "$DEFAULT_PROXY/https://github.com/lvyuemeng/scoop-cn"
        
		if ($Options["to"]) {
			Set-ToBucket -To $Options["to"]
		}
	}
}


function Set-ToBucket {
	param(
		[string]$To,
		[string[]]$From = @("main", "extras", "versions", "nirsoft", "sysinternals", "php", "nerd-fonts", "nonportable", "java", "games")
	)

	if (-not $To) {
		Write-Error "Bucket name is required. Use: <cli> bucket resolve --to <bucket>"
		return
	}

	# get scoop dir
	$scoopDir = may_scoop_dir
	if (-not $scoopDir) { return }

	Write-Host "Updating bucket names to '$To'..." -ForegroundColor Cyan

	# escape regex metacharacters in bucket names
	$fromRegex = ($From | ForEach-Object { 
			[Regex]::Escape($_) 
		} | Select-Object -Unique) -join '|'

	try {
		$installJsons = Get-ChildItem -Path (Join-Path $scoopDir "apps") -Recurse -Filter "install.json" -ErrorAction Stop
		if (-not $installJsons) {
			Write-Warning "No install.json files found. This might be normal if no apps are installed yet."
			return
		}

		$updatedCount = 0

		foreach ($installJson in $installJsons) {
			$content = Get-Content -Path $installJson.FullName -Raw

			# --- the core replacement ---
			# replace `"bucket": "<anything in $From>"` (including possibly empty)
			$newContent = $content -replace "`"bucket`": `"(?:$fromRegex)?`"", "`"bucket`": `"$To`""

			if ($content -ne $newContent) {
				Set-Content -Path $installJson.FullName -Value $newContent -Encoding UTF8
				$updatedCount++
			}
		}

		Write-Host "Updated $updatedCount app configuration(s)." -ForegroundColor Green
	}
	catch {
		Write-Error "Failed to update bucket names: $_"
	}
}

function Set-BucketProxy {
	param(
		[string]$bucket,
		[string]$proxy
	)

	$scoopDir = may_scoop_dir
	if (-not $scoopDir) { return }

	if (-not (Get-Command git -ErrorAction SilentlyContinue)) {
		Write-Error "Git is required but not found in PATH."
		return
	}

	$useProxy = if ($proxy -ne "default") {
		$true
	}
 else {
		$false
	}

	if ([string]::IsNullOrWhiteSpace($proxy)) {
		$proxy = $DEFAULT_PROXY
	}
	$proxy = $proxy.TrimEnd('/')

	$bucketsRoot = Join-Path $scoopDir "buckets"
	$bucketsTo = resolve_bucket -bucketsRoot $bucketsRoot -bucket $bucket
	if (-Not $bucketsTo) {
		return 
	}

	foreach ($curBucket in $bucketsTo) {
		$bucketPath = Join-Path $bucketsRoot $curBucket
		
		Write-Host "`n--- Processing Bucket: $curBucket ---" -ForegroundColor Yellow

		try {
			$curSource = git -C $bucketPath config --get remote.origin.url
			Write-Host "Current remote URL: $curSource"
			
			$baseSource = ($curSource -split '(?=https?://)')[-1] 
			
			$newSource = if ($useProxy) {
				Write-Host "Setting proxy for bucket '$curBucket' to: $proxy" -ForegroundColor Cyan
				"$proxy/$baseSource"
			}
			else {
				Write-Host "Recovering bucket '$curBucket' to original source" -ForegroundColor Cyan
				$baseSource
			}
			
			Write-Host "New remote URL: $newSource"
			git -C $bucketPath remote set-url origin $newSource
			Write-Host "Bucket proxy updated successfully for '$curBucket'!" -ForegroundColor Green
		}
		catch {
			Write-Error "Failed to set bucket proxy for '$curBucket': $($_.Exception.Message)"
		}
	}
}

function Invoke-MainCommand {
	param([string]$Command, [string[]]$SubCommands)
	$argsMap = parse $SubCommands
    
	switch -Regex ($Command) {
		"install" {
			$source = [string]($argsMap["_0"] ?? $argsMap["s"] ?? $argsMap["source"])
			Install-Scoop -source $source
		}
		"bucket" {
			$subCommand = $argsMap["_0"]
			switch ($subCommand) {
				"resolve" {
					Set-ToBucket -To $argsMap["to"] -From $argsMap["from"]
				}
				"proxy" {
					Write-Debug "argsMap: $($argsMap | Out-String)"
					Set-BucketProxy -bucket $argsMap["_1"] -proxy $argsMap["url"]
				}
				default {
					Write-Warning "Available bucket subcommands: resolve, proxy"
					Write-Warning "Use: scoop-setup.ps1 --help for more information"
				}
			}
		}
		"-(-h|-\?|/\?|--help)" {
			Write-Host $HELP_MSG
		}
		default {
			Write-Host $HELP_MSG
		}
	}
}

if ($MyInvocation.InvocationName -ne '.') {
	Invoke-MainCommand $command $args
}