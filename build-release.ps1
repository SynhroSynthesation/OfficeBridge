# build-release.ps1
# OfficeBridge release builder.
# Run from project root:
# powershell -ExecutionPolicy Bypass -File .\build-release.ps1

$ErrorActionPreference = "Stop"

$Root = "C:\SOFTWARE\Fast_Tag-process\OfficeBridge"
$DefaultTemplate = "C:\SOFTWARE\Fast_Tag-process\TAG-process_HARNESS.docx"

$Project = Join-Path $Root "OfficeBridge.Desktop\OfficeBridge.Desktop.csproj"
$Solution = Join-Path $Root "OfficeBridge.sln"
$ReleaseRoot = Join-Path $Root "Release"
$ReleaseDir = Join-Path $ReleaseRoot "OfficeBridge"
$PublishDir = Join-Path $Root "OfficeBridge.Desktop\bin\Release\net9.0-windows\win-x64\publish"


function Stop-OfficeBridgeProcess {
    $processes = Get-Process "OfficeBridge.Desktop" -ErrorAction SilentlyContinue

    if ($null -ne $processes) {
        Write-Host "Stopping running OfficeBridge.Desktop process..." -ForegroundColor DarkYellow
        $processes | Stop-Process -Force
        Start-Sleep -Milliseconds 700
    }
}

function Write-Step($Text) {
    Write-Host "`n[$Text]" -ForegroundColor Yellow
}

function Find-TemplateDocx {
    param(
        [string]$Root,
        [string]$DefaultTemplate
    )

    if (Test-Path $DefaultTemplate) {
        return $DefaultTemplate
    }

    $PreferredNames = @(
        "TAG-process_HARNESS.docx",
        "TAG-procees.docx",
        "TAG-procees(2).docx",
        "TAG-process.docx",
        "TAG-process(2).docx"
    )

    foreach ($name in $PreferredNames) {
        $path = Join-Path $Root $name
        if (Test-Path $path) {
            return $path
        }
    }

    $found = Get-ChildItem -Path $Root -Recurse -Filter "*.docx" -File |
        Where-Object {
            $_.FullName -notmatch "\\bin\\" -and
            $_.FullName -notmatch "\\obj\\" -and
            $_.FullName -notmatch "\\Release\\" -and
            $_.FullName -notmatch "\\Archive\\" -and
            $_.FullName -notmatch "\\Output\\" -and
            $_.Name -notmatch "^TAG_PR"
        } |
        Sort-Object FullName |
        Select-Object -First 1

    if ($null -ne $found) {
        return $found.FullName
    }

    return $null
}

Write-Host "=== OfficeBridge Release Builder ===" -ForegroundColor Cyan
Write-Host "Root: $Root"

if (!(Test-Path $Solution)) {
    throw "Solution file not found: $Solution"
}

if (!(Test-Path $Project)) {
    throw "Project file not found: $Project"
}

Stop-OfficeBridgeProcess

Write-Step "1/7 Cleaning old release"
if (Test-Path $ReleaseDir) {
    Remove-Item $ReleaseDir -Recurse -Force
}
New-Item -ItemType Directory -Path $ReleaseDir -Force | Out-Null

Write-Step "2/7 Restoring packages"
dotnet restore $Solution

