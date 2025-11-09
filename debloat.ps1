param(
	[parameter(ValueFromRemainingArguments = $true)]
	[string[]]$options
)

# --- Help ---

$HELP_MSG = @"
This script will execute Debloat script.

Thanks to "https://github.com/Raphire/Win11Debloat/" support.

You should refer to "https://github.com/Raphire/Win11Debloat/wiki/How-To-Use" for more information!

Usage: debloat.ps1 [options]

Options:
	-CreateRestorePoint: Create a system restore point before making any changes. Unless a restore point was already created in the last 24 hours.

	-Silent:	Suppresses all interactive prompts, so the script will run without requiring any user input.

	-Sysprep:	Run the script in Sysprep mode. All changes will be applied to the Windows default user profile and will only affect new user accounts.

	-User <USERNAME>:	Run the script for the specified user, instead of the currently logged in user. This user must have logged on at least once, and cannot be logged in at the time the script is run.

	-RunDefaults:	Run the script with the default settings, including removing the default selection of apps.

	-RunSavedSettings:	Run the script with the saved custom settings from last time. These settings are saved to and read from the SavedSettings file in the root folder of the script.

	-RemoveApps:	Remove the default selection of bloatware apps.

	-RemoveAppsCustom:	Remove all apps specified in the CustomAppsList file. No apps will be removed if this file does not exist. IMPORTANT: You can generate your custom apps list by running the script with the -RunAppsListGenerator parameter as explained here.

	-RunAppsListGenerator:	Run the apps list generator to generate a custom list of apps to remove, the list is saved to the CustomAppsList file inside the root folder of the script. Running the script with the -RemoveAppsCustom parameter will remove the selected apps.

	For more information, refer: https://github.com/Raphire/Win11Debloat/wiki/How-To-Use.
"@

$all_args = @($PSBoundParameters.Values + $args)

if ($all_args -match '^(?:-h|-\?|/\?|--help)$') {
	Write-Host $HELP_MSG
	exit 0
}

& ([scriptblock]::Create((Invoke-RestMethod "https://debloat.raphi.re/"))) @options