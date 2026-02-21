[CmdletBinding()]
param(
    [Parameter()]
    [bool]$isDraft = $false
)

Set-StrictMode -Version Latest

Push-Location (Join-Path $PSScriptRoot "..") -Verbose

Write-Output "📝 Release is draft: $isDraft"

$astroneer_indexFilePath = Join-Path $env:RESOURCES_DIR "index.json"
$astroneer_tagsFilePath = Join-Path $env:ASTRONEER_TEMP_DIR "tags.json"

# Default to false if $env:ACT is not set
if ($null -ne $env:ACT) {
    try {
        $act = [bool]::Parse($env:ACT.ToLower())
    }
    catch {
        Write-Warning "Invalid value for ACT: '$($env:ACT)'. Defaulting to false."
        $act = $false
    }
}
else {
    $act = $false
}

Write-Output "🧪 act is $act"

# Check if the local file exists
if (-not (Test-Path $astroneer_tagsFilePath)) {
    Write-Output "$astroneer_tagsFilePath not found. Downloading from GitHub..."

    $TagsUrl = "https://api.github.com/repos/$env:GITHUB_REPOSITORY/tags"
    $Headers = @{ "User-Agent" = "Mozilla/5.0" }  # GitHub API requires a User-Agent

    try {
        # Download tags from GitHub
        $Tags = Invoke-RestMethod -Uri $TagsUrl -Headers $Headers

        # Check if $Tags is empty
        if (-not $Tags -or $Tags.Count -eq 0) {
            throw "❌ No tags were returned from GitHub. URL: $TagsUrl"
        }

        # Save locally as JSON
        $Tags | ConvertTo-Json -Depth 10 | Set-Content $astroneer_tagsFilePath -Encoding UTF8

        Write-Output "Tags saved to $astroneer_tagsFilePath"
    }
    catch {
        throw "Failed to download tags. URL: $TagsUrl $_"
    }
}
else {
    Write-Output "$astroneer_tagsFilePath already exists. Using local file."
    $Tags = Get-Content $astroneer_tagsFilePath -Raw | ConvertFrom-Json
}

# Initialize main structure
$Json = [ordered]@{ mods = [ordered]@{} }

# Ensure the specific mod entry exists
if (-not $Json.mods.Contains($env:REPO_NAME)) {
    $Json.mods[$env:REPO_NAME] = [ordered]@{ latest_version = ""; versions = [ordered]@{} }
}

# Process Tags
foreach ($TagObj in $Tags) {
    $TagName = $TagObj.name
    
    # Regex check for semantic versioning (vX.Y.Z)
    if ($TagName -notmatch '^v(\d+\.\d+\.\d+)$') { continue }
    $Version = $Matches[1]

    # Skip if version already exists to save network requests
    if ($Json.mods.$env:REPO_NAME.versions.Contains($Version)) { continue }

    $FileName = "000-$env:REPO_NAME-$Version`_P.pak"
    $ReleaseUrl = "https://github.com/$env:GITHUB_REPOSITORY/releases/download/$TagName/$FileName"

    try {
        # Verify if the release asset actually exists
        Invoke-WebRequest -Uri $ReleaseUrl -Method Head -UserAgent "Mozilla/5.0" -ErrorAction Stop | Out-Null
        
        $Json.mods.$env:REPO_NAME.versions.$Version = [ordered]@{
            download_url = $ReleaseUrl
            filename     = $FileName
        }
        Write-Output "✅ Added: $Version"
    }
    catch {
        Write-Warning "⚠️ Asset not found for $TagName. URL: $ReleaseUrl"
    }
}

# --- RESTRUCTURING & FINAL SORTING ---

# Sort versions for the current mod (using [version] type for correct numerical sorting)
$AllVersions = $Json.mods.$env:REPO_NAME.versions.Keys | Sort-Object { [version]$_ }

if ($AllVersions) {
    $SortedVersions = [ordered]@{}
    foreach ($v in $AllVersions) { 
        $SortedVersions[$v] = $Json.mods.$env:REPO_NAME.versions.$v
    }

    # Update current mod data
    $Json.mods.$env:REPO_NAME.versions = $SortedVersions
    $Json.mods.$env:REPO_NAME.latest_version = $AllVersions | Select-Object -Last 1
}

# ALPHABETICAL SORTING OF MODS + KEY ORDERING
$SortedMods = [ordered]@{}
$ModNames = $Json.mods.Keys | Sort-Object # Alphabetical sort of mod names

foreach ($Name in $ModNames) {
    $CurrentMod = $Json.mods[$Name]
    
    # Reconstruct the mod object to force 'latest_version' to appear BEFORE 'versions'
    $SortedMods[$Name] = [ordered]@{
        latest_version = $CurrentMod.latest_version
        versions       = $CurrentMod.versions
    }
}

# Replace the unsorted mods list with the sorted one
$Json.mods = $SortedMods

# Convert your object to JSON (Depth 10 to preserve nested objects)
$JsonText = $Json | ConvertTo-Json -Depth 10

Write-Output "📄 New JSON content:`n"

# Print JSON as plain text
Write-Output $JsonText

# Save JSON to file
$JsonText | Set-Content $astroneer_indexFilePath -Encoding utf8

Write-Output "`n✨ File $astroneer_indexFilePath updated and sorted successfully!`n"

Pop-Location
