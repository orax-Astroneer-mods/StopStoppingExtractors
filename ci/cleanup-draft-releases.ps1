# Example:
# With this GitHub URL: https://github.com/OWNER/MY_REPO
# .\cleanup-draft-releases.ps1 -github_repository "OWNER/MY_REPO"
# or using positional argument:
# .\cleanup-draft-releases.ps1 "OWNER/MY_REPO"


[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$github_repository
)

Set-StrictMode -Version Latest

Push-Location (Join-Path $PSScriptRoot "..") -Verbose

Write-Output "🔍 Searching for v0.0.0 drafts in: $github_repository"

if (-not (Get-Command gh -ErrorAction SilentlyContinue)) {
    throw "GitHub CLI (gh) not found."
}

$drafts = gh release list --repo $github_repository --json "tagName,name,isDraft" | ConvertFrom-Json

# Check if the gh command succeeded
if ($LASTEXITCODE -ne 0) {
    throw '"gh" command failed. You may need to run "gh auth login" or check your GITHUB_TOKEN.'
}

# Filter drafts named v0.0.0 or with tag v0.0.0
$draftsToDelete = $drafts | Where-Object { $_.isDraft -eq $true -and ($_.name -eq 'v0.0.0' -or $_.tagName -eq 'v0.0.0') }

if (-not $draftsToDelete) {
    Write-Output "✅ No draft releases named v0.0.0 found."
    return
}

foreach ($release in $draftsToDelete) {
    # Use tagName for deletion if name is ambiguous
    $target = if ($release.tagName) { $release.tagName } else { $release.name }
    Write-Output "🗑️ Deleting draft release: $target"
    gh release delete $target --repo $github_repository --yes
}

Pop-Location
