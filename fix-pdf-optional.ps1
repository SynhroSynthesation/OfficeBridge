# Description:
# SignalWar / RobotBaseGame audit script for Unity 6.
# Stage: BETA-004 Health System Stabilization.
# ASCII-only script to avoid PowerShell encoding/parser issues.
#
# This script does not modify gameplay files.
# Output:
# - Docs/BETA_004_Health_System_Audit.md

$ErrorActionPreference = "Stop"

Write-Host "=== BETA-004 Health System Audit ===" -ForegroundColor Cyan

$gitRoot = git rev-parse --show-toplevel 2>$null
if ([string]::IsNullOrWhiteSpace($gitRoot)) {
    throw "Git repository was not found."
}

Set-Location $gitRoot

$docsPath = "Docs"
$reportPath = Join-Path $docsPath "BETA_004_Health_System_Audit.md"

New-Item -ItemType Directory -Path $docsPath -Force | Out-Null

$csFiles = Get-ChildItem .\Assets -Recurse -Filter *.cs

$patterns = @(
    "class Health",
    "class HealthUnit",
    "TakeDamage",
    "Damage",
    "CurrentHealth",
    "currentHealth",
    "maxHealth",
    "SetMax",
    "SetValue",
    "Die",
    "Destroy",
    "ApplyAttack",
    "SetAttackHighlight",
    "AttackRange",
    "Warrior",
    "UnitController",
    "Building",
    "HealthBar",
    "health"
)

$matches = foreach ($pattern in $patterns) {
    $found = $csFiles | Select-String -Pattern $pattern -SimpleMatch
    foreach ($item in $found) {
        [PSCustomObject]@{
            Pattern = $pattern
            Path = $item.Path.Replace($gitRoot + "\", "")
            LineNumber = $item.LineNumber
            Line = $item.Line.Trim()
        }
    }
}

$report = New-Object System.Collections.Generic.List[string]

$report.Add("# BETA-004 Health System Audit")
$report.Add("")
$report.Add("Audit date: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')")
$report.Add("")
$report.Add("## Goal")
$report.Add("")
$report.Add("Audit current health, damage, death, attack and destroy logic.")
$report.Add("")
$report.Add("## Risks to check")
$report.Add("")
$report.Add("- Health / HealthUnit conflict.")
$report.Add("- Different damage APIs for units and buildings.")
$report.Add("- Duplicated CurrentHealth / maxHealth state.")
$report.Add("- Building damage path: Building.TakeDamage vs Health.TakeDamage.")
$report.Add("- Unit damage path: UnitController vs HealthUnit vs Health.")
$report.Add("- Warrior attack target routing: unit / building / tile.")
$report.Add("- Death / destroy cleanup in managers and tiles.")
$report.Add("")
$report.Add("## Matches")
$report.Add("")

if ($matches.Count -eq 0) {
    $report.Add("No matches found.")
}
else {
    $groups = $matches | Group-Object Path | Sort-Object Name

    foreach ($group in $groups) {
        $report.Add("### $($group.Name)")
        $report.Add("")

        foreach ($m in ($group.Group | Sort-Object LineNumber)) {
            $safeLine = $m.Line.Replace("|", "\|")
            $report.Add("- L$($m.LineNumber) [$($m.Pattern)] `$safeLine`")
        }

        $report.Add("")
    }
}

$report.Add("## Candidate files for BETA-004")
$report.Add("")

$candidateFiles = $matches |
    Select-Object -ExpandProperty Path -Unique |
    Sort-Object

foreach ($file in $candidateFiles) {
    $report.Add("- $file")
}

$report.Add("")
$report.Add("## Preliminary fix strategy")
$report.Add("")
$report.Add("1. Do not start Victory / Defeat before damage/death is stable.")
$report.Add("2. Select one runtime damage API.")
$report.Add("3. Remove duplicate HP sources where possible.")
$report.Add("4. Ensure safe cleanup:")
$report.Add("   - UnitManager unregister.")
$report.Add("   - HexTile clear unit/building reference.")
$report.Add("   - BuildingManager unregister.")
$report.Add("   - SignalManager unregister DataCenter.")
$report.Add("   - EnergyManager unregister Building.")
$report.Add("5. Then continue to BETA-005 Victory / Defeat.")
$report.Add("")

[System.IO.File]::WriteAllLines(
    (Join-Path $gitRoot $reportPath),
    $report,
    [System.Text.UTF8Encoding]::new($true)
)

Write-Host "Report created:" -ForegroundColor Green
Write-Host (Join-Path $gitRoot $reportPath)

Write-Host ""
Write-Host "Candidate files:" -ForegroundColor Cyan
$candidateFiles | ForEach-Object { Write-Host "- $_" }

Write-Host ""
Write-Host "Git status:" -ForegroundColor Cyan
git status --short

Write-Host ""
Write-Host "Audit complete." -ForegroundColor Green