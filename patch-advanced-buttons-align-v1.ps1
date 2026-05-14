$ErrorActionPreference = "Stop"

Write-Host "=== OfficeBridge v1.0 Advanced buttons alignment patch ===" -ForegroundColor Cyan

$Root = Get-Location
$XamlPath = Join-Path $Root "OfficeBridge.Desktop\MainWindow.xaml"

if (!(Test-Path $XamlPath)) {
    throw "MainWindow.xaml not found: $XamlPath"
}

$BackupDir = Join-Path $Root ("_backup_advanced_buttons_align_v1_" + (Get-Date -Format "yyyyMMdd_HHmmss"))
New-Item -ItemType Directory -Path $BackupDir -Force | Out-Null
Copy-Item $XamlPath (Join-Path $BackupDir "MainWindow.xaml") -Force

Write-Host "Backup created: $BackupDir" -ForegroundColor DarkGray

$x = Get-Content $XamlPath -Raw -Encoding UTF8

function Set-ButtonAttribute {
    param(
        [string]$Text,
        [string]$ButtonName,
        [string]$AttributeName,
        [string]$AttributeValue
    )

    $pattern = "(?s)(<Button\b[^>]*x:Name=`"$ButtonName`"[^>]*)(/?>)"
    return [regex]::Replace($Text, $pattern, {
        param($m)

        $tagStart = $m.Groups[1].Value
        $tagEnd = $m.Groups[2].Value

        $tagStart = [regex]::Replace(
            $tagStart,
            "\s+$AttributeName=`"[^`"]*`"",
            ""
        )

        return "$tagStart $AttributeName=`"$AttributeValue`"$tagEnd"
    }, 1)
}

# Одинаковая высота и вертикальное выравнивание
$buttonNames = @(
    "LoadJsonButton",
    "SaveJsonToArchiveButton",
    "OpenArchiveButton"
)

foreach ($name in $buttonNames) {
    $x = Set-ButtonAttribute $x $name "Height" "42"
    $x = Set-ButtonAttribute $x $name "MinWidth" "150"
    $x = Set-ButtonAttribute $x $name "VerticalAlignment" "Top"
    $x = Set-ButtonAttribute $x $name "Padding" "16,0"
}

# Индивидуальные отступы, чтобы все стояли ровно в одной линии
$x = Set-ButtonAttribute $x "LoadJsonButton" "Margin" "0,0,8,0"
$x = Set-ButtonAttribute $x "SaveJsonToArchiveButton" "Margin" "8,0,8,0"
$x = Set-ButtonAttribute $x "OpenArchiveButton" "Margin" "8,0,0,0"

# Если Save JSON попал в отдельный StackPanel с Margin сверху — убираем частый случай
$x = $x -replace '(<Button\s+x:Name="SaveJsonToArchiveButton"[\s\S]*?)Margin="[^"]*"', '$1Margin="8,0,8,0"'

Set-Content $XamlPath -Value $x -Encoding UTF8

Write-Host "Running dotnet build..." -ForegroundColor Cyan
dotnet build

Write-Host ""
Write-Host "=== DONE ===" -ForegroundColor Green
Write-Host "Advanced buttons should now have same Height=42 and top alignment." -ForegroundColor Green