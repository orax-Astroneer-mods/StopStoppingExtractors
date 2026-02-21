[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [string]$github_ref_name,

    [Parameter(Mandatory)]
    [string]$github_repository
)

Set-StrictMode -Version Latest

Push-Location (Join-Path $PSScriptRoot "..") -Verbose

Write-Host "🏷️ github_ref_name: $github_ref_name"
Write-Host "📦 github_repository: $github_repository"

$projectRootDir = [System.IO.Path]::GetFullPath((Join-Path $PSScriptRoot ".."))
$version = $github_ref_name -replace '^v(?=\d+\.\d+\.\d+)', ''
$repoOwner, $repoName = $github_repository -split '/'

$tempDir = ".TEMP"
$releaseDir = ".RELEASE"
$resourcesDir = "resources"
$targetDir = Join-Path $releaseDir $repoName
     
$releaseFilename = "$repoName.zip"
$releaseRelPath = Join-Path $releaseDir $releaseFilename

@{
    PROJECT_ROOT_DIR   = $projectRootDir

    VERSION            = $version
    REPO_OWNER         = $repoOwner
    REPO_NAME          = $repoName

    $GITHUB_REPOSITORY = $github_repository

    RESOURCES_DIR      = $resourcesDir
    TEMP_DIR           = $tempDir
    RELEASE_DIR        = $releaseDir
    TARGET_DIR         = $targetDir

    RELEASE_FILENAME   = $releaseFilename
    RELEASE_REL_PATH   = $releaseRelPath
}.GetEnumerator() | ForEach-Object {
    if ($env:GITHUB_ENV) {
        # Export for next GitHub Actions steps
        "$($_.Key)=$($_.Value)" | Out-File -FilePath $env:GITHUB_ENV -Append -Encoding utf8
    }
    else {
        # Make variable available in the current script (useful when script is run locally)
        Set-Item -Path "env:$($_.Key)" -Value $_.Value
    }
}

# List of directories to create
$dirs = @($resourcesDir, $tempDir, $releaseDir)

# Create each directory if it doesn't exist
foreach ($dir in $dirs) {
    if (-not (Test-Path $dir)) {
        Write-Output "📁 Create directory: $dir"
        New-Item -Path $dir -ItemType Directory | Out-Null
    }
}

Pop-Location
