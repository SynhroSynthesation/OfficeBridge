$ErrorActionPreference = "Stop"

Write-Host "=== OfficeBridge v1.0 Save JSON to Archive patch ===" -ForegroundColor Cyan

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

# ------------------------------------------------------------
# Backup
# ------------------------------------------------------------

$BackupDir = Join-Path $Root ("_backup_save_json_archive_v1_" + (Get-Date -Format "yyyyMMdd_HHmmss"))
New-Item -ItemType Directory -Path $BackupDir -Force | Out-Null

Copy-Item $XamlPath (Join-Path $BackupDir "MainWindow.xaml") -Force
Copy-Item $CodePath (Join-Path $BackupDir "MainWindow.xaml.cs") -Force

Write-Host "Backup created: $BackupDir" -ForegroundColor DarkGray

# ------------------------------------------------------------
# Patch MainWindow.xaml
# ------------------------------------------------------------

Write-Host "Patching MainWindow.xaml..." -ForegroundColor Yellow

$x = Get-Content $XamlPath -Raw -Encoding UTF8

# Add button only if it does not already exist
if ($x -notmatch 'x:Name="SaveJsonToArchiveButton"') {

    $buttonBlock = @'

                                    <Button x:Name="SaveJsonToArchiveButton"
                                            Content="Save JSON to Archive"
                                            Style="{StaticResource PrimaryButtonStyle}"
                                            Margin="0,8,0,0"
                                            Click="SaveJsonToArchiveButton_Click"/>
'@

    # Best case: insert after an existing JSON save/load button area
    if ($x -match 'x:Name="SaveJsonButton"') {
        $x = [regex]::Replace(
            $x,
            '(<Button\b[^>]*x:Name="SaveJsonButton"[^>]*/>)',
            "`$1`r`n$buttonBlock",
            1
        )
    }
    elseif ($x -match 'x:Name="LoadJsonButton"') {
        $x = [regex]::Replace(
            $x,
            '(<Button\b[^>]*x:Name="LoadJsonButton"[^>]*/>)',
            "`$1`r`n$buttonBlock",
            1
        )
    }
    elseif ($x -match 'JSON') {
        # Fallback: insert after first JSON-related TextBlock/Button line
        $x = [regex]::Replace(
            $x,
            '(<TextBlock[^>]*JSON[^>]*/>)',
            "`$1`r`n$buttonBlock",
            1
        )
    }
    else {
        throw "Could not find JSON panel location. Send MainWindow.xaml lines around the JSON panel."
    }
}

Set-Content $XamlPath -Value $x -Encoding UTF8

# ------------------------------------------------------------
# Patch MainWindow.xaml.cs
# ------------------------------------------------------------

Write-Host "Patching MainWindow.xaml.cs..." -ForegroundColor Yellow

$cs = Get-Content $CodePath -Raw -Encoding UTF8

# Ensure usings
if ($cs -notmatch 'using System\.Text\.Json;') {
    $cs = "using System.Text.Json;`r`n" + $cs
}

if ($cs -notmatch 'using System\.Text\.Encodings\.Web;') {
    $cs = "using System.Text.Encodings.Web;`r`n" + $cs
}

# Remove old patch block if exists
$cs = [regex]::Replace(
    $cs,
    '(?s)\s*// OFFICEBRIDGE_SAVE_JSON_ARCHIVE_PATCH_START.*?// OFFICEBRIDGE_SAVE_JSON_ARCHIVE_PATCH_END\s*',
    "`r`n"
)

$patch = @'

// OFFICEBRIDGE_SAVE_JSON_ARCHIVE_PATCH_START
private void SaveJsonToArchiveButton_Click(object sender, System.Windows.RoutedEventArgs e)
{
    try
    {
        var archiveDir = System.IO.Path.Combine(AppContext.BaseDirectory, "Archive", "Json");
        System.IO.Directory.CreateDirectory(archiveDir);

        var fileName = $"OfficeBridge_{DateTime.Now:yyyyMMdd_HHmmss}.json";
        var filePath = System.IO.Path.Combine(archiveDir, fileName);

        var data = BuildCurrentParametersJsonModel();

        var options = new JsonSerializerOptions
        {
            WriteIndented = true,
            Encoder = JavaScriptEncoder.UnsafeRelaxedJsonEscaping
        };

        var json = JsonSerializer.Serialize(data, options);
        System.IO.File.WriteAllText(filePath, json, System.Text.Encoding.UTF8);

        AppendLog($"JSON saved to archive: {filePath}");
    }
    catch (Exception ex)
    {
        AppendLog($"ERROR saving JSON to archive: {ex.Message}");
        System.Windows.MessageBox.Show(
            ex.Message,
            "Save JSON to Archive",
            System.Windows.MessageBoxButton.OK,
            System.Windows.MessageBoxImage.Error);
    }
}

