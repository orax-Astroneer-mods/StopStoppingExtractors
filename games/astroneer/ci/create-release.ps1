Push-Location (Join-Path $PSScriptRoot "../../..") -Verbose

#
# Create "AstroModLoader Classic" PAK archive
#

$astroneer_pakDirName = "000-$env:REPO_NAME-${env:VERSION}_P"
$astroneer_pakFileName = "$astroneer_pakDirName.pak"
$astroneer_resourcesDir = $env:RESOURCES_DIR

$releaseDir = $env:RELEASE_DIR
$astroneer_pakDir = Join-Path $releaseDir $astroneer_pakDirName

# Create the directory for AstroModLoader Classic
if (Test-Path $astroneer_pakDir) {
    Remove-Item -Path $astroneer_pakDir -Recurse -Force
}
New-Item -Path $astroneer_pakDir -ItemType Directory | Out-Null

# Create the UE4SS directory
$UE4SSDir = Join-Path $astroneer_pakDir "UE4SS"
New-Item -Path $UE4SSDir -ItemType Directory | Out-Null

# Delete enabled.txt because AstroModLoader Classic uses mods.txt to enable mods
Remove-Item -Path (Join-Path $env:TARGET_DIR "enabled.txt")

# Move existing TargetDir content into UE4SS
Get-ChildItem -Path $env:TARGET_DIR | Move-Item -Destination $UE4SSDir

#
# Read mod metadata from mod.json file
#

$jsonPath = "mod.json"

if (-not (Test-Path -Path $jsonPath -PathType Leaf)) {
    throw "Critical Error: File not found at '$jsonPath'. Ensure the path is correct."
}

$jsonRawContent = Get-Content -Path $jsonPath -Raw -Encoding utf8

# Test JSON validity (syntax + structure)
$schemaPath = Join-Path $env:RESOURCES_DIR "schema.json"
if (-not ($jsonRawContent | Test-Json)) {
    throw "❌ Malformed JSON (syntax error). JSON path: $jsonPath"
}
if (-not ($jsonRawContent | Test-Json -SchemaFile $schemaPath)) {
    throw "❌ JSON is valid but does not conform to the schema rules. JSON path: $jsonPath"
}

$modMetadata = $jsonRawContent | ConvertFrom-Json

$description = ""
if ($modMetadata.description -is [Array]) {
    $description = $modMetadata.description -join '\n'
}
else {
    $description = $modMetadata.description
}

#
# Write metadata.json
#

$metadataFile = "metadata.json"
$TargetMetadata = Join-Path -Path $astroneer_pakDir $metadataFile

$jsonObject = @{
    author         = $modMetadata.author
    description    = $description
    download       = @{
        type = 'index_file'
        url  = "https://raw.githubusercontent.com/$env:GITHUB_REPOSITORY/refs/heads/master/games/astroneer/resources/index.json"
    }
    enable_ue4ss   = $true
    homepage       = $modMetadata.homepage
    mod_id         = $env:REPO_NAME
    name           = $modMetadata.name
    schema_version = 2
    sync           = 'client'
    version        = $env:VERSION
}

$jsonContent = $jsonObject | ConvertTo-Json 

Set-Content -Path $TargetMetadata -Value $jsonContent -Encoding utf8

Write-Output "📝 Content of the file: $TargetMetadata"
Write-Output $jsonContent

# Test JSON validity (syntax + structure)
$schemaPath = Join-Path $PSScriptRoot '..' $astroneer_resourcesDir 'schema-metadata-v2.json'
if (-not ($jsonContent | Test-Json)) {
    throw "❌ Malformed JSON (syntax error). JSON path: $TargetMetadata"
}
if (-not ($jsonContent | Test-Json -SchemaFile $schemaPath)) {
    throw "❌ JSON is valid but does not conform to the schema rules. JSON path: $TargetMetadata"
}

#
# Create the PAK file
# https://astroneermodding.readthedocs.io/en/latest/guides/basicSetup.html#setting-up-repak
# https://github.com/trumank/repak
#

$RepakExe = Join-Path $env:RESOURCES_DIR "repak_cli-x86_64-pc-windows-msvc/repak.exe"

if (-not (Test-Path $astroneer_pakDir)) {
    throw "PAK directory does not exist: $astroneer_pakDir"
}

$CmdArgs = @("pack", "--version", "V4", $astroneer_pakDir)
Write-Output "Run command: $RepakExe $($CmdArgs -join ' ')"
& $RepakExe @CmdArgs

$PakFilePath = Join-Path $releaseDir $astroneer_pakFileName

if ($LASTEXITCODE -ne 0) {
    throw "PAK build failed: $RepakExe returned exit code $LASTEXITCODE."
}

if (-not (Test-Path $PakFilePath)) {
    throw "PAK build failed: File not found at expected location -> $PakFilePath"
}

Pop-Location
