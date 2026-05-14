$ErrorActionPreference = "Stop"

Write-Host "=== OfficeBridge v1.0 language separation patch ===" -ForegroundColor Cyan

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

$BackupDir = Join-Path $Root ("_backup_language_v1_" + (Get-Date -Format "yyyyMMdd_HHmmss"))
New-Item -ItemType Directory -Path $BackupDir -Force | Out-Null

Copy-Item $XamlPath (Join-Path $BackupDir "MainWindow.xaml") -Force
Copy-Item $CodePath (Join-Path $BackupDir "MainWindow.xaml.cs") -Force

Write-Host "Backup created: $BackupDir" -ForegroundColor DarkGray

# ------------------------------------------------------------
# Helper
# ------------------------------------------------------------

function Normalize-XamlNames {
    param([string]$Text)

    # Fix any previously damaged names
    $Text = $Text -replace 'x:Name="Project Number[^"]*TextBox"', 'x:Name="ProjectNumberTextBox"'
    $Text = $Text -replace 'Name="Project Number[^"]*TextBox"', 'Name="ProjectNumberTextBox"'

    $Text = $Text -replace 'x:Name="Product Name[^"]*TextBox"', 'x:Name="TitleTextBox"'
    $Text = $Text -replace 'Name="Product Name[^"]*TextBox"', 'Name="TitleTextBox"'

    $Text = $Text -replace 'x:Name="שם המוצרTextBox"', 'x:Name="TitleTextBox"'
    $Text = $Text -replace 'Name="שם המוצרTextBox"', 'Name="TitleTextBox"'

    $Text = $Text -replace 'x:Name="Revision[^"]*TextBox"', 'x:Name="RevisionTextBox"'
    $Text = $Text -replace 'Name="Revision[^"]*TextBox"', 'Name="RevisionTextBox"'

    return $Text
}

# ------------------------------------------------------------
# Patch XAML
# ------------------------------------------------------------

Write-Host "Patching MainWindow.xaml..." -ForegroundColor Yellow

$x = Get-Content $XamlPath -Raw -Encoding UTF8
$x = Normalize-XamlNames $x

# 1. Replace first fields block:
# Current expected block:
# Title / TitleTextBox
# Project Number / ProjectNumberTextBox
#
# Target:
# Project Number / ProjectNumberTextBox
# Product Name / TitleTextBox

$fieldsPattern = '(?s)\s*<TextBlock Text="Title" Style="\{StaticResource FieldLabelStyle\}"/>\s*<TextBox x:Name="TitleTextBox" Style="\{StaticResource InputTextBoxStyle\}"/>\s*<TextBlock Text="Project Number[^"]*" Style="\{StaticResource FieldLabelStyle\}"/>\s*<TextBox x:Name="ProjectNumberTextBox" Style="\{StaticResource InputTextBoxStyle\}"/>'

$fieldsReplacement = @'

                                    <TextBlock x:Name="ProjectNumberLabel" Text="Project Number" Style="{StaticResource FieldLabelStyle}"/>
                                    <TextBox x:Name="ProjectNumberTextBox" Style="{StaticResource InputTextBoxStyle}"/>

                                    <TextBlock x:Name="ProductNameLabel" Text="Product Name" Style="{StaticResource FieldLabelStyle}"/>
                                    <TextBox x:Name="TitleTextBox" Style="{StaticResource InputTextBoxStyle}"/>
'@

$x2 = [regex]::Replace($x, $fieldsPattern, $fieldsReplacement, 1)

# If the order is already correct, normalize labels there
if ($x2 -eq $x) {
    $correctOrderPattern = '(?s)\s*<TextBlock[^>]*Text="Project Number[^"]*"[^>]*/>\s*<TextBox x:Name="ProjectNumberTextBox" Style="\{StaticResource InputTextBoxStyle\}"/>\s*<TextBlock[^>]*Text="[^"]*(Product Name|שם המוצר|Title)[^"]*"[^>]*/>\s*<TextBox x:Name="TitleTextBox" Style="\{StaticResource InputTextBoxStyle\}"/>'

    $x2 = [regex]::Replace($x, $correctOrderPattern, $fieldsReplacement, 1)
}

