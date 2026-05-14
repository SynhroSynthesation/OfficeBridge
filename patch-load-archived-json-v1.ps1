$ErrorActionPreference = "Stop"

Write-Host "=== OfficeBridge v1.0 Load Archived JSON patch ===" -ForegroundColor Cyan

$Root = Get-Location
$CodePath = Join-Path $Root "OfficeBridge.Desktop\MainWindow.xaml.cs"

if (!(Test-Path $CodePath)) {
    throw "MainWindow.xaml.cs not found: $CodePath"
}

$BackupDir = Join-Path $Root ("_backup_load_archived_json_v1_" + (Get-Date -Format "yyyyMMdd_HHmmss"))
New-Item -ItemType Directory -Path $BackupDir -Force | Out-Null
Copy-Item $CodePath (Join-Path $BackupDir "MainWindow.xaml.cs") -Force

Write-Host "Backup created: $BackupDir" -ForegroundColor DarkGray

$cs = Get-Content $CodePath -Raw -Encoding UTF8

# Ensure using
if ($cs -notmatch 'using System\.Text\.Json;') {
    $cs = "using System.Text.Json;`r`n" + $cs
}

# Remove old load-json archive patch if exists
$cs = [regex]::Replace(
    $cs,
    '(?s)\s*// OFFICEBRIDGE_LOAD_ARCHIVED_JSON_PATCH_START.*?// OFFICEBRIDGE_LOAD_ARCHIVED_JSON_PATCH_END\s*',
    "`r`n"
)

# Replace existing LoadJsonButton_Click with robust universal loader
$loadHandlerPattern = '(?s)\s*private\s+void\s+LoadJsonButton_Click\s*\(\s*object\s+sender\s*,\s*System\.Windows\.RoutedEventArgs\s+e\s*\)\s*\{.*?\n\s*\}\s*(?=\n\s*(private|public|protected|internal)\s+)'

$loadHandlerReplacement = @'

private void LoadJsonButton_Click(object sender, System.Windows.RoutedEventArgs e)
{
    try
    {
        var jsonPath = GetTextBoxValueByName("JsonPathTextBox");

        if (string.IsNullOrWhiteSpace(jsonPath))
        {
            System.Windows.MessageBox.Show(
                "JSON path is empty.",
                "Load JSON",
                System.Windows.MessageBoxButton.OK,
                System.Windows.MessageBoxImage.Warning);
            return;
        }

        if (!System.IO.File.Exists(jsonPath))
        {
            System.Windows.MessageBox.Show(
                $"JSON file not found: {jsonPath}",
                "Load JSON",
                System.Windows.MessageBoxButton.OK,
                System.Windows.MessageBoxImage.Warning);
            return;
        }

        var json = System.IO.File.ReadAllText(jsonPath, System.Text.Encoding.UTF8);
        LoadJsonIntoCurrentUi(json);

        AppendLog($"JSON loaded: {jsonPath}");
    }
    catch (Exception ex)
    {
        AppendLog($"ERROR loading JSON: {ex.Message}");
        System.Windows.MessageBox.Show(
            ex.Message,
            "Load JSON",
            System.Windows.MessageBoxButton.OK,
            System.Windows.MessageBoxImage.Error);
    }
}

'@

$cs2 = [regex]::Replace($cs, $loadHandlerPattern, $loadHandlerReplacement, 1)

if ($cs2 -eq $cs) {
    Write-Host "WARNING: LoadJsonButton_Click was not replaced. A new handler may conflict if old handler exists." -ForegroundColor Yellow
}
else {
    $cs = $cs2
}

$patch = @'

