$ErrorActionPreference = "Stop"

Write-Host "=== OfficeBridge v1.0 safe fix ===" -ForegroundColor Cyan

$Root = Get-Location
$DesktopProject = Join-Path $Root "OfficeBridge.Desktop"
$TemplatesDir = Join-Path $Root "Templates"
$AssetsDir = Join-Path $DesktopProject "Assets"

if (!(Test-Path $DesktopProject)) {
    throw "OfficeBridge.Desktop folder not found. Run this script from OfficeBridge solution root."
}

# Hebrew strings via Unicode, to avoid encoding corruption
$HebProductName = -join ([char[]](0x05E9,0x05DD,0x0020,0x05D4,0x05DE,0x05D5,0x05E6,0x05E8)) # שם המוצר
$HebTitleOld    = -join ([char[]](0x05DB,0x05D5,0x05EA,0x05E8,0x05EA)) # כותרת
$HebProject     = -join ([char[]](0x05DE,0x05E1,0x05E4,0x05E8,0x0020,0x05E4,0x05E8,0x05D5,0x05D9,0x05E7,0x05D8)) # מספר פרויקט
$HebPart        = -join ([char[]](0x05DE,0x05E1,0x05E4,0x05E8,0x0020,0x05E4,0x05E8,0x05D9,0x05D8)) # מספר פריט
$HebRevision    = -join ([char[]](0x05DE,0x05D4,0x05D3,0x05D5,0x05E8,0x05D4)) # מהדורה
$HebAddReq      = -join ([char[]](0x05D3,0x05E8,0x05D9,0x05E9,0x05D5,0x05EA,0x0020,0x05E0,0x05D5,0x05E1,0x05E4,0x05D5,0x05EA)) # דרישות נוספות

# ------------------------------------------------------------
# Backup
# ------------------------------------------------------------

$BackupDir = Join-Path $Root ("_backup_v1_fix_" + (Get-Date -Format "yyyyMMdd_HHmmss"))
New-Item -ItemType Directory -Path $BackupDir -Force | Out-Null

$FilesToBackup = @(
    "OfficeBridge.Desktop\MainWindow.xaml",
    "OfficeBridge.Desktop\MainWindow.xaml.cs",
    "OfficeBridge.Desktop\OfficeBridge.Desktop.csproj",
    "build-release.ps1"
)

foreach ($file in $FilesToBackup) {
    $src = Join-Path $Root $file
    if (Test-Path $src) {
        $dst = Join-Path $BackupDir $file
        New-Item -ItemType Directory -Path (Split-Path $dst) -Force | Out-Null
        Copy-Item $src $dst -Force
    }
}

Write-Host "Backup created: $BackupDir" -ForegroundColor DarkGray

# ------------------------------------------------------------
# Templates folder
# ------------------------------------------------------------

Write-Host "Ensuring Templates folder..." -ForegroundColor Yellow

New-Item -ItemType Directory -Path $TemplatesDir -Force | Out-Null

$templatePatterns = @("*.docx", "*.dotx", "*.xlsx", "*.xlsm")

foreach ($pattern in $templatePatterns) {
    Get-ChildItem -Path $Root -Filter $pattern -File -ErrorAction SilentlyContinue |
        Where-Object {
            $_.DirectoryName -eq $Root.Path -and
            $_.FullName -notlike "*\bin\*" -and
            $_.FullName -notlike "*\obj\*"
        } |
        ForEach-Object {
            $target = Join-Path $TemplatesDir $_.Name
            Write-Host "Moving template: $($_.Name) -> Templates" -ForegroundColor DarkYellow
            Move-Item $_.FullName $target -Force
        }
}

# ------------------------------------------------------------
# Icon
# ------------------------------------------------------------

Write-Host "Ensuring app icon..." -ForegroundColor Yellow

New-Item -ItemType Directory -Path $AssetsDir -Force | Out-Null
$IconPath = Join-Path $AssetsDir "OfficeBridge.ico"

