# install.ps1 — register dsh-workspace-launcher in a DeepSeek Harness profile (0.2.x).
#
# This installer does NOT patch any Harness package. It installs/links the bundle
# `plugin/dsh-workspace-launcher` and lets the profile Loader mount its row.
#
# Usage:
#   .\install.ps1                 # use $env:DSH_PROFILE, else "desktop"
#   .\install.ps1 -Profile web    # target another profile
#   .\install.ps1 -NoInstall      # print the manual steps only

param(
    [string]$Profile = $(if ($env:DSH_PROFILE) { $env:DSH_PROFILE } else { 'desktop' }),
    [switch]$NoInstall
)

$ErrorActionPreference = 'Stop'
$repoRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$pluginDir = Join-Path $repoRoot 'plugin\dsh-workspace-launcher'
$dshHome = if ($env:DSH_HOME) { $env:DSH_HOME } else { Join-Path $env:USERPROFILE '.dsh' }

function Write-Step([string]$msg) { Write-Host "[dsh-workspace-launcher] $msg" -ForegroundColor Cyan }

if (-not (Test-Path $pluginDir)) { throw "plugin directory not found: $pluginDir" }

Write-Step "target profile: $Profile"
Write-Step "bundle directory: $pluginDir"

if ($NoInstall) {
    Write-Step 'manual steps:'
    Write-Host @"
1) Open the Harness Plugin Manager → install from folder → choose:
     $pluginDir
2) Enable "dsh-workspace-launcher".
3) Reload the page.

Or add this to $dshHome\profiles\$Profile\cordis.patch.yml after linking the
package into that profile's node_modules:

- insert:
    - id: workspace-open
      name: 'dsh-workspace-launcher'
"@
    exit 0
}

$dsh = Get-Command dsh -ErrorAction SilentlyContinue
if ($null -eq $dsh) {
    Write-Step 'the `dsh` CLI is not on PATH (Desktop installs usually are not).'
    Write-Step 'Use Plugin Manager → install from folder → choose the directory below, then enable the bundle.'
    Write-Host "  $pluginDir"
    exit 0
}

& $dsh.Source plugin --profile $Profile add $pluginDir
if ($LASTEXITCODE -ne 0) { throw "dsh plugin add failed with exit code $LASTEXITCODE" }
Write-Step 'installed. Reload the Harness page (the client bundle loads on enable).'
