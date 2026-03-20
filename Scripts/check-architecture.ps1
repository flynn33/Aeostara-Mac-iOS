# Aeostara Architecture Check Script
# Copyright (c) 2026 James Daley. All Rights Reserved.
# Proprietary and Confidential.
#
# Quick architecture validation for CI/pre-commit.
# Usage: powershell -ExecutionPolicy Bypass -File Scripts/check-architecture.ps1

param(
    [string]$SourceDir = $PSScriptRoot + "/.."
)

$ErrorActionPreference = "Stop"
$SourceDir = Resolve-Path $SourceDir
$failures = 0

Write-Host "Aeostara Architecture Check" -ForegroundColor Cyan
Write-Host "Source: $SourceDir"
Write-Host ""

# 1. Grep for forbidden Forsetti includes
$hits = Get-ChildItem -Path "$SourceDir/include","$SourceDir/src" -Recurse -Include "*.h","*.cpp" |
    Select-String -Pattern '#include.*Forsetti' -List

if ($hits.Count -gt 0) {
    Write-Host "[FAIL] Forbidden Forsetti includes:" -ForegroundColor Red
    $hits | ForEach-Object { Write-Host "  $_" -ForegroundColor Yellow }
    $failures++
} else {
    Write-Host "[OK] No Forsetti includes" -ForegroundColor Green
}

# 2. Check Core→CLI dependency direction
$reverseDep = Get-ChildItem -Path "$SourceDir/include/AeostaraCore","$SourceDir/src/AeostaraCore" -Recurse -Include "*.h","*.cpp" |
    Select-String -Pattern '#include.*AeostaraCLI' -List

if ($reverseDep.Count -gt 0) {
    Write-Host "[FAIL] Core depends on CLI:" -ForegroundColor Red
    $reverseDep | ForEach-Object { Write-Host "  $_" -ForegroundColor Yellow }
    $failures++
} else {
    Write-Host "[OK] Dependency direction correct (CLI→Core)" -ForegroundColor Green
}

# 3. Check namespace isolation
$nsHits = Get-ChildItem -Path "$SourceDir/include","$SourceDir/src" -Recurse -Include "*.h","*.cpp" |
    Select-String -Pattern 'namespace\s+Forsetti\b' -List

if ($nsHits.Count -gt 0) {
    Write-Host "[FAIL] Forsetti namespace in Aeostara source:" -ForegroundColor Red
    $nsHits | ForEach-Object { Write-Host "  $_" -ForegroundColor Yellow }
    $failures++
} else {
    Write-Host "[OK] Namespace isolation (Aeostara only)" -ForegroundColor Green
}

# 4. No Python in product source
$pythonHits = Get-ChildItem -Path "$SourceDir/include","$SourceDir/src" -Recurse -Include "*.h","*.cpp" |
    Select-String -Pattern 'python|Python' -List

if ($pythonHits.Count -gt 0) {
    Write-Host "[FAIL] Python references in product source:" -ForegroundColor Red
    $pythonHits | ForEach-Object { Write-Host "  $_" -ForegroundColor Yellow }
    $failures++
} else {
    Write-Host "[OK] No Python references in product source" -ForegroundColor Green
}

# 5. No YAML in product source
$yamlHits = Get-ChildItem -Path "$SourceDir/include","$SourceDir/src" -Recurse -Include "*.h","*.cpp" |
    Select-String -Pattern 'yaml|YAML|Yaml|yaml-cpp' -List

if ($yamlHits.Count -gt 0) {
    Write-Host "[FAIL] YAML references in product source:" -ForegroundColor Red
    $yamlHits | ForEach-Object { Write-Host "  $_" -ForegroundColor Yellow }
    $failures++
} else {
    Write-Host "[OK] No YAML references in product source" -ForegroundColor Green
}

Write-Host ""
if ($failures -eq 0) {
    Write-Host "Architecture check PASSED" -ForegroundColor Green
    exit 0
} else {
    Write-Host "Architecture check FAILED ($failures issues)" -ForegroundColor Red
    exit 1
}
