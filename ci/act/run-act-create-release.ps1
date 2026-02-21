[CmdletBinding()]
param(
    [Parameter(ValueFromRemainingArguments = $true)]
    [string[]]$PassThruArgs
)

Push-Location (Join-Path $PSScriptRoot "../..") -Verbose

# Verify act is installed
if (-not (Get-Command act -ErrorAction SilentlyContinue)) {
    Write-Error "act is not installed. Visit https://nektosact.com/"
    exit 1
}

$SecretFile = ".LOCAL/.secrets"
$EventFile = "ci/act/create-release-event.json"
$Workflow = ".github/workflows/create-release.yml"

Write-Output "🚀 Running act..."

# Note: $PassThruArgs is passed at the end
& act -P windows-latest=-self-hosted `
    --secret-file "$SecretFile" `
    -e "$EventFile" `
    -W "$Workflow" `
    @PassThruArgs

Pop-Location
