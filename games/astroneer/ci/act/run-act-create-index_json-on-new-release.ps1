[CmdletBinding()]
param(
    [Parameter(ValueFromRemainingArguments = $true)]
    [string[]]$PassThruArgs
)

Push-Location (Join-Path $PSScriptRoot "../../../..") -Verbose

# Verify act is installed
if (-not (Get-Command act -ErrorAction SilentlyContinue)) {
    Write-Error "act is not installed. Visit https://nektosact.com/"
    exit 1
}

$SecretFile = ".LOCAL/.secrets"
$EventFile = "games/astroneer/ci/act/create-index_json-on-new-release-event.json"
$Workflow = ".github/workflows/game-astroneer_create-index_json-on-new-release.yml"

Write-Output "🚀 Running act..."

# Note: $PassThruArgs is passed at the end
& act workflow_run -P windows-latest=-self-hosted `
    --secret-file "$SecretFile" `
    -e "$EventFile" `
    -W "$Workflow" `
    @PassThruArgs

Pop-Location