$x = $x2

# 2. Normalize common mixed labels to English base UI
$x = $x -replace 'Text="Project Number / [^"]*"', 'Text="Project Number"'
$x = $x -replace 'Text="שם המוצר"', 'Text="Product Name"'
$x = $x -replace 'Text="Title"', 'Text="Product Name"'
$x = $x -replace 'Text="Revision / [^"]*"', 'Text="Revision"'
$x = $x -replace 'Text="Part Number / [^"]*"', 'Text="Part Number"'
$x = $x -replace 'Text="Additional requirements / [^"]*"', 'Text="Additional requirements"'
$x = $x -replace 'Content="Additional requirements / [^"]*"', 'Content="Additional requirements"'

# 3. Ensure named labels for known fields
$x = $x -replace '<TextBlock Text="Project Number" Style="\{StaticResource FieldLabelStyle\}"/>', '<TextBlock x:Name="ProjectNumberLabel" Text="Project Number" Style="{StaticResource FieldLabelStyle}"/>'
$x = $x -replace '<TextBlock Text="Product Name" Style="\{StaticResource FieldLabelStyle\}"/>', '<TextBlock x:Name="ProductNameLabel" Text="Product Name" Style="{StaticResource FieldLabelStyle}"/>'
$x = $x -replace '<TextBlock Text="Revision" Style="\{StaticResource FieldLabelStyle\}"/>', '<TextBlock x:Name="RevisionLabel" Text="Revision" Style="{StaticResource FieldLabelStyle}"/>'

# 4. Optional common labels if they exist
$x = $x -replace '<TextBlock Text="Sigma P/N" Style="\{StaticResource FieldLabelStyle\}"/>', '<TextBlock x:Name="SigmaPnLabel" Text="Sigma P/N" Style="{StaticResource FieldLabelStyle}"/>'
$x = $x -replace '<TextBlock Text="Customer P/N" Style="\{StaticResource FieldLabelStyle\}"/>', '<TextBlock x:Name="CustomerPnLabel" Text="Customer P/N" Style="{StaticResource FieldLabelStyle}"/>'
$x = $x -replace '<TextBlock Text="Units to produce" Style="\{StaticResource FieldLabelStyle\}"/>', '<TextBlock x:Name="UnitsToProduceLabel" Text="Units to produce" Style="{StaticResource FieldLabelStyle}"/>'
$x = $x -replace '<TextBlock Text="Project Manager" Style="\{StaticResource FieldLabelStyle\}"/>', '<TextBlock x:Name="ProjectManagerLabel" Text="Project Manager" Style="{StaticResource FieldLabelStyle}"/>'

# 5. Ensure AdditionalRequirementsCheckBox has x:Name and English content
if ($x -match '<CheckBox[^>]*Additional requirements[^>]*>' -and $x -notmatch 'x:Name="AdditionalRequirementsCheckBox"') {
    $x = $x -replace '(<CheckBox)([^>]*Additional requirements[^>]*>)', '$1 x:Name="AdditionalRequirementsCheckBox"$2'
}

$x = $x -replace 'Content="Additional requirements"', 'Content="Additional requirements"'

