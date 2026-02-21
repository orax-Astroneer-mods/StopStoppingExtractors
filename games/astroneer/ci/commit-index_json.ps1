Set-StrictMode -Version Latest

Push-Location (Join-Path $PSScriptRoot "..") -Verbose

$file = "resources\index.json"
        
git config --local user.email "github-actions[bot]@users.noreply.github.com"
git config --local user.name "github-actions[bot]"

if (Test-Path $file) {
    $status = git status --porcelain $file
    if ($null -eq $status) {
        Write-Warning "⚠️ No changes detected in $file. Skipping commit."
        return 
    }

    # [skip ci] means skipping workflow runs
    # https://docs.github.com/en/actions/how-tos/manage-workflow-runs/skip-workflow-runs
    $msg = "ci: update index.json [skip ci]"

    git add $file

    if ($env:ACT -eq "true") {
        Write-Output "🧪 ACT detected: performing dry-run commit..."
        git commit -m "$msg (dry run)" --dry-run
        git status --short
    }
    else {
        Write-Output "🚀 Pushing changes to repository..."
        git commit -m $msg
        git push
    }
}
else {
    throw "❌ File $file not found. Nothing to commit."
}

Pop-Location
