$ErrorActionPreference = "Stop"

Write-Host "=== OfficeBridge v1.0 ProductName JSON fix ===" -ForegroundColor Cyan

$Root = Get-Location
$CodePath = Join-Path $Root "OfficeBridge.Desktop\MainWindow.xaml.cs"
$XamlPath = Join-Path $Root "OfficeBridge.Desktop\MainWindow.xaml"

if (!(Test-Path $CodePath)) {
    throw "MainWindow.xaml.cs not found: $CodePath"
}

if (!(Test-Path $XamlPath)) {
    throw "MainWindow.xaml not found: $XamlPath"
}

$BackupDir = Join-Path $Root ("_backup_product_name_json_v1_" + (Get-Date -Format "yyyyMMdd_HHmmss"))
New-Item -ItemType Directory -Path $BackupDir -Force | Out-Null

Copy-Item $CodePath (Join-Path $BackupDir "MainWindow.xaml.cs") -Force
Copy-Item $XamlPath (Join-Path $BackupDir "MainWindow.xaml") -Force

Write-Host "Backup created: $BackupDir" -ForegroundColor DarkGray

# ------------------------------------------------------------
# Ensure XAML has a stable ProductName field name alias
# ------------------------------------------------------------

$xaml = Get-Content $XamlPath -Raw -Encoding UTF8

# Keep the existing TitleTextBox because the app already uses it,
# but ensure the label is Product Name.
$xaml = $xaml -replace '(<TextBlock\s+x:Name="ProductNameLabel"[^>]*Text=")[^"]*(")', '$1Product Name$2'

Set-Content $XamlPath -Value $xaml -Encoding UTF8

# ------------------------------------------------------------
# C# method replacement helper
# ------------------------------------------------------------

function Replace-CSharpMethod {
    param(
        [string]$Source,
        [string]$MethodSignatureStart,
        [string]$Replacement
    )

    $methodIndex = $Source.IndexOf($MethodSignatureStart)
    if ($methodIndex -lt 0) {
        throw "Method not found: $MethodSignatureStart"
    }

    $openBraceIndex = $Source.IndexOf("{", $methodIndex)
    if ($openBraceIndex -lt 0) {
        throw "Opening brace not found for method: $MethodSignatureStart"
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
        throw "Closing brace not found for method: $MethodSignatureStart"
    }

    return $Source.Substring(0, $methodIndex) + $Replacement + $Source.Substring($endIndex + 1)
}

$cs = Get-Content $CodePath -Raw -Encoding UTF8

if ($cs -notmatch 'using System\.Text\.Json;') {
    $cs = "using System.Text.Json;`r`n" + $cs
}

# ------------------------------------------------------------
# Replace BuildCurrentParametersJsonModel
# ------------------------------------------------------------

$buildMethod = @'
private Dictionary<string, object?> BuildCurrentParametersJsonModel()
{
    var result = new Dictionary<string, object?>
    {
        ["CreatedAt"] = DateTime.Now.ToString("yyyy-MM-dd HH:mm:ss"),

        ["ProjectNumber"] = GetTextBoxValueForJson("ProjectNumberTextBox"),
        ["ProductName"] = GetTextBoxValueForJson("TitleTextBox", "ProductNameTextBox"),
        ["SigmaPn"] = GetTextBoxValueForJson("SigmaPnTextBox", "SigmaPNTextBox"),
        ["CustomerPn"] = GetTextBoxValueForJson("CustomerPnTextBox", "CustomerPNTextBox"),
        ["SerialNumber"] = GetTextBoxValueForJson("SerialNumberTextBox"),
        ["Revision"] = GetTextBoxValueForJson("RevisionTextBox"),
        ["ProductionQuantity"] = GetTextBoxValueForJson("ProductionQuantityTextBox", "UnitsToProduceTextBox"),
        ["ProjectManager"] = GetTextBoxValueForJson("ProjectManagerTextBox"),
        ["ClosureStatus"] = GetComboBoxValueForJson("ClosureStatusComboBox"),
        ["AdditionalRequirements"] = GetTextBoxValueForJson("AdditionalRequirementsTextBox"),
        ["SelectedLanguage"] = GetSelectedLanguageSafe()
    };

    AddCheckBoxValueForJson(result, "MechanicalDrawing", "MechanicalDrawingCheckBox");
    AddCheckBoxValueForJson(result, "ElectricalDrawing", "ElectricalDrawingCheckBox");
    AddCheckBoxValueForJson(result, "Specification", "SpecificationCheckBox");
    AddCheckBoxValueForJson(result, "CableLugCrimpForceVerification", "CableLugCrimpForceVerificationCheckBox", "CableCrimpForceCheckBox", "CableCrimpForceVerificationCheckBox");
    AddCheckBoxValueForJson(result, "FAI", "FaiCheckBox", "FAICheckBox");
    AddCheckBoxValueForJson(result, "InspectorRequirement", "InspectorRequirementCheckBox");
    AddCheckBoxValueForJson(result, "AutomaticTest", "AutomaticTestCheckBox", "AutomaticCheckCheckBox");
    AddCheckBoxValueForJson(result, "AdditionalRequirementsEnabled", "AdditionalRequirementsCheckBox");

    return result;
}
'@

