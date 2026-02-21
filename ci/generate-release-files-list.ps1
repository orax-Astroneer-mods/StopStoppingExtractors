Set-StrictMode -Version Latest

Push-Location (Join-Path $PSScriptRoot "..") -Verbose

$ReleaseDir = Join-Path $env:PROJECT_ROOT_DIR $env:RELEASE_DIR

Write-Output "🔍 Searching for release files in: $ReleaseDir"

if (-not (Test-Path $ReleaseDir)) {
    Write-Error "❌ Release directory does not exist: $ReleaseDir"
    exit 1
}

$FileList = Get-ChildItem -Path $ReleaseDir -File | Select-Object -ExpandProperty FullName

if ($null -eq $FileList -or $FileList.Count -eq 0) {
    Write-Warning "⚠️ No files found."
    # Clear the local env var for this session
    $env:RELEASE_FILES_LIST = ""
    return
}

$FilesString = $FileList -join "," 

Write-Output "📦 Detected files:"
$FileList | ForEach-Object { Write-Output " - $(Split-Path $_ -Leaf)" }

$env:RELEASE_FILES_LIST = $FilesString

Write-Output "✅ Local environment variable 'RELEASE_FILES_LIST' has been set for this session."

Pop-Location
