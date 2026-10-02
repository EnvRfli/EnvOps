<#
.SYNOPSIS
    EnvOps Ultra-Slim Production APK Build Script (ARM64-v8a)

.DESCRIPTION
    Builds a highly optimized, minimal-size Release APK for modern physical Android devices.
    
    Optimizations applied:
    1. Single Architecture Target: android-arm64 (arm64-v8a)
       - Eliminates 32-bit ARM (armeabi-v7a) and x86/x86_64 emulator binaries.
       - Reduces raw download/install size by ~55%.
    2. Code Obfuscation: --obfuscate
       - Strips symbol names, obfuscates Dart class and method identifiers.
    3. Debug Symbol Stripping: --split-debug-info=build/app/outputs/symbols
       - Extracts heavy debugging symbols from the APK binary into an external folder.
    4. Optional Tree-Shaking: Allows toggling between icon tree shaking or --no-tree-shake-icons.

.PARAMETER NoTreeShake
    Disable icon font tree shaking (--no-tree-shake-icons) if custom icon fonts encounter build issues.

.PARAMETER SkipTests
    Skip running 'flutter test' and 'flutter analyze' prior to building.

.EXAMPLE
    # Standard ultra-slim arm64 release build:
    .\scripts\build_release_arm64.ps1

.EXAMPLE
    # Build with --no-tree-shake-icons:
    .\scripts\build_release_arm64.ps1 -NoTreeShake

.NOTES
    Target Audience: Developers and AI Coding Agents (Antigravity, Cursor, Claude Code, Copilot).
    When an AI agent is tagged with this file, the agent should execute this script to build the release APK.
#>

[CmdletBinding()]
param(
    [switch]$NoTreeShake = $false,
    [switch]$SkipTests = $false
)

$ErrorActionPreference = "Stop"
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$ProjectRoot = Split-Path -Parent $ScriptDir
Set-Location $ProjectRoot

Write-Host "==========================================================" -ForegroundColor Cyan
Write-Host "  EnvOps — Ultra-Slim ARM64 Release Build Pipeline" -ForegroundColor White
Write-Host "==========================================================" -ForegroundColor Cyan
Write-Host "Project Root : $ProjectRoot"
Write-Host "Architecture : android-arm64 (64-bit physical mobile devices)"

# 1. Pre-flight Quality Checks
if (-not $SkipTests) {
    Write-Host "`n[1/4] Running Static Analysis (flutter analyze)..." -ForegroundColor Yellow
    flutter analyze
    if ($LASTEXITCODE -ne 0) {
        Write-Error "flutter analyze reported issues. Build aborted."
        exit 1
    }
    Write-Host "Static analysis passed with 0 issues." -ForegroundColor Green

    Write-Host "`n[2/4] Running Automated Tests (flutter test)..." -ForegroundColor Yellow
    flutter test
    if ($LASTEXITCODE -ne 0) {
        Write-Error "Automated test suite failed. Build aborted."
        exit 1
    }
    Write-Host "All automated tests passed successfully." -ForegroundColor Green
} else {
    Write-Host "`n[1/4 & 2/4] Pre-flight tests skipped via -SkipTests flag." -ForegroundColor DarkGray
}

# 2. Build Arguments Setup
$SymbolsDir = Join-Path $ProjectRoot "build\app\outputs\symbols"
if (-not (Test-Path $SymbolsDir)) {
    New-Item -ItemType Directory -Path $SymbolsDir -Force | Out-Null
}

$BuildArgs = @(
    "build", "apk", "--release",
    "--target-platform", "android-arm64",
    "--obfuscate",
    "--split-debug-info=$SymbolsDir"
)

if ($NoTreeShake) {
    Write-Host "Icon tree shaking disabled (--no-tree-shake-icons)." -ForegroundColor DarkYellow
    $BuildArgs += "--no-tree-shake-icons"
} else {
    Write-Host "Icon font tree-shaking active for maximum size reduction." -ForegroundColor DarkCyan
}

# 3. Execute Build
Write-Host "`n[3/4] Compiling Optimized ARM64 APK with Flutter..." -ForegroundColor Yellow
Write-Host "Command: flutter $($BuildArgs -join ' ')" -ForegroundColor DarkGray

$Stopwatch = [System.Diagnostics.Stopwatch]::StartNew()
& flutter $BuildArgs
if ($LASTEXITCODE -ne 0) {
    Write-Error "Flutter build failed with exit code $LASTEXITCODE."
    exit $LASTEXITCODE
}
$Stopwatch.Stop()

# 4. Result & APK Size Inspection
Write-Host "`n[4/4] Verifying Generated APK..." -ForegroundColor Yellow

$ApkPath = Join-Path $ProjectRoot "build\app\outputs\flutter-apk\app-release.apk"
if (-not (Test-Path $ApkPath)) {
    # Check arm64 specific name if generated
    $Arm64Apk = Join-Path $ProjectRoot "build\app\outputs\flutter-apk\app-arm64-v8a-release.apk"
    if (Test-Path $Arm64Apk) {
        $ApkPath = $Arm64Apk
    }
}

if (Test-Path $ApkPath) {
    $ApkItem = Get-Item $ApkPath
    $SizeBytes = $ApkItem.Length
    $SizeMB = [math]::Round($SizeBytes / 1MB, 2)

    Write-Host "==========================================================" -ForegroundColor Green
    Write-Host "  BUILD SUCCESSFUL!" -ForegroundColor Green
    Write-Host "==========================================================" -ForegroundColor Green
    Write-Host "APK Location : $($ApkItem.FullName)" -ForegroundColor White
    Write-Host "APK Size     : $SizeMB MB ($SizeBytes bytes)" -ForegroundColor Cyan
    Write-Host "Build Time   : $([math]::Round($Stopwatch.Elapsed.TotalSeconds, 1)) seconds"
    Write-Host "Target ABI   : ARM64-v8a (Clean, single-arch standalone)"
    Write-Host "Debug Symbols: $SymbolsDir"
    Write-Host "`nInstall to your connected Android phone using ADB:" -ForegroundColor Yellow
    Write-Host "  adb install -r `"$($ApkItem.FullName)`"" -ForegroundColor White
    Write-Host "==========================================================" -ForegroundColor Green
} else {
    Write-Warning "Build finished, but could not locate the APK output at $ApkPath."
}
