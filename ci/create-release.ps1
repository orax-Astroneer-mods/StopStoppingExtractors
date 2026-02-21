<#
.SYNOPSIS
PowerShell script to create a GitHub release
.DESCRIPTION
- Copies files into .RELEASE
- Creates version.txt and enabled.txt files
- Creates a ZIP archive
- (Optional) Depends on softprops/action-gh-release to create the release
#>

Set-StrictMode -Version Latest

Push-Location (Join-Path $PSScriptRoot "..") -Verbose

#
# Prepare the release folder
#

if (-not (Test-Path $env:RELEASE_DIR)) {
    New-Item -Path $env:RELEASE_DIR -ItemType Directory | Out-Null
}

if (Test-Path $env:TARGET_DIR) {
    Remove-Item -Path $env:TARGET_DIR -Recurse -Force
}

New-Item -Path $env:TARGET_DIR -ItemType Directory | Out-Null

#
# Copy files
#

# Read excluded files for the release from an external file
$Excludes = Get-Content -Path './ci/excluded-files-in-release.txt'

# Copy "Scripts" directory
Copy-Item -Path 'Scripts' -Destination $env:TARGET_DIR -Recurse

# Copy all files in the current directory except the excluded ones
Get-ChildItem -File | Where-Object { $Excludes -notcontains $_.Name } | ForEach-Object {
    Copy-Item -Path $_.FullName -Destination $env:TARGET_DIR
}

#
# Create enabled.txt and version.txt
#

New-Item -Path (Join-Path -Path  $env:TARGET_DIR "enabled.txt") -ItemType File | Out-Null
Set-Content -Path (Join-Path -Path $env:TARGET_DIR "version.txt") -Value $env:VERSION

#
# Create ZIP archive
#

if (Test-Path $env:RELEASE_REL_PATH) { Remove-Item $env:RELEASE_REL_PATH }

Compress-Archive -Path $env:TARGET_DIR -DestinationPath $env:RELEASE_REL_PATH -Force
Write-Output "ZIP created: $env:RELEASE_REL_PATH"

if (-not (Test-Path $env:RELEASE_REL_PATH)) {
    throw "ZIP release failed."
}

Pop-Location
