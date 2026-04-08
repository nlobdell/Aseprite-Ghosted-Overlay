param(
  [Parameter(Mandatory = $true)]
  [string]$AsepriteRepoPath
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$overlayRoot = Split-Path -Parent $PSScriptRoot
$targetRoot = (Resolve-Path -LiteralPath $AsepriteRepoPath).Path
$targetGitDir = Join-Path $targetRoot ".git"

if (-not (Test-Path -LiteralPath $targetGitDir)) {
  throw "Target path is not a git checkout: $targetRoot"
}

$sourceExtension = Join-Path $overlayRoot "extensions\\ghostling-tools"
$sourceGuide = Join-Path $overlayRoot "CUSTOMIZATION.md"
$patchPath = Join-Path $overlayRoot "patches\\ghosted-ui.patch"

if (-not (Test-Path -LiteralPath $sourceExtension)) {
  throw "Missing extension source at $sourceExtension"
}

if (-not (Test-Path -LiteralPath $sourceGuide)) {
  throw "Missing guide file at $sourceGuide"
}

if (-not (Test-Path -LiteralPath $patchPath)) {
  throw "Missing patch file at $patchPath"
}

$targetExtensionsRoot = Join-Path $targetRoot "data\\extensions"
$targetExtension = Join-Path $targetExtensionsRoot "ghostling-tools"

Push-Location $targetRoot
try {
  & git apply --check $patchPath
  if ($LASTEXITCODE -ne 0) {
    throw "Patch check failed for $patchPath"
  }

  & git apply $patchPath
  if ($LASTEXITCODE -ne 0) {
    throw "Patch apply failed for $patchPath"
  }
}
finally {
  Pop-Location
}

New-Item -ItemType Directory -Force -Path $targetExtensionsRoot | Out-Null
$resolvedExtensionsRoot = (Resolve-Path -LiteralPath $targetExtensionsRoot).Path

if (Test-Path -LiteralPath $targetExtension) {
  $resolvedTargetExtension = (Resolve-Path -LiteralPath $targetExtension).Path
  if (-not $resolvedTargetExtension.StartsWith($resolvedExtensionsRoot, [System.StringComparison]::OrdinalIgnoreCase)) {
    throw "Refusing to replace extension outside target repo: $resolvedTargetExtension"
  }

  Remove-Item -LiteralPath $resolvedTargetExtension -Recurse -Force
}

Copy-Item -LiteralPath $sourceExtension -Destination $targetExtension -Recurse
Copy-Item -LiteralPath $sourceGuide -Destination (Join-Path $targetRoot "CUSTOMIZATION.md") -Force

Write-Host "Ghosted overlay installed into $targetRoot"