private Dictionary<string, object?> BuildCurrentParametersJsonModel()
{
    var result = new Dictionary<string, object?>
    {
        ["CreatedAt"] = DateTime.Now.ToString("yyyy-MM-dd HH:mm:ss"),
        ["ProjectNumber"] = GetTextBoxValue("ProjectNumberTextBox"),
        ["ProductName"] = GetTextBoxValue("TitleTextBox"),
        ["SigmaPn"] = GetTextBoxValue("SigmaPnTextBox"),
        ["CustomerPn"] = GetTextBoxValue("CustomerPnTextBox"),
        ["Revision"] = GetTextBoxValue("RevisionTextBox"),
        ["UnitsToProduce"] = GetTextBoxValue("UnitsToProduceTextBox"),
        ["ProjectManager"] = GetTextBoxValue("ProjectManagerTextBox"),
        ["AdditionalRequirements"] = GetTextBoxValue("AdditionalRequirementsTextBox"),
        ["SelectedLanguage"] = GetSelectedLanguageSafe()
    };

    AddCheckBoxValueIfExists(result, "MechanicalDrawingCheckBox", "MechanicalDrawing");
    AddCheckBoxValueIfExists(result, "ElectricalDrawingCheckBox", "ElectricalDrawing");
    AddCheckBoxValueIfExists(result, "SpecificationCheckBox", "Specification");
    AddCheckBoxValueIfExists(result, "CableCrimpForceCheckBox", "CableCrimpForceCheck");
    AddCheckBoxValueIfExists(result, "FaiCheckBox", "FAI");
    AddCheckBoxValueIfExists(result, "InspectorRequirementCheckBox", "InspectorRequirement");
    AddCheckBoxValueIfExists(result, "AutomaticCheckCheckBox", "AutomaticCheck");
    AddCheckBoxValueIfExists(result, "AdditionalRequirementsCheckBox", "AdditionalRequirementsEnabled");

    return result;
}

private string GetTextBoxValue(string name)
{
    if (FindName(name) is System.Windows.Controls.TextBox textBox)
    {
        return textBox.Text?.Trim() ?? string.Empty;
    }

    return string.Empty;
}

private void AddCheckBoxValueIfExists(Dictionary<string, object?> target, string controlName, string jsonName)
{
    if (FindName(controlName) is System.Windows.Controls.CheckBox checkBox)
    {
        target[jsonName] = checkBox.IsChecked == true;
    }
}

private string GetSelectedLanguageSafe()
{
    if (FindName("LanguageComboBox") is System.Windows.Controls.ComboBox comboBox &&
        comboBox.SelectedItem is System.Windows.Controls.ComboBoxItem item &&
        item.Tag is string tag)
    {
        return tag;
    }

    return "English";
}
// OFFICEBRIDGE_SAVE_JSON_ARCHIVE_PATCH_END
'@

# Insert before final class brace
$lastBraceIndex = $cs.LastIndexOf("}")
if ($lastBraceIndex -lt 0) {
    throw "Cannot find final closing brace in MainWindow.xaml.cs"
}

$cs = $cs.Insert($lastBraceIndex, "`r`n$patch`r`n")

Set-Content $CodePath -Value $cs -Encoding UTF8

# ------------------------------------------------------------
# Build
# ------------------------------------------------------------

Write-Host "Running dotnet build..." -ForegroundColor Cyan
dotnet build

Write-Host ""
Write-Host "=== DONE ===" -ForegroundColor Green
Write-Host "Check JSON panel: Save JSON to Archive button should appear." -ForegroundColor Green
Write-Host "Saved files path at runtime: Archive\Json near application base directory." -ForegroundColor Green