Write-Step "3/7 Publishing Desktop app"
dotnet publish $Project `
    -c Release `
    -r win-x64 `
    --self-contained false `
    -p:PublishSingleFile=false `
    -p:IncludeNativeLibrariesForSelfExtract=true

if (!(Test-Path $PublishDir)) {
    throw "Publish directory not found: $PublishDir"
}

Write-Step "4/7 Copying publish output"
Copy-Item "$PublishDir\*" $ReleaseDir -Recurse -Force

Write-Step "5/7 Copying required folders and files"

# Copy Assets
$SourceAssets = Join-Path $Root "OfficeBridge.Desktop\Assets"
$ReleaseAssets = Join-Path $ReleaseDir "Assets"

if (Test-Path $SourceAssets) {
    New-Item -ItemType Directory -Path $ReleaseAssets -Force | Out-Null
    Copy-Item "$SourceAssets\*" $ReleaseAssets -Recurse -Force
    Write-Host "Copied: Assets"
}
else {
    Write-Host "Warning: Assets folder not found: $SourceAssets" -ForegroundColor DarkYellow
}

# Copy appsettings.json explicitly
$SourceAppSettings = Join-Path $Root "OfficeBridge.Desktop\appsettings.json"
if (Test-Path $SourceAppSettings) {
    Copy-Item $SourceAppSettings (Join-Path $ReleaseDir "appsettings.json") -Force
    Write-Host "Copied: appsettings.json"
}
else {
    Write-Host "Warning: appsettings.json not found." -ForegroundColor DarkYellow
}

# Copy correct DOCX template
$TemplatePath = Find-TemplateDocx -Root $Root -DefaultTemplate $DefaultTemplate

if ($null -ne $TemplatePath -and (Test-Path $TemplatePath)) {
    Copy-Item $TemplatePath (Join-Path $ReleaseDir "TAG-process_HARNESS.docx") -Force
    Copy-Item $TemplatePath (Join-Path $ReleaseDir "TAG-procees.docx") -Force
    Write-Host "Copied template: $TemplatePath"
}
else {
    Write-Host "Warning: DOCX template not found. Expected: $DefaultTemplate" -ForegroundColor DarkYellow
}

# Copy sample JSON
$SampleJson = Join-Path $Root "OfficeBridge.App\Data\tagprocess.sample.json"
if (Test-Path $SampleJson) {
    New-Item -ItemType Directory -Path (Join-Path $ReleaseDir "Data") -Force | Out-Null
    Copy-Item $SampleJson (Join-Path $ReleaseDir "Data\tagprocess.sample.json") -Force
    Write-Host "Copied: sample JSON"
}
else {
    Write-Host "Warning: sample JSON not found." -ForegroundColor DarkYellow
}

# Create Output and Archive folders
New-Item -ItemType Directory -Path (Join-Path $ReleaseDir "Output") -Force | Out-Null
New-Item -ItemType Directory -Path (Join-Path $ReleaseDir "Archive") -Force | Out-Null

Write-Step "6/7 Writing helper files"

$RunBat = @"
@echo off
cd /d "%~dp0"
start "" "OfficeBridge.Desktop.exe"
"@
Set-Content -Path (Join-Path $ReleaseDir "RUN_OfficeBridge.bat") -Value $RunBat -Encoding ASCII

$DebugBat = @"
@echo off
cd /d "%~dp0"
OfficeBridge.Desktop.exe
pause
"@
Set-Content -Path (Join-Path $ReleaseDir "RUN_DEBUG_OfficeBridge.bat") -Value $DebugBat -Encoding ASCII

$UserReadme = @"
OfficeBridge - User Instructions

Run:
RUN_OfficeBridge.bat

If the program does not start:
RUN_DEBUG_OfficeBridge.bat

Default template:
C:\SOFTWARE\Fast_Tag-process\TAG-process_HARNESS.docx

Release local fallback template:
TAG-process_HARNESS.docx

Output folder:
Output

Archive folder:
Archive

If PDF is not created, check LibreOffice path in appsettings.json:
C:\Program Files\LibreOffice\program\soffice.exe
"@
Set-Content -Path (Join-Path $ReleaseDir "README_FOR_USER.txt") -Value $UserReadme -Encoding UTF8

Write-Step "7/7 Validating release"

$ExePath = Join-Path $ReleaseDir "OfficeBridge.Desktop.exe"
$LogoPath = Join-Path $ReleaseDir "Assets\logo.png"
$SettingsPath = Join-Path $ReleaseDir "appsettings.json"
$TemplateReleasePath = Join-Path $ReleaseDir "TAG-process_HARNESS.docx"

Write-Host "Exe exists:       $(Test-Path $ExePath)"
Write-Host "Settings exists:  $(Test-Path $SettingsPath)"
Write-Host "Logo exists:      $(Test-Path $LogoPath)"
Write-Host "Template exists:  $(Test-Path $TemplateReleasePath)"

if (!(Test-Path $ExePath)) {
    throw "Release validation failed: EXE missing."
}

if (!(Test-Path $SettingsPath)) {
    throw "Release validation failed: appsettings.json missing."
}

if (!(Test-Path $LogoPath)) {
    throw "Release validation failed: Assets\logo.png missing."
}

if (!(Test-Path $TemplateReleasePath)) {
    Write-Host "Warning: release template missing. App can still run, but default template may be missing." -ForegroundColor DarkYellow
}

Write-Host "`nRelease folder ready:" -ForegroundColor Green
Write-Host $ReleaseDir -ForegroundColor Green

