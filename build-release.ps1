$ErrorActionPreference = "Stop"

$ProjectName = "OfficeBridge"
$DesktopProject = "OfficeBridge.Desktop"
$Configuration = "Release"
$Runtime = "win-x64"

$Root = Split-Path -Parent $MyInvocation.MyCommand.Path
$ReleaseRoot = Join-Path $Root "release"
$PublishDir = Join-Path $ReleaseRoot "publish"
$PackageDir = Join-Path $ReleaseRoot "OfficeBridge_Release_v1.0"
$ZipPath = Join-Path $ReleaseRoot "OfficeBridge_Release_v1.0.zip"

$DesktopCsproj = Join-Path $Root "$DesktopProject\$DesktopProject.csproj"

Write-Host "=== OfficeBridge Release Builder ===" -ForegroundColor Cyan
Write-Host "Root: $Root"
Write-Host "Project: $DesktopCsproj"

if (!(Test-Path $DesktopCsproj)) {
    throw "Desktop project not found: $DesktopCsproj"
}

if (Test-Path $ReleaseRoot) {
    Remove-Item $ReleaseRoot -Recurse -Force
}

New-Item -ItemType Directory -Path $ReleaseRoot -Force | Out-Null
New-Item -ItemType Directory -Path $PublishDir -Force | Out-Null
New-Item -ItemType Directory -Path $PackageDir -Force | Out-Null

Write-Host ""
Write-Host "[1/7] Restore..." -ForegroundColor Yellow
dotnet restore $DesktopCsproj

Write-Host ""
Write-Host "[2/7] Publish..." -ForegroundColor Yellow
dotnet publish $DesktopCsproj `
    -c $Configuration `
    -r $Runtime `
    --self-contained true `
    -p:PublishSingleFile=false `
    -p:IncludeNativeLibrariesForSelfExtract=true `
    -o $PublishDir

Write-Host ""
Write-Host "[3/7] Copy published files..." -ForegroundColor Yellow
Copy-Item -Path (Join-Path $PublishDir "*") -Destination $PackageDir -Recurse -Force

$TemplatesDir = Join-Path $PackageDir "Templates"
$DataDir = Join-Path $PackageDir "Data"
$OutputDir = Join-Path $PackageDir "Output"
$LogsDir = Join-Path $PackageDir "Logs"
$DocsDir = Join-Path $PackageDir "Docs"

New-Item -ItemType Directory -Path $TemplatesDir -Force | Out-Null
New-Item -ItemType Directory -Path $DataDir -Force | Out-Null
New-Item -ItemType Directory -Path $OutputDir -Force | Out-Null
New-Item -ItemType Directory -Path $LogsDir -Force | Out-Null
New-Item -ItemType Directory -Path $DocsDir -Force | Out-Null

Write-Host ""
Write-Host "[4/7] Copy templates and data..." -ForegroundColor Yellow

$TemplateSources = @(
    (Join-Path $Root "Templates"),
    (Join-Path $Root "OfficeBridge.App\Templates"),
    (Join-Path $Root "OfficeBridge.Desktop\Templates")
)

foreach ($src in $TemplateSources) {
    if (Test-Path $src) {
        Copy-Item -Path (Join-Path $src "*") -Destination $TemplatesDir -Recurse -Force -ErrorAction SilentlyContinue
    }
}

$DataSources = @(
    (Join-Path $Root "Data"),
    (Join-Path $Root "OfficeBridge.App\Data"),
    (Join-Path $Root "OfficeBridge.Desktop\Data")
)

foreach ($src in $DataSources) {
    if (Test-Path $src) {
        Copy-Item -Path (Join-Path $src "*") -Destination $DataDir -Recurse -Force -ErrorAction SilentlyContinue
    }
}

Write-Host ""
Write-Host "[5/7] Create demo JSON if missing..." -ForegroundColor Yellow

$SampleJson = Join-Path $DataDir "tagprocess.sample.json"

if (!(Test-Path $SampleJson)) {
@'
{
  "ProjectName": "TAG Process",
  "PartNumber": "PN-001",
  "SerialNumber": "SN-0001",
  "Revision": "A",
  "UnitsToProduce": 50,
  "ProjectManager": "Yuri",
  "ClosureType": "Full",
  "MechanicalDrawing": true,
  "ElectricalDrawing": true,
  "Specification": true,
  "CableCrimpForceCheck": true,
  "FAI": false,
  "InspectorRequirement": true,
  "AutomaticCheck": false,
  "AdditionalRequirements": "No additional requirements"
}
'@ | Set-Content -Path $SampleJson -Encoding UTF8
}