if (!(Test-Path $IconPath)) {
    Add-Type -AssemblyName System.Drawing

    $bmp = New-Object System.Drawing.Bitmap 256, 256
    $g = [System.Drawing.Graphics]::FromImage($bmp)
    $g.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias

    $rect = New-Object System.Drawing.Rectangle 0, 0, 256, 256
    $bg = New-Object System.Drawing.Drawing2D.LinearGradientBrush(
        $rect,
        [System.Drawing.Color]::FromArgb(18, 32, 48),
        [System.Drawing.Color]::FromArgb(0, 170, 220),
        45
    )

    $g.FillRectangle($bg, $rect)

    $font = New-Object System.Drawing.Font("Segoe UI", 82, [System.Drawing.FontStyle]::Bold)
    $brush = New-Object System.Drawing.SolidBrush([System.Drawing.Color]::White)
    $format = New-Object System.Drawing.StringFormat
    $format.Alignment = [System.Drawing.StringAlignment]::Center
    $format.LineAlignment = [System.Drawing.StringAlignment]::Center

    $g.DrawString("OB", $font, $brush, (New-Object System.Drawing.RectangleF 0, 0, 256, 256), $format)

    $hIcon = $bmp.GetHicon()
    $icon = [System.Drawing.Icon]::FromHandle($hIcon)

    $fs = New-Object System.IO.FileStream($IconPath, [System.IO.FileMode]::Create)
    $icon.Save($fs)
    $fs.Close()

    $g.Dispose()
    $bmp.Dispose()

    Write-Host "Icon created: $IconPath" -ForegroundColor Green
}

# ------------------------------------------------------------
# Patch csproj
# ------------------------------------------------------------

$Csproj = Join-Path $DesktopProject "OfficeBridge.Desktop.csproj"

if (Test-Path $Csproj) {
    Write-Host "Patching csproj..." -ForegroundColor Yellow

    $csprojText = Get-Content $Csproj -Raw -Encoding UTF8

    if ($csprojText -notmatch "<ApplicationIcon>") {
        $csprojText = $csprojText -replace "</PropertyGroup>", "  <ApplicationIcon>Assets\OfficeBridge.ico</ApplicationIcon>`r`n  </PropertyGroup>"
    }
    else {
        $csprojText = $csprojText -replace "<ApplicationIcon>.*?</ApplicationIcon>", "<ApplicationIcon>Assets\OfficeBridge.ico</ApplicationIcon>"
    }

    if ($csprojText -notmatch "\.\.\\Templates\\\*\*\\\*") {
        $insert = @"

  <ItemGroup>
    <Resource Include="Assets\OfficeBridge.ico" />
    <Content Include="..\Templates\**\*">
      <Link>Templates\%(RecursiveDir)%(Filename)%(Extension)</Link>
      <CopyToOutputDirectory>PreserveNewest</CopyToOutputDirectory>
    </Content>
  </ItemGroup>
"@

        $csprojText = $csprojText -replace "</Project>", "$insert`r`n</Project>"
    }

    Set-Content -Path $Csproj -Value $csprojText -Encoding UTF8
}

# ------------------------------------------------------------
# Patch XAML
# ------------------------------------------------------------

$Xaml = Join-Path $DesktopProject "MainWindow.xaml"

