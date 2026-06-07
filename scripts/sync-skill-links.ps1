<#
.SYNOPSIS
Sync shared skills into tool-specific skill folders as directory links.

.DESCRIPTION
Creates junctions from `skills/<name>` into:
  - `.codex/skills/<name>`
  - `.claude/skills/<name>`
  - `.opencode/skills/<name>`

By default the script is conservative:
  - missing links are created
  - existing correct links are kept
  - existing real directories are left untouched
  - mismatched links are skipped unless `-ReplaceExistingLinks` is passed

.EXAMPLE
powershell -ExecutionPolicy Bypass -File scripts\sync-skill-links.ps1

.EXAMPLE
powershell -ExecutionPolicy Bypass -File scripts\sync-skill-links.ps1 -ReplaceExistingLinks
#>
[CmdletBinding(SupportsShouldProcess = $true)]
param(
  [ValidateSet("Junction", "SymbolicLink")]
  [string]$LinkType = "Junction",

  [switch]$ReplaceExistingLinks
)

$ErrorActionPreference = "Stop"

function Test-IsLink {
  param(
    [Parameter(Mandatory = $true)]$Item
  )

  return ($null -ne $Item.LinkType) -or (($Item.Attributes -band [IO.FileAttributes]::ReparsePoint) -ne 0)
}

function Test-TargetsMatch {
  param(
    [Parameter(Mandatory = $true)]$Item,
    [Parameter(Mandatory = $true)][string]$ExpectedTarget
  )

  if (-not (Test-IsLink -Item $Item)) {
    return $false
  }

  $actualTargets = @($Item.Target | ForEach-Object { [string]$_ })
  foreach ($target in $actualTargets) {
    if ([string]::Equals($target, $ExpectedTarget, [System.StringComparison]::OrdinalIgnoreCase)) {
      return $true
    }
  }

  return $false
}

$repoRoot = Split-Path -Parent $PSScriptRoot
$sharedRoot = Join-Path $repoRoot "skills"
$toolRoots = @(
  (Join-Path $repoRoot ".codex\skills"),
  (Join-Path $repoRoot ".claude\skills"),
  (Join-Path $repoRoot ".opencode\skills")
)

if (-not (Test-Path -LiteralPath $sharedRoot -PathType Container)) {
  throw "Shared skills folder not found: $sharedRoot"
}

$sharedSkills = Get-ChildItem -LiteralPath $sharedRoot -Directory | Sort-Object Name
if ($sharedSkills.Count -eq 0) {
  Write-Host "No shared skills found under $sharedRoot" -ForegroundColor Yellow
  exit 0
}

$created = 0
$updated = 0
$skipped = 0
$warnings = 0

foreach ($toolRoot in $toolRoots) {
  if (-not (Test-Path -LiteralPath $toolRoot -PathType Container)) {
    if ($PSCmdlet.ShouldProcess($toolRoot, "Create tool skills directory")) {
      New-Item -ItemType Directory -Path $toolRoot -Force | Out-Null
      Write-Host "Created tool skills directory: $toolRoot" -ForegroundColor Cyan
    }
  }

  foreach ($skill in $sharedSkills) {
    $linkPath = Join-Path $toolRoot $skill.Name
    $targetPath = $skill.FullName

    if (-not (Test-Path -LiteralPath $linkPath)) {
      if ($PSCmdlet.ShouldProcess($linkPath, "Create $LinkType to $targetPath")) {
        New-Item -ItemType $LinkType -Path $linkPath -Target $targetPath | Out-Null
        Write-Host "Linked: $linkPath -> $targetPath" -ForegroundColor Green
        $created++
      }
      continue
    }

    $item = Get-Item -LiteralPath $linkPath -Force

    if (Test-TargetsMatch -Item $item -ExpectedTarget $targetPath) {
      Write-Host "OK: $linkPath" -ForegroundColor DarkGray
      $skipped++
      continue
    }

    if (Test-IsLink -Item $item) {
      if ($ReplaceExistingLinks) {
        if ($PSCmdlet.ShouldProcess($linkPath, "Replace existing link with $LinkType to $targetPath")) {
          Remove-Item -LiteralPath $linkPath -Force
          New-Item -ItemType $LinkType -Path $linkPath -Target $targetPath | Out-Null
          Write-Host "Re-linked: $linkPath -> $targetPath" -ForegroundColor Yellow
          $updated++
        }
      } else {
        Write-Warning "Skip mismatched link: $linkPath"
        $warnings++
      }
      continue
    }

    Write-Warning "Skip existing real directory or file: $linkPath"
    $warnings++
  }
}

Write-Host ""
Write-Host "sync-skill-links summary" -ForegroundColor Cyan
Write-Host "  created: $created"
Write-Host "  updated: $updated"
Write-Host "  skipped: $skipped"
Write-Host "  warnings: $warnings"
