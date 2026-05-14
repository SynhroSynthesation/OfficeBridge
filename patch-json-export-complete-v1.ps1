$ErrorActionPreference = "Stop"

Write-Host "=== OfficeBridge v1.0 complete JSON export patch ===" -ForegroundColor Cyan

$Root = Get-Location
$CodePath = Join-Path $Root "OfficeBridge.Desktop\MainWindow.xaml.cs"

if (!(Test-Path $CodePath)) {
    throw "MainWindow.xaml.cs not found: $CodePath"
}

$BackupDir = Join-Path $Root ("_backup_json_export_complete_v1_" + (Get-Date -Format "yyyyMMdd_HHmmss"))
New-Item -ItemType Directory -Path $BackupDir -Force | Out-Null
Copy-Item $CodePath (Join-Path $BackupDir "MainWindow.xaml.cs") -Force

Write-Host "Backup created: $BackupDir" -ForegroundColor DarkGray

$cs = Get-Content $CodePath -Raw -Encoding UTF8

# Replace BuildCurrentParametersJsonModel with a fuller and more tolerant version
$pattern = '(?s)private\s+Dictionary<string,\s*object\?>\s+BuildCurrentParametersJsonModel\s*\(\)\s*\{.*?\n\s*\}'

$replacement = @'
private Dictionary<string, object?> BuildCurrentParametersJsonModel()
{
    var result = new Dictionary<string, object?>
    {
        ["CreatedAt"] = DateTime.Now.ToString("yyyy-MM-dd HH:mm:ss"),

        ["ProjectNumber"] = GetTextBoxValueAny("ProjectNumberTextBox"),
        ["ProductName"] = GetTextBoxValueAny("TitleTextBox", "ProductNameTextBox"),
        ["SigmaPn"] = GetTextBoxValueAny("SigmaPnTextBox", "SigmaPNTextBox"),
        ["CustomerPn"] = GetTextBoxValueAny("CustomerPnTextBox", "CustomerPNTextBox"),
        ["SerialNumber"] = GetTextBoxValueAny("SerialNumberTextBox"),
        ["Revision"] = GetTextBoxValueAny("RevisionTextBox"),
        ["ProductionQuantity"] = GetTextBoxValueAny("ProductionQuantityTextBox", "UnitsToProduceTextBox"),
        ["ProjectManager"] = GetTextBoxValueAny("ProjectManagerTextBox"),
        ["ClosureStatus"] = GetComboBoxValueAny("ClosureStatusComboBox"),
        ["AdditionalRequirements"] = GetTextBoxValueAny("AdditionalRequirementsTextBox"),
        ["SelectedLanguage"] = GetSelectedLanguageSafe()
    };

    AddCheckBoxValueAny(result, "MechanicalDrawing", "MechanicalDrawingCheckBox");
    AddCheckBoxValueAny(result, "ElectricalDrawing", "ElectricalDrawingCheckBox");
    AddCheckBoxValueAny(result, "Specification", "SpecificationCheckBox");
    AddCheckBoxValueAny(result, "CableLugCrimpForceVerification", "CableLugCrimpForceVerificationCheckBox", "CableCrimpForceCheckBox", "CableCrimpForceVerificationCheckBox");
    AddCheckBoxValueAny(result, "FAI", "FaiCheckBox", "FAICheckBox");
    AddCheckBoxValueAny(result, "InspectorRequirement", "InspectorRequirementCheckBox");
    AddCheckBoxValueAny(result, "AutomaticTest", "AutomaticTestCheckBox", "AutomaticCheckCheckBox");
    AddCheckBoxValueAny(result, "AdditionalRequirementsEnabled", "AdditionalRequirementsCheckBox");

    return result;
}
'@

$cs2 = [regex]::Replace($cs, $pattern, $replacement, 1)

if ($cs2 -eq $cs) {
    throw "BuildCurrentParametersJsonModel was not found or was not replaced."
}

$cs = $cs2

# Add helper methods if missing
if ($cs -notmatch 'private string GetTextBoxValueAny') {
    $helpers = @'

private string GetTextBoxValueAny(params string[] names)
{
    foreach (var name in names)
    {
        if (FindName(name) is System.Windows.Controls.TextBox textBox)
        {
            return textBox.Text?.Trim() ?? string.Empty;
        }
    }

    return string.Empty;
}

private string GetComboBoxValueAny(params string[] names)
{
    foreach (var name in names)
    {
        if (FindName(name) is System.Windows.Controls.ComboBox comboBox)
        {
            if (comboBox.SelectedItem is System.Windows.Controls.ComboBoxItem item)
            {
                return item.Content?.ToString() ?? string.Empty;
            }

            return comboBox.Text?.Trim() ?? string.Empty;
        }
    }

    return string.Empty;
}

private void AddCheckBoxValueAny(Dictionary<string, object?> target, string jsonName, params string[] controlNames)
{
    foreach (var controlName in controlNames)
    {
        if (FindName(controlName) is System.Windows.Controls.CheckBox checkBox)
        {
            target[jsonName] = checkBox.IsChecked == true;
            return;
        }
    }

    target[jsonName] = false;
}
'@

    $lastBraceIndex = $cs.LastIndexOf("}")
    if ($lastBraceIndex -lt 0) {
        throw "Cannot find final closing brace in MainWindow.xaml.cs"
    }

    $cs = $cs.Insert($lastBraceIndex, "`r`n$helpers`r`n")
}

Set-Content $CodePath -Value $cs -Encoding UTF8

Write-Host "Running dotnet build..." -ForegroundColor Cyan
dotnet build

Write-Host ""
Write-Host "=== DONE ===" -ForegroundColor Green
Write-Host "JSON export now includes SerialNumber, ProductionQuantity, ClosureStatus, CableLugCrimpForceVerification, AutomaticTest." -ForegroundColor Green