Write-Host ""
Write-Host "[6/7] Create readme files..." -ForegroundColor Yellow

$StartBat = Join-Path $PackageDir "start_OfficeBridge.bat"

@'
@echo off
chcp 65001 > nul
cd /d "%~dp0"
start "" "OfficeBridge.Desktop.exe"
'@ | Set-Content -Path $StartBat -Encoding ASCII

$InstallReadme = Join-Path $DocsDir "INSTALL.txt"

@'
OFFICEBRIDGE - INSTALLATION

1. Extract OfficeBridge_Release_v1.0.zip to a local folder.
   Example:
   C:\OfficeBridge\

2. Do not run the program directly from ZIP.

3. Start the program:
   - OfficeBridge.Desktop.exe
   or
   - start_OfficeBridge.bat

4. Required system:
   - Windows 10 or Windows 11 x64
   - Screen resolution 1024x768 or higher

5. This release is self-contained.
   .NET Runtime installation is not required.

6. For PDF export install LibreOffice.
   Default path:
   C:\Program Files\LibreOffice\program\soffice.exe
'@ | Set-Content -Path $InstallReadme -Encoding UTF8

$UsageReadme = Join-Path $DocsDir "USAGE.txt"

@'
OFFICEBRIDGE - USER MANUAL

Main workflow:

1. Start OfficeBridge.
2. Select DOCX template from Templates folder.
3. Load JSON file from Data folder.
4. Check loaded data in the program window.
5. Select output folder.
6. Generate document.
7. Check generated DOCX in Output folder.
8. Export PDF if needed.

Folders:

Templates
- DOCX templates.

Data
- JSON input files.

Output
- Generated documents.

Logs
- Program logs.

Recommended flow:

1. Copy sample JSON.
2. Rename it for a real project.
3. Fill project data.
4. Load JSON in OfficeBridge.
5. Generate test document.
6. Check result manually.
7. Use the document as production output.
'@ | Set-Content -Path $UsageReadme -Encoding UTF8

$JsonReadme = Join-Path $DocsDir "JSON_GUIDE.txt"

@'
OFFICEBRIDGE - JSON LOADING ALGORITHM

1. User clicks Load JSON.
2. Program opens file selection dialog.
3. User selects .json file.
4. Program checks that file exists.
5. Program reads file as UTF-8.
6. Program parses JSON.
7. Program validates required fields.
8. Program displays data in UI.
9. User clicks Generate.
10. Program sends data to DOCX template engine.
11. Template engine replaces tags in DOCX.
12. Generated DOCX is saved to Output folder.
13. PDF is created if export is enabled.

Recommended required fields:

ProjectName
PartNumber
Revision
ProjectManager
UnitsToProduce

Example JSON:

{
  "ProjectName": "TAG Process",
  "PartNumber": "PN-001",
  "SerialNumber": "SN-0001",
  "Revision": "A",
  "UnitsToProduce": 50,
  "ProjectManager": "Yuri",
  "ClosureType": "Full",
  "MechanicalDrawing": true,
  "ElectricalDrawing": true,
  "Specification": true,
  "CableCrimpForceCheck": true,
  "FAI": false,
  "InspectorRequirement": true,
  "AutomaticCheck": false,
  "AdditionalRequirements": "No additional requirements"
}
'@ | Set-Content -Path $JsonReadme -Encoding UTF8

Write-Host ""
Write-Host "[7/7] Create ZIP..." -ForegroundColor Yellow

if (Test-Path $ZipPath) {
    Remove-Item $ZipPath -Force
}

Compress-Archive -Path (Join-Path $PackageDir "*") -DestinationPath $ZipPath -Force

Write-Host ""
Write-Host "DONE!" -ForegroundColor Green
Write-Host "Release folder:"
Write-Host $PackageDir
Write-Host ""
Write-Host "ZIP archive:"
Write-Host $ZipPath
# Copy Templates into release package
$TemplatesSource = Join-Path $PSScriptRoot "Templates"

if (Test-Path $TemplatesSource) {
    if ($ReleaseDir) {
        $TemplatesTarget = Join-Path $ReleaseDir "Templates"
    }
    else {
        $TemplatesTarget = Join-Path $PSScriptRoot "release\Templates"
    }

    New-Item -ItemType Directory -Path $TemplatesTarget -Force | Out-Null
    Copy-Item "$TemplatesSource\*" $TemplatesTarget -Recurse -Force
    Write-Host "Templates copied to release package." -ForegroundColor Green
}
else {
    Write-Host "WARNING: Templates folder not found." -ForegroundColor Yellow
}