if (Test-Path $Xaml) {
    Write-Host "Patching MainWindow.xaml..." -ForegroundColor Yellow

    $xamlText = Get-Content $Xaml -Raw -Encoding UTF8

    # TITLE / Hebrew title -> Product Name Hebrew
    $xamlText = $xamlText.Replace("TITLE ($HebTitleOld)", $HebProductName)
    $xamlText = $xamlText.Replace("Title ($HebTitleOld)", $HebProductName)
    $xamlText = $xamlText.Replace($HebTitleOld, $HebProductName)

    # Add window icon
    if ($xamlText -match "<Window\b" -and $xamlText -notmatch "Icon=""Assets/OfficeBridge.ico""") {
        $xamlText = $xamlText -replace "<Window\b", "<Window Icon=""Assets/OfficeBridge.ico"""
    }

    # Safer English labels
    $xamlText = $xamlText -replace "Project\s*Number", "Project Number / $HebProject"
    $xamlText = $xamlText -replace "Part\s*Number", "Part Number / $HebPart"
    $xamlText = $xamlText -replace "Revision", "Revision / $HebRevision"

    # Try to give the checkbox a stable name
    if ($xamlText -match "<CheckBox[^>]*Additional requirements[^>]*>" -and $xamlText -notmatch "x:Name=""AdditionalRequirementsCheckBox""") {
        $xamlText = $xamlText -replace "(<CheckBox)", '$1 x:Name="AdditionalRequirementsCheckBox"'
    }

    # Add textbox for additional requirements
    if ($xamlText -notmatch "AdditionalRequirementsTextBox") {
        $insertBlock = @"

<TextBlock Text="Additional requirements / $HebAddReq"
           Margin="0,8,0,4"
           Visibility="{Binding IsChecked, ElementName=AdditionalRequirementsCheckBox, Converter={StaticResource BooleanToVisibilityConverter}}" />

<TextBox x:Name="AdditionalRequirementsTextBox"
         MinHeight="80"
         TextWrapping="Wrap"
         AcceptsReturn="True"
         VerticalScrollBarVisibility="Auto"
         Margin="0,0,0,8"
         Visibility="{Binding IsChecked, ElementName=AdditionalRequirementsCheckBox, Converter={StaticResource BooleanToVisibilityConverter}}" />
"@

        if ($xamlText -match "x:Name=""AdditionalRequirementsCheckBox""") {
            $xamlText = $xamlText -replace "(<CheckBox[^>]*x:Name=""AdditionalRequirementsCheckBox""[^>]*/>)", "`$1`r`n$insertBlock"
        }
        else {
            Write-Host "WARNING: AdditionalRequirementsCheckBox not found. TextBox was not inserted." -ForegroundColor Red
        }
    }

    # Add converter resource
    if ($xamlText -match "BooleanToVisibilityConverter" -and $xamlText -notmatch 'x:Key="BooleanToVisibilityConverter"') {
        if ($xamlText -match "<Window.Resources>") {
            $xamlText = $xamlText -replace "<Window.Resources>", "<Window.Resources>`r`n        <BooleanToVisibilityConverter x:Key=""BooleanToVisibilityConverter"" />"
        }
        else {
            $xamlText = $xamlText -replace "(<Window[^>]*>)", "`$1`r`n    <Window.Resources>`r`n        <BooleanToVisibilityConverter x:Key=""BooleanToVisibilityConverter"" />`r`n    </Window.Resources>"
        }
    }

    Set-Content -Path $Xaml -Value $xamlText -Encoding UTF8
}

# ------------------------------------------------------------
# Patch code-behind lightly
# ------------------------------------------------------------

$CodeBehind = Join-Path $DesktopProject "MainWindow.xaml.cs"

if (Test-Path $CodeBehind) {
    Write-Host "Checking code-behind..." -ForegroundColor Yellow

    $cs = Get-Content $CodeBehind -Raw -Encoding UTF8
    $cs = $cs.Replace("TITLE", "ProductName")
    $cs = $cs.Replace($HebTitleOld, $HebProductName)

    Set-Content -Path $CodeBehind -Value $cs -Encoding UTF8
}

# ------------------------------------------------------------
# Patch build-release.ps1
# ------------------------------------------------------------

$BuildScript = Join-Path $Root "build-release.ps1"

if (Test-Path $BuildScript) {
    Write-Host "Patching build-release.ps1..." -ForegroundColor Yellow

    $build = Get-Content $BuildScript -Raw -Encoding UTF8

    if ($build -notmatch "TemplatesSource") {
        $append = @'

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
'@

        Add-Content -Path $BuildScript -Value $append -Encoding UTF8
    }
}

# ------------------------------------------------------------
# Build
# ------------------------------------------------------------

Write-Host "Running dotnet build..." -ForegroundColor Cyan
dotnet build

Write-Host ""
Write-Host "=== DONE ===" -ForegroundColor Green
Write-Host "Now check: Product Name Hebrew label, Project Number first, Additional Requirements textbox, icon, Templates folder." -ForegroundColor Green