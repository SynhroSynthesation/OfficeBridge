$ErrorActionPreference = "Stop"

Write-Host "=== OfficeBridge v1.0 complete JSON export patch v2 ===" -ForegroundColor Cyan

$Root = Get-Location
$CodePath = Join-Path $Root "OfficeBridge.Desktop\MainWindow.xaml.cs"

if (!(Test-Path $CodePath)) {
    throw "MainWindow.xaml.cs not found: $CodePath"
}

$BackupDir = Join-Path $Root ("_backup_json_export_complete_v2_" + (Get-Date -Format "yyyyMMdd_HHmmss"))
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

$replacementMethod = @'
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

    AddCheckBoxValueAny(
        result,
        "CableLugCrimpForceVerification",
        "CableLugCrimpForceVerificationCheckBox",
        "CableCrimpForceCheckBox",
        "CableCrimpForceVerificationCheckBox");

    AddCheckBoxValueAny(result, "FAI", "FaiCheckBox", "FAICheckBox");
    AddCheckBoxValueAny(result, "InspectorRequirement", "InspectorRequirementCheckBox");
    AddCheckBoxValueAny(result, "AutomaticTest", "AutomaticTestCheckBox", "AutomaticCheckCheckBox");
    AddCheckBoxValueAny(result, "AdditionalRequirementsEnabled", "AdditionalRequirementsCheckBox");

    return result;
}
'@

$cs = Replace-CSharpMethod $cs "private Dictionary<string, object?> BuildCurrentParametersJsonModel()" $replacementMethod

# Remove previous helper block if present
$cs = [regex]::Replace(
    $cs,
    '(?s)\s*// OFFICEBRIDGE_JSON_EXPORT_HELPERS_START.*?// OFFICEBRIDGE_JSON_EXPORT_HELPERS_END\s*',
    "`r`n"
)

$helpers = @'

// OFFICEBRIDGE_JSON_EXPORT_HELPERS_START
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
// OFFICEBRIDGE_JSON_EXPORT_HELPERS_END
'@

$lastBraceIndex = $cs.LastIndexOf("}")
if ($lastBraceIndex -lt 0) {
    throw "Cannot find final closing brace in MainWindow.xaml.cs"
}

$cs = $cs.Insert($lastBraceIndex, "`r`n$helpers`r`n")

Set-Content $CodePath -Value $cs -Encoding UTF8

Write-Host "Running dotnet build..." -ForegroundColor Cyan
dotnet build

Write-Host ""
Write-Host "=== DONE ===" -ForegroundColor Green
Write-Host "JSON export now includes SerialNumber, ProductionQuantity, ClosureStatus, CableLugCrimpForceVerification, AutomaticTest." -ForegroundColor Green