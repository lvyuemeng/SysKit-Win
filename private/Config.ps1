$Global:ConfigPath = Join-Path $Global:ConfigDir 'config.json'
$Global:Config = if (Test-Path $ConfigPath) {
	Get-Content -Path $ConfigPath | ConvertFrom-Json
} else {
	throw "Config not found at $ConfigPath"
}

$Global:Root = $Global:Config.Root
$Global:Schema = $Global:Config.Schema
$Global:Stratum = $Global:Config.Stratum
$Global:Features = $Global:Config.Features
