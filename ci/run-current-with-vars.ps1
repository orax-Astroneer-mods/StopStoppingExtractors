<#
.SYNOPSIS
Run a PowerShell script with environment variables set from ci\set-vars.ps1
.DESCRIPTION
This script first executes ci\set-vars.ps1 to initialize environment variables,
passing two arguments, then runs the target script without arguments.
#>

param(
    [string]$ScriptToRun,          # Path to the target script (e.g., ${file})
    [string]$GithubRefName,        # First argument for set-vars.ps1
    [string]$GithubRepository      # Second argument for set-vars.ps1
)

Set-StrictMode -Version Latest

Push-Location (Join-Path $PSScriptRoot "..") -Verbose

# ---------------------------
# Load set-vars.ps1
# ---------------------------
$SetVarsScript = Join-Path $PSScriptRoot "set-vars.ps1"

if (-not (Test-Path $SetVarsScript)) {
    throw "Cannot find set-vars.ps1 at path $SetVarsScript"
}

Write-Output "Loading environment variables from $SetVarsScript..."
& $SetVarsScript -github_ref_name $GithubRefName -github_repository $GithubRepository

# ---------------------------
# Run the target script
# ---------------------------
if (-not (Test-Path $ScriptToRun)) {
    throw "Target script not found: $ScriptToRun"
}

Write-Output "Running script: $ScriptToRun"
& $ScriptToRun

Pop-Location
