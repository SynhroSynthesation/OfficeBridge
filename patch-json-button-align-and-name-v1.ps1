$ErrorActionPreference = "Stop"

Write-Host "=== OfficeBridge v1.0 JSON button align + filename patch ===" -ForegroundColor Cyan

$Root = Get-Location
$DesktopProject = Join-Path $Root "OfficeBridge.Desktop"
$XamlPath = Join-Path $DesktopProject "MainWindow.xaml"
$CodePath = Join-Path $DesktopProject "MainWindow.xaml.cs"

if (!(Test-Path $XamlPath)) {
    throw "MainWindow.xaml not found: $XamlPath"
}

if (!(Test-Path $CodePath)) {
    throw "MainWindow.xaml.cs not found: $CodePath"
}

# Backup
$BackupDir = Join-Path $Root ("_backup_json_button_filename_v1_" + (Get-Date -Format "yyyyMMdd_HHmmss"))
New-Item -ItemType Directory -Path $BackupDir -Force | Out-Null
Copy-Item $XamlPath (Join-Path $BackupDir "MainWindow.xaml") -Force
Copy-Item $CodePath (Join-Path $BackupDir "MainWindow.xaml.cs") -Force

Write-Host "Backup created: $BackupDir" -ForegroundColor DarkGray

# ------------------------------------------------------------
# 1. Fix XAML button alignment
# ------------------------------------------------------------

Write-Host "Patching button alignment..." -ForegroundColor Yellow

$x = Get-Content $XamlPath -Raw -Encoding UTF8

# Убираем вертикальный отступ у кнопки Save JSON to Archive
$x = $x -replace '(<Button\s+x:Name="SaveJsonToArchiveButton"[\s\S]*?)Margin="[^"]*"', '$1Margin="8,0,0,0"'

# Добавляем выравнивание по центру, если его нет
if ($x -match 'x:Name="SaveJsonToArchiveButton"' -and $x -notmatch 'x:Name="SaveJsonToArchiveButton"[\s\S]*?VerticalAlignment=') {
    $x = $x -replace '(<Button\s+x:Name="SaveJsonToArchiveButton"[\s\S]*?Margin="8,0,0,0")', '$1 VerticalAlignment="Center"'
}

# Добавляем минимальную ширину, чтобы кнопка выглядела аккуратно
if ($x -match 'x:Name="SaveJsonToArchiveButton"' -and $x -notmatch 'x:Name="SaveJsonToArchiveButton"[\s\S]*?MinWidth=') {
    $x = $x -replace '(<Button\s+x:Name="SaveJsonToArchiveButton"[\s\S]*?Content="Save JSON to Archive")', '$1 MinWidth="170"'
}

Set-Content $XamlPath -Value $x -Encoding UTF8

# ------------------------------------------------------------
# 2. Fix JSON filename and archive folder
# ------------------------------------------------------------

Write-Host "Patching JSON filename logic..." -ForegroundColor Yellow

$cs = Get-Content $CodePath -Raw -Encoding UTF8

# Заменяем папку сохранения: берём ArchiveFolderTextBox, если он есть
$cs = [regex]::Replace(
    $cs,
    'var archiveDir = System\.IO\.Path\.Combine\(AppContext\.BaseDirectory, "Archive", "Json"\);\s*System\.IO\.Directory\.CreateDirectory\(archiveDir\);',
    'var archiveDir = GetJsonArchiveFolder();' + "`r`n        System.IO.Directory.CreateDirectory(archiveDir);",
    1
)

# Заменяем имя файла
$cs = [regex]::Replace(
    $cs,
    'var fileName = \$"OfficeBridge_\{DateTime\.Now:yyyyMMdd_HHmmss\}\.json";',
    'var fileName = BuildJsonArchiveFileName();',
    1
)

# Добавляем helper-методы перед концом класса, если их ещё нет
if ($cs -notmatch 'private string BuildJsonArchiveFileName\(\)') {
    $helper = @'

private string BuildJsonArchiveFileName()
{
    var projectNumber = MakeSafeFileNamePart(GetTextBoxValue("ProjectNumberTextBox"));
    var productName = MakeSafeFileNamePart(GetTextBoxValue("TitleTextBox"));
    var date = DateTime.Now.ToString("yyyyMMdd_HHmmss");

    if (string.IsNullOrWhiteSpace(projectNumber))
    {
        projectNumber = "NoProject";
    }

    if (string.IsNullOrWhiteSpace(productName))
    {
        productName = "NoProduct";
    }

    return $"{projectNumber}_{productName}_{date}.json";
}

private string GetJsonArchiveFolder()
{
    if (FindName("ArchiveFolderTextBox") is System.Windows.Controls.TextBox archiveFolderTextBox)
    {
        var archivePath = archiveFolderTextBox.Text?.Trim();

        if (!string.IsNullOrWhiteSpace(archivePath))
        {
            return archivePath;
        }
    }

    return System.IO.Path.Combine(AppContext.BaseDirectory, "Archive");
}

private string MakeSafeFileNamePart(string value)
{
    if (string.IsNullOrWhiteSpace(value))
    {
        return string.Empty;
    }

    var invalidChars = System.IO.Path.GetInvalidFileNameChars();
    var safe = new string(value.Trim()
        .Select(ch => invalidChars.Contains(ch) ? '_' : ch)
        .ToArray());

    safe = safe.Replace(" ", "_");

    while (safe.Contains("__"))
    {
        safe = safe.Replace("__", "_");
    }

    return safe.Trim('_');
}
'@

    $lastBraceIndex = $cs.LastIndexOf("}")
    if ($lastBraceIndex -lt 0) {
        throw "Cannot find final closing brace in MainWindow.xaml.cs"
    }

    $cs = $cs.Insert($lastBraceIndex, "`r`n$helper`r`n")
}

Set-Content $CodePath -Value $cs -Encoding UTF8

# ------------------------------------------------------------
# Build
# ------------------------------------------------------------

Write-Host "Running dotnet build..." -ForegroundColor Cyan
dotnet build

Write-Host ""
Write-Host "=== DONE ===" -ForegroundColor Green
Write-Host "Expected JSON filename: ProjectNumber_ProductName_yyyyMMdd_HHmmss.json" -ForegroundColor Green
Write-Host "Expected save folder: value from Archive Folder field." -ForegroundColor Green