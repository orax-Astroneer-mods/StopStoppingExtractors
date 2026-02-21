[CmdletBinding()]
param(
    [Parameter()]
    [string]$repoOwner = $env:GITHUB_REPOSITORY_OWNER,

    [Parameter()]
    [string]$scriptToExecute = "script.ps1"
)

Set-StrictMode -Version Latest

Push-Location (Join-Path $PSScriptRoot "..") -Verbose

if ($repoOwner -match "-([^-]+)-mods") {
    $gameName = $Matches[1]
    Write-Output "🕹️ Run custom script for the game: $gameName"
    $gameName = $gameName.ToLowerInvariant()
    "GAME_NAME=$gameName" | Out-File -FilePath $env:GITHUB_ENV -Append -Encoding utf8
    $scriptPath = Join-Path "games" $gameName "ci" $scriptToExecute

    if (Test-Path $scriptPath) {
        Write-Output "🚀 Executing custom script '$scriptToExecute' for the game ($gameName): $scriptPath"
        # Run the game-specific script
        & $scriptPath
    }
    else {
        Write-Output "Custom script ($scriptToExecute) for the game '$gameName' does not exist. scriptPath: $scriptPath"
    }
}
else {
    Write-Warning "Cannot get the game name from repository owner: $repoOwner."
}