# 6. Add language selector once, near Project Data title
if ($x -notmatch 'x:Name="LanguageComboBox"') {
    $languageSelector = @'

                                    <StackPanel Orientation="Horizontal" Margin="0,0,0,12">
                                        <TextBlock x:Name="LanguageLabel"
                                                   Text="Language"
                                                   Style="{StaticResource FieldLabelStyle}"
                                                   VerticalAlignment="Center"
                                                   Margin="0,0,8,0"/>
                                        <ComboBox x:Name="LanguageComboBox"
                                                  Width="90"
                                                  SelectedIndex="0"
                                                  SelectionChanged="LanguageComboBox_SelectionChanged">
                                            <ComboBoxItem Content="EN" Tag="English"/>
                                            <ComboBoxItem Content="HE" Tag="Hebrew"/>
                                            <ComboBoxItem Content="RU" Tag="Russian"/>
                                        </ComboBox>
                                    </StackPanel>
'@

    $x = $x -replace '(<TextBlock x:Name="ProjectDataTitleTextBlock"[^>]*/>)', "`$1`r`n$languageSelector"
}

# 7. Final cleanup: no mixed project/product labels
$x = $x -replace 'Project Number / [^"]*', 'Project Number'
$x = $x -replace 'Additional requirements / [^"]*', 'Additional requirements'

Set-Content $XamlPath -Value $x -Encoding UTF8

# ------------------------------------------------------------
# Patch code-behind
# ------------------------------------------------------------

Write-Host "Patching MainWindow.xaml.cs..." -ForegroundColor Yellow

$cs = Get-Content $CodePath -Raw -Encoding UTF8

# Add ApplyLanguage call after InitializeComponent
if ($cs -notmatch 'ApplyLanguage\("English"\);') {
        $initReplacement = "InitializeComponent();" + "`r`n            ApplyLanguage(""English"");"
    $cs = $cs -replace 'InitializeComponent\(\);', $initReplacement
}

# Remove old duplicate language patch block if it exists
$cs = [regex]::Replace(
    $cs,
    '(?s)\s*// OFFICEBRIDGE_LANGUAGE_PATCH_START.*?// OFFICEBRIDGE_LANGUAGE_PATCH_END\s*',
    "`r`n",
    1
)

$languagePatch = @'

// OFFICEBRIDGE_LANGUAGE_PATCH_START
private void LanguageComboBox_SelectionChanged(object sender, System.Windows.Controls.SelectionChangedEventArgs e)
{
    if (LanguageComboBox?.SelectedItem is System.Windows.Controls.ComboBoxItem item &&
        item.Tag is string language)
    {
        ApplyLanguage(language);
    }
}

