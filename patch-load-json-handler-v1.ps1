$ErrorActionPreference = "Stop"

Write-Host "=== OfficeBridge v1.0 Load JSON handler patch ===" -ForegroundColor Cyan

$Root = Get-Location
$CodePath = Join-Path $Root "OfficeBridge.Desktop\MainWindow.xaml.cs"

if (!(Test-Path $CodePath)) {
    throw "MainWindow.xaml.cs not found: $CodePath"
}

$BackupDir = Join-Path $Root ("_backup_load_json_handler_v1_" + (Get-Date -Format "yyyyMMdd_HHmmss"))
New-Item -ItemType Directory -Path $BackupDir -Force | Out-Null
Copy-Item $CodePath (Join-Path $BackupDir "MainWindow.xaml.cs") -Force

Write-Host "Backup created: $BackupDir" -ForegroundColor DarkGray

function Replace-CSharpMethod {
    param(
        [string]$Source,
        [string]$MethodName,
        [string]$Replacement
    )

    $methodIndex = $Source.IndexOf($MethodName)
    if ($methodIndex -lt 0) {
        throw "Method not found: $MethodName"
    }

    $openBraceIndex = $Source.IndexOf("{", $methodIndex)
    if ($openBraceIndex -lt 0) {
        throw "Opening brace not found for method: $MethodName"
    }

    $depth = 0
    $endIndex = -1

    for ($i = $openBraceIndex; $i -lt $Source.Length; $i++) {
        $ch = $Source[$i]

        if ($ch -eq "{") {
            $depth++
        }
        elseif ($ch -eq "}") {
            $depth--

            if ($depth -eq 0) {
                $endIndex = $i
                break
            }
        }
    }

    if ($endIndex -lt 0) {
        throw "Closing brace not found for method: $MethodName"
    }

    return $Source.Substring(0, $methodIndex) + $Replacement + $Source.Substring($endIndex + 1)
}

$cs = Get-Content $CodePath -Raw -Encoding UTF8

if ($cs -notmatch 'using System\.Text\.Json;') {
    $cs = "using System.Text.Json;`r`n" + $cs
}

$newLoadHandler = @'
private void LoadJsonButton_Click(object sender, RoutedEventArgs e)
{
    try
    {
        var jsonPath = JsonPathTextBox.Text?.Trim();

        if (string.IsNullOrWhiteSpace(jsonPath))
        {
            MessageBox.Show("JSON path is empty.", "Load JSON", MessageBoxButton.OK, MessageBoxImage.Warning);
            return;
        }

        if (!System.IO.File.Exists(jsonPath))
        {
            MessageBox.Show($"JSON file not found: {jsonPath}", "Load JSON", MessageBoxButton.OK, MessageBoxImage.Warning);
            return;
        }

        var json = System.IO.File.ReadAllText(jsonPath, System.Text.Encoding.UTF8);

        // Universal loader: supports archived JSON with ProductName and old sample JSON aliases.
        LoadJsonIntoCurrentUi(json);

        AppendLog($"JSON loaded: {jsonPath}");
    }
    catch (Exception ex)
    {
        AppendLog($"ERROR loading JSON: {ex.Message}");
        MessageBox.Show(ex.Message, "Load JSON", MessageBoxButton.OK, MessageBoxImage.Error);
    }
}
'@

$cs = Replace-CSharpMethod $cs "private void LoadJsonButton_Click" $newLoadHandler

Set-Content $CodePath -Value $cs -Encoding UTF8

Write-Host "Running dotnet build..." -ForegroundColor Cyan
dotnet build

Write-Host ""
Write-Host "=== DONE ===" -ForegroundColor Green
Write-Host "Load JSON now calls LoadJsonIntoCurrentUi(json)." -ForegroundColor Green