// OFFICEBRIDGE_LOAD_ARCHIVED_JSON_PATCH_START
private void LoadJsonIntoCurrentUi(string json)
{
    using var document = JsonDocument.Parse(json);
    var root = document.RootElement;

    // New archive JSON format
    SetTextBoxValueIfJsonExists(root, "ProjectNumber", "ProjectNumberTextBox");
    SetTextBoxValueIfJsonExists(root, "ProductName", "TitleTextBox");
    SetTextBoxValueIfJsonExists(root, "SigmaPn", "SigmaPnTextBox");
    SetTextBoxValueIfJsonExists(root, "CustomerPn", "CustomerPnTextBox");
    SetTextBoxValueIfJsonExists(root, "SerialNumber", "SerialNumberTextBox");
    SetTextBoxValueIfJsonExists(root, "Revision", "RevisionTextBox");
    SetTextBoxValueIfJsonExists(root, "UnitsToProduce", "UnitsToProduceTextBox");
    SetTextBoxValueIfJsonExists(root, "ProductionQuantity", "ProductionQuantityTextBox");
    SetTextBoxValueIfJsonExists(root, "ProjectManager", "ProjectManagerTextBox");
    SetTextBoxValueIfJsonExists(root, "AdditionalRequirements", "AdditionalRequirementsTextBox");

    SetCheckBoxValueIfJsonExists(root, "MechanicalDrawing", "MechanicalDrawingCheckBox");
    SetCheckBoxValueIfJsonExists(root, "ElectricalDrawing", "ElectricalDrawingCheckBox");
    SetCheckBoxValueIfJsonExists(root, "Specification", "SpecificationCheckBox");
    SetCheckBoxValueIfJsonExists(root, "CableCrimpForceCheck", "CableCrimpForceCheckBox");
    SetCheckBoxValueIfJsonExists(root, "CableLugCrimpForceVerification", "CableCrimpForceCheckBox");
    SetCheckBoxValueIfJsonExists(root, "FAI", "FaiCheckBox");
    SetCheckBoxValueIfJsonExists(root, "InspectorRequirement", "InspectorRequirementCheckBox");
    SetCheckBoxValueIfJsonExists(root, "AutomaticCheck", "AutomaticCheckCheckBox");
    SetCheckBoxValueIfJsonExists(root, "AutomaticTest", "AutomaticCheckCheckBox");
    SetCheckBoxValueIfJsonExists(root, "AdditionalRequirementsEnabled", "AdditionalRequirementsCheckBox");

    // Old/sample JSON fallback: common alternative names
    SetTextBoxValueIfJsonExists(root, "Title", "TitleTextBox");
    SetTextBoxValueIfJsonExists(root, "Name", "TitleTextBox");
    SetTextBoxValueIfJsonExists(root, "Product", "TitleTextBox");
    SetTextBoxValueIfJsonExists(root, "PartNumber", "SigmaPnTextBox");
    SetTextBoxValueIfJsonExists(root, "SigmaPN", "SigmaPnTextBox");
    SetTextBoxValueIfJsonExists(root, "Serial", "SerialNumberTextBox");
    SetTextBoxValueIfJsonExists(root, "Quantity", "ProductionQuantityTextBox");
    SetTextBoxValueIfJsonExists(root, "Manager", "ProjectManagerTextBox");

    ApplyAdditionalRequirementsVisibility();
}

private void SetTextBoxValueIfJsonExists(JsonElement root, string jsonName, string controlName)
{
    if (!root.TryGetProperty(jsonName, out var value))
    {
        return;
    }

    if (FindName(controlName) is not System.Windows.Controls.TextBox textBox)
    {
        return;
    }

    textBox.Text = value.ValueKind switch
    {
        JsonValueKind.String => value.GetString() ?? string.Empty,
        JsonValueKind.Number => value.ToString(),
        JsonValueKind.True => "true",
        JsonValueKind.False => "false",
        _ => value.ToString()
    };
}

private void SetCheckBoxValueIfJsonExists(JsonElement root, string jsonName, string controlName)
{
    if (!root.TryGetProperty(jsonName, out var value))
    {
        return;
    }

    if (FindName(controlName) is not System.Windows.Controls.CheckBox checkBox)
    {
        return;
    }

    checkBox.IsChecked = value.ValueKind switch
    {
        JsonValueKind.True => true,
        JsonValueKind.False => false,
        JsonValueKind.String => bool.TryParse(value.GetString(), out var parsed) && parsed,
        JsonValueKind.Number => value.TryGetInt32(out var number) && number != 0,
        _ => false
    };
}

private string GetTextBoxValueByName(string controlName)
{
    if (FindName(controlName) is System.Windows.Controls.TextBox textBox)
    {
        return textBox.Text?.Trim() ?? string.Empty;
    }

    return string.Empty;
}

private void ApplyAdditionalRequirementsVisibility()
{
    if (FindName("AdditionalRequirementsCheckBox") is not System.Windows.Controls.CheckBox checkBox)
    {
        return;
    }

    if (FindName("AdditionalRequirementsTextBox") is System.Windows.Controls.TextBox textBox)
    {
        textBox.Visibility = checkBox.IsChecked == true
            ? System.Windows.Visibility.Visible
            : System.Windows.Visibility.Collapsed;
    }
}
// OFFICEBRIDGE_LOAD_ARCHIVED_JSON_PATCH_END
'@

$lastBraceIndex = $cs.LastIndexOf("}")
if ($lastBraceIndex -lt 0) {
    throw "Cannot find final closing brace in MainWindow.xaml.cs"
}

$cs = $cs.Insert($lastBraceIndex, "`r`n$patch`r`n")

Set-Content $CodePath -Value $cs -Encoding UTF8

Write-Host "Running dotnet build..." -ForegroundColor Cyan
dotnet build

Write-Host ""
Write-Host "=== DONE ===" -ForegroundColor Green
Write-Host "Load JSON now supports archived JSON fields: ProjectNumber, ProductName, SigmaPn, Revision, checkboxes." -ForegroundColor Green