$cs = Replace-CSharpMethod $cs "private Dictionary<string, object?> BuildCurrentParametersJsonModel()" $buildMethod

# ------------------------------------------------------------
# Replace LoadJsonIntoCurrentUi if it exists
# ------------------------------------------------------------

if ($cs.Contains("private void LoadJsonIntoCurrentUi(string json)")) {

$loadMethod = @'
private void LoadJsonIntoCurrentUi(string json)
{
    using var document = JsonDocument.Parse(json);
    var root = document.RootElement;

    SetTextBoxFromJson(root, "ProjectNumber", "ProjectNumberTextBox");

    // Product Name: support all old and new names.
    SetTextBoxFromJson(root, "ProductName", "TitleTextBox", "ProductNameTextBox");
    SetTextBoxFromJson(root, "Title", "TitleTextBox", "ProductNameTextBox");
    SetTextBoxFromJson(root, "Name", "TitleTextBox", "ProductNameTextBox");
    SetTextBoxFromJson(root, "Product", "TitleTextBox", "ProductNameTextBox");

    SetTextBoxFromJson(root, "SigmaPn", "SigmaPnTextBox", "SigmaPNTextBox");
    SetTextBoxFromJson(root, "SigmaPN", "SigmaPnTextBox", "SigmaPNTextBox");
    SetTextBoxFromJson(root, "PartNumber", "SigmaPnTextBox", "SigmaPNTextBox");

    SetTextBoxFromJson(root, "CustomerPn", "CustomerPnTextBox", "CustomerPNTextBox");
    SetTextBoxFromJson(root, "SerialNumber", "SerialNumberTextBox");
    SetTextBoxFromJson(root, "Serial", "SerialNumberTextBox");
    SetTextBoxFromJson(root, "Revision", "RevisionTextBox");
    SetTextBoxFromJson(root, "ProductionQuantity", "ProductionQuantityTextBox", "UnitsToProduceTextBox");
    SetTextBoxFromJson(root, "UnitsToProduce", "ProductionQuantityTextBox", "UnitsToProduceTextBox");
    SetTextBoxFromJson(root, "Quantity", "ProductionQuantityTextBox", "UnitsToProduceTextBox");
    SetTextBoxFromJson(root, "ProjectManager", "ProjectManagerTextBox");
    SetTextBoxFromJson(root, "Manager", "ProjectManagerTextBox");
    SetTextBoxFromJson(root, "AdditionalRequirements", "AdditionalRequirementsTextBox");

    SetComboBoxFromJson(root, "ClosureStatus", "ClosureStatusComboBox");

    SetCheckBoxFromJson(root, "MechanicalDrawing", "MechanicalDrawingCheckBox");
    SetCheckBoxFromJson(root, "ElectricalDrawing", "ElectricalDrawingCheckBox");
    SetCheckBoxFromJson(root, "Specification", "SpecificationCheckBox");
    SetCheckBoxFromJson(root, "CableLugCrimpForceVerification", "CableLugCrimpForceVerificationCheckBox", "CableCrimpForceCheckBox", "CableCrimpForceVerificationCheckBox");
    SetCheckBoxFromJson(root, "CableCrimpForceCheck", "CableLugCrimpForceVerificationCheckBox", "CableCrimpForceCheckBox", "CableCrimpForceVerificationCheckBox");
    SetCheckBoxFromJson(root, "FAI", "FaiCheckBox", "FAICheckBox");
    SetCheckBoxFromJson(root, "InspectorRequirement", "InspectorRequirementCheckBox");
    SetCheckBoxFromJson(root, "AutomaticTest", "AutomaticTestCheckBox", "AutomaticCheckCheckBox");
    SetCheckBoxFromJson(root, "AutomaticCheck", "AutomaticTestCheckBox", "AutomaticCheckCheckBox");
    SetCheckBoxFromJson(root, "AdditionalRequirementsEnabled", "AdditionalRequirementsCheckBox");

    ApplyAdditionalRequirementsVisibility();
}
'@

    $cs = Replace-CSharpMethod $cs "private void LoadJsonIntoCurrentUi(string json)" $loadMethod
}
else {
    Write-Host "WARNING: LoadJsonIntoCurrentUi not found. Export will be fixed, but import may still need manual patch." -ForegroundColor Yellow
}