private void ApplyLanguage(string language)
{
    string projectData;
    string languageLabel;
    string projectNumber;
    string productName;
    string sigmaPn;
    string customerPn;
    string revision;
    string unitsToProduce;
    string projectManager;
    string additionalRequirements;

    switch (language)
    {
        case "Hebrew":
            projectData = "\u05E0\u05EA\u05D5\u05E0\u05D9 \u05E4\u05E8\u05D5\u05D9\u05E7\u05D8";
            languageLabel = "\u05E9\u05E4\u05D4";
            projectNumber = "\u05DE\u05E1\u05E4\u05E8 \u05E4\u05E8\u05D5\u05D9\u05E7\u05D8";
            productName = "\u05E9\u05DD \u05D4\u05DE\u05D5\u05E6\u05E8";
            sigmaPn = "\u05DE\u05E7\u05F4\u05D8 Sigma";
            customerPn = "\u05DE\u05E7\u05F4\u05D8 \u05DC\u05E7\u05D5\u05D7";
            revision = "\u05DE\u05D4\u05D3\u05D5\u05E8\u05D4";
            unitsToProduce = "\u05DB\u05DE\u05D5\u05EA";
            projectManager = "\u05DE\u05E0\u05D4\u05DC \u05E4\u05E8\u05D5\u05D9\u05E7\u05D8";
            additionalRequirements = "\u05D3\u05E8\u05D9\u05E9\u05D5\u05EA \u05E0\u05D5\u05E1\u05E4\u05D5\u05EA";
            this.FlowDirection = System.Windows.FlowDirection.RightToLeft;
            break;

        case "Russian":
            projectData = "\u0414\u0430\u043D\u043D\u044B\u0435 \u043F\u0440\u043E\u0435\u043A\u0442\u0430";
            languageLabel = "\u042F\u0437\u044B\u043A";
            projectNumber = "\u041D\u043E\u043C\u0435\u0440 \u043F\u0440\u043E\u0435\u043A\u0442\u0430";
            productName = "\u041D\u0430\u0437\u0432\u0430\u043D\u0438\u0435 \u0438\u0437\u0434\u0435\u043B\u0438\u044F";
            sigmaPn = "\u041D\u043E\u043C\u0435\u0440 Sigma";
            customerPn = "\u041D\u043E\u043C\u0435\u0440 \u0437\u0430\u043A\u0430\u0437\u0447\u0438\u043A\u0430";
            revision = "\u0420\u0435\u0432\u0438\u0437\u0438\u044F";
            unitsToProduce = "\u041A\u043E\u043B\u0438\u0447\u0435\u0441\u0442\u0432\u043E";
            projectManager = "\u0420\u0443\u043A\u043E\u0432\u043E\u0434\u0438\u0442\u0435\u043B\u044C \u043F\u0440\u043E\u0435\u043A\u0442\u0430";
            additionalRequirements = "\u0414\u043E\u043F\u043E\u043B\u043D\u0438\u0442\u0435\u043B\u044C\u043D\u044B\u0435 \u0442\u0440\u0435\u0431\u043E\u0432\u0430\u043D\u0438\u044F";
            this.FlowDirection = System.Windows.FlowDirection.LeftToRight;
            break;

        default:
            projectData = "Project Data";
            languageLabel = "Language";
            projectNumber = "Project Number";
            productName = "Product Name";
            sigmaPn = "Sigma P/N";
            customerPn = "Customer P/N";
            revision = "Revision";
            unitsToProduce = "Units to produce";
            projectManager = "Project Manager";
            additionalRequirements = "Additional requirements";
            this.FlowDirection = System.Windows.FlowDirection.LeftToRight;
            break;
    }

    SetTextBlockText("ProjectDataTitleTextBlock", projectData);
    SetTextBlockText("LanguageLabel", languageLabel);
    SetTextBlockText("ProjectNumberLabel", projectNumber);
    SetTextBlockText("ProductNameLabel", productName);
    SetTextBlockText("SigmaPnLabel", sigmaPn);
    SetTextBlockText("CustomerPnLabel", customerPn);
    SetTextBlockText("RevisionLabel", revision);
    SetTextBlockText("UnitsToProduceLabel", unitsToProduce);
    SetTextBlockText("ProjectManagerLabel", projectManager);

    if (FindName("AdditionalRequirementsCheckBox") is System.Windows.Controls.CheckBox additionalRequirementsCheckBox)
    {
        additionalRequirementsCheckBox.Content = additionalRequirements;
    }
}

private void SetTextBlockText(string name, string text)
{
    if (FindName(name) is System.Windows.Controls.TextBlock textBlock)
    {
        textBlock.Text = text;
    }
}
// OFFICEBRIDGE_LANGUAGE_PATCH_END
'@

# Insert before final class closing brace
$lastBraceIndex = $cs.LastIndexOf("}")
if ($lastBraceIndex -lt 0) {
    throw "Cannot find final closing brace in MainWindow.xaml.cs"
}

$cs = $cs.Insert($lastBraceIndex, "`r`n$languagePatch`r`n")

Set-Content $CodePath -Value $cs -Encoding UTF8

# ------------------------------------------------------------
# Build
# ------------------------------------------------------------

Write-Host "Running dotnet build..." -ForegroundColor Cyan
dotnet build

Write-Host ""
Write-Host "=== DONE ===" -ForegroundColor Green
Write-Host "Check UI: EN shows only English, HE only Hebrew, RU only Russian." -ForegroundColor Green
Write-Host "Check field order: Project Number first, Product Name second." -ForegroundColor Green
