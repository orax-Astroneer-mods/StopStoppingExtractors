Write-Output "🕹️ Run the custom script for the game Astroneer..."

Set-StrictMode -Version Latest

Push-Location (Join-Path $PSScriptRoot "..") -Verbose

$astroneer_tempDir = $env:TEMP_DIR

if ([string]::IsNullOrWhiteSpace($astroneer_tempDir)) {
    throw "Variable `$tempDir is invalid (null, empty or whitespace)."
}

@{
    ASTRONEER_TEMP_DIR = $astroneer_tempDir
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
$dirs = @($astroneer_tempDir)

# Create each directory if it doesn't exist
foreach ($dir in $dirs) {
    if (-not (Test-Path $dir)) {
        New-Item -Path $dir -ItemType Directory | Out-Null
    }
}

Pop-Location