# ------------------------------------------------------------
# Remove old helper block and add clean helpers
# ------------------------------------------------------------

$cs = [regex]::Replace(
    $cs,
    '(?s)\s*// OFFICEBRIDGE_PRODUCT_NAME_JSON_HELPERS_START.*?// OFFICEBRIDGE_PRODUCT_NAME_JSON_HELPERS_END\s*',
    "`r`n"
)

$helpers = @'

// OFFICEBRIDGE_PRODUCT_NAME_JSON_HELPERS_START
private string GetTextBoxValueForJson(params string[] names)
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

private string GetComboBoxValueForJson(params string[] names)
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

private void AddCheckBoxValueForJson(Dictionary<string, object?> target, string jsonName, params string[] controlNames)
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

private void SetTextBoxFromJson(JsonElement root, string jsonName, params string[] controlNames)
{
    if (!root.TryGetProperty(jsonName, out var value))
    {
        return;
    }

    var text = value.ValueKind switch
    {
        JsonValueKind.String => value.GetString() ?? string.Empty,
        JsonValueKind.Number => value.ToString(),
        JsonValueKind.True => "true",
        JsonValueKind.False => "false",
        _ => value.ToString()
    };

    foreach (var controlName in controlNames)
    {
        if (FindName(controlName) is System.Windows.Controls.TextBox textBox)
        {
            textBox.Text = text;
            return;
        }
    }
}

private void SetComboBoxFromJson(JsonElement root, string jsonName, params string[] controlNames)
{
    if (!root.TryGetProperty(jsonName, out var value))
    {
        return;
    }

    var text = value.ValueKind == JsonValueKind.String
        ? value.GetString()
        : value.ToString();

    if (string.IsNullOrWhiteSpace(text))
    {
        return;
    }

    foreach (var controlName in controlNames)
    {
        if (FindName(controlName) is System.Windows.Controls.ComboBox comboBox)
        {
            foreach (var item in comboBox.Items)
            {
                if (item is System.Windows.Controls.ComboBoxItem comboBoxItem &&
                    string.Equals(comboBoxItem.Content?.ToString(), text, StringComparison.OrdinalIgnoreCase))
                {
                    comboBox.SelectedItem = comboBoxItem;
                    return;
                }
            }

            comboBox.Text = text;
            return;
        }
    }
}

private void SetCheckBoxFromJson(JsonElement root, string jsonName, params string[] controlNames)
{
    if (!root.TryGetProperty(jsonName, out var value))
    {
        return;
    }

    var isChecked = value.ValueKind switch
    {
        JsonValueKind.True => true,
        JsonValueKind.False => false,
        JsonValueKind.String => bool.TryParse(value.GetString(), out var parsed) && parsed,
        JsonValueKind.Number => value.TryGetInt32(out var number) && number != 0,
        _ => false
    };

    foreach (var controlName in controlNames)
    {
        if (FindName(controlName) is System.Windows.Controls.CheckBox checkBox)
        {
            checkBox.IsChecked = isChecked;
            return;
        }
    }
}
// OFFICEBRIDGE_PRODUCT_NAME_JSON_HELPERS_END
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
Write-Host "ProductName export/import fixed for TitleTextBox and ProductNameTextBox." -ForegroundColor Green