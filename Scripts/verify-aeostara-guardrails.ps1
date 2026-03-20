# Aeostara Guardrails Verification Script
# Copyright (c) 2026 James Daley. All Rights Reserved.
# Proprietary and Confidential.
#
# Usage: powershell -ExecutionPolicy Bypass -File Scripts/verify-aeostara-guardrails.ps1
# Run from the repository root (A:/Claude/aeostara/)

param(
    [string]$SourceDir = $PSScriptRoot + "/.."
)

$ErrorActionPreference = "Stop"
$SourceDir = Resolve-Path $SourceDir
$exitCode = 0

function Write-Check {
    param([string]$Name, [bool]$Pass, [string]$Detail = "")
    if ($Pass) {
        Write-Host "  [PASS] $Name" -ForegroundColor Green
    } else {
        Write-Host "  [FAIL] $Name" -ForegroundColor Red
        if ($Detail) { Write-Host "         $Detail" -ForegroundColor Yellow }
        $script:exitCode = 1
    }
}

Write-Host ""
Write-Host "=== Aeostara Guardrails Verification ===" -ForegroundColor Cyan
Write-Host "Source directory: $SourceDir"
Write-Host ""

# ---- 1. No Forsetti includes ----
Write-Host "--- Architecture Checks ---" -ForegroundColor Cyan

$forsettiIncludes = Get-ChildItem -Path "$SourceDir/include","$SourceDir/src" -Recurse -Include "*.h","*.cpp","*.hpp" |
    Select-String -Pattern '#include\s+[<"]Forsetti' -List

Write-Check "No ForsettiCore/ForsettiPlatform includes" ($forsettiIncludes.Count -eq 0) `
    ($forsettiIncludes | ForEach-Object { $_.Path } | Out-String)

# ---- 2. No Forsetti namespace ----
$forsettiNs = Get-ChildItem -Path "$SourceDir/include","$SourceDir/src" -Recurse -Include "*.h","*.cpp","*.hpp" |
    Select-String -Pattern 'namespace\s+Forsetti' -List

Write-Check "No Forsetti namespace usage" ($forsettiNs.Count -eq 0) `
    ($forsettiNs | ForEach-Object { $_.Path } | Out-String)

# ---- 3. Copyright headers ----
$sourceFiles = Get-ChildItem -Path "$SourceDir/include","$SourceDir/src" -Recurse -Include "*.h","*.cpp","*.hpp"
$missingCopyright = @()
foreach ($file in $sourceFiles) {
    $content = Get-Content $file.FullName -Raw -ErrorAction SilentlyContinue
    if ($content -and $content -notmatch 'Copyright \(c\) 2026 James Daley') {
        $missingCopyright += $file.FullName
    }
}

Write-Check "All source files have copyright header" ($missingCopyright.Count -eq 0) `
    ($missingCopyright -join "`n")

# ---- 4. All concrete classes final ----
Write-Host ""
Write-Host "--- Class Finality Checks ---" -ForegroundColor Cyan

$headerFiles = Get-ChildItem -Path "$SourceDir/include/AeostaraCore" -Filter "*.h" |
    Where-Object { $_.Name -notmatch '^I[A-Z]' }  # Skip interface headers

$nonFinalClasses = @()
foreach ($file in $headerFiles) {
    $content = Get-Content $file.FullName -Raw
    $matches = [regex]::Matches($content, '(class|struct)\s+(\w+)\s+(?!final)[:{]')
    foreach ($m in $matches) {
        $typeName = $m.Groups[2].Value
        # Skip known non-class types
        if ($typeName -match 'Type$|Severity$') { continue }
        $nonFinalClasses += "$typeName in $($file.Name)"
    }
}

Write-Check "All concrete classes/structs are final" ($nonFinalClasses.Count -eq 0) `
    ($nonFinalClasses -join "`n")

# ---- 5. One-way dependency: Core does not depend on CLI ----
Write-Host ""
Write-Host "--- Dependency Checks ---" -ForegroundColor Cyan

$coreToCli = Get-ChildItem -Path "$SourceDir/include/AeostaraCore","$SourceDir/src/AeostaraCore" -Recurse -Include "*.h","*.cpp" |
    Select-String -Pattern '#include.*AeostaraCLI' -List

Write-Check "Core does not depend on CLI" ($coreToCli.Count -eq 0) `
    ($coreToCli | ForEach-Object { $_.Path } | Out-String)

# ---- 6. Compliance: No Python in product source ----
Write-Host ""
Write-Host "--- Compliance Checks ---" -ForegroundColor Cyan

$pythonRefs = Get-ChildItem -Path "$SourceDir/include","$SourceDir/src" -Recurse -Include "*.h","*.cpp","*.hpp" |
    Select-String -Pattern 'python|Python|\.py[\"''\s]' -List

Write-Check "No Python references in product source" ($pythonRefs.Count -eq 0) `
    ($pythonRefs | ForEach-Object { $_.Path } | Out-String)

# ---- 7. Compliance: No YAML in product source ----
$yamlRefs = Get-ChildItem -Path "$SourceDir/include","$SourceDir/src" -Recurse -Include "*.h","*.cpp","*.hpp" |
    Select-String -Pattern 'yaml|YAML|Yaml|\.yml|yaml-cpp' -List

Write-Check "No YAML references in product source" ($yamlRefs.Count -eq 0) `
    ($yamlRefs | ForEach-Object { $_.Path } | Out-String)

# ---- 8. Compliance: No YAML claims in docs ----
$yamlClaims = Select-String -Path "$SourceDir/README.md" -Pattern 'YAML support|yaml support' -List

Write-Check "No YAML support claims in README" ($yamlClaims.Count -eq 0) `
    ($yamlClaims | ForEach-Object { $_.Line } | Out-String)

# ---- 9. Required files exist ----
Write-Host ""
Write-Host "--- File Existence Checks ---" -ForegroundColor Cyan

$requiredFiles = @(
    "CMakeLists.txt",
    "CMakePresets.json",
    "vcpkg.json",
    "LICENSE.md",
    "include/AeostaraCore/IHealingEngine.h",
    "include/AeostaraCore/IConfigAdapter.h",
    "include/AeostaraCore/IBackupProvider.h",
    "include/AeostaraCore/IAuditSink.h",
    "include/AeostaraCore/IFileSystem.h",
    "include/AeostaraCore/HealingEngine.h",
    "include/AeostaraCore/Contracts.h",
    "src/AeostaraCore/CMakeLists.txt",
    "src/AeostaraCLI/CMakeLists.txt",
    "src/AeostaraCLI/Main.cpp",
    "tests/CMakeLists.txt"
)

foreach ($file in $requiredFiles) {
    $fullPath = Join-Path $SourceDir $file
    Write-Check "Exists: $file" (Test-Path $fullPath)
}

# ---- Summary ----
Write-Host ""
if ($exitCode -eq 0) {
    Write-Host "=== ALL GUARDRAILS PASSED ===" -ForegroundColor Green
} else {
    Write-Host "=== GUARDRAIL FAILURES DETECTED ===" -ForegroundColor Red
}

exit $exitCode
