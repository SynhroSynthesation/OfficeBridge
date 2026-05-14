$ErrorActionPreference = "Stop"

Write-Host "=== OfficeBridge v1.0 safe single language switch patch ===" -ForegroundColor Cyan

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

$BackupDir = Join-Path $Root ("_backup_single_language_switch_safe_v1_" + (Get-Date -Format "yyyyMMdd_HHmmss"))
New-Item -ItemType Directory -Path $BackupDir -Force | Out-Null

Copy-Item $XamlPath (Join-Path $BackupDir "MainWindow.xaml") -Force
Copy-Item $CodePath (Join-Path $BackupDir "MainWindow.xaml.cs") -Force

Write-Host "Backup created: $BackupDir" -ForegroundColor DarkGray

# ------------------------------------------------------------
# Patch XAML safely
# ------------------------------------------------------------

Write-Host "Patching MainWindow.xaml..." -ForegroundColor Yellow

$x = Get-Content $XamlPath -Raw -Encoding UTF8

# Remove only explicitly named language switch panel, not any generic StackPanel
$x = [regex]::Replace(
    $x,
    '(?s)\s*<StackPanel\b[^>]*x:Name="LanguageSwitchPanel"[^>]*>.*?</StackPanel>',
    '',
    1
)

# Remove standalone LanguageComboBox block if it exists
$x = [regex]::Replace(
    $x,
    '(?s)\s*<ComboBox\b[^>]*x:Name="LanguageComboBox"[^>]*>.*?</ComboBox>',
    '',
    1
)

# Remove standalone LanguageLabel only if left as a single self-closing TextBlock
$x = [regex]::Replace(
    $x,
    '(?s)\s*<TextBlock\b[^>]*x:Name="LanguageLabel"[^>]*/>',
    '',
    1
)

# Insert one language switch after ProjectDataTitleTextBlock if possible,
# otherwise insert before ProjectNumberLabel as fallback.
$singleLanguageSwitch = @'

                                    <StackPanel x:Name="LanguageSwitchPanel"
                                                Orientation="Horizontal"
                                                Margin="0,0,0,12">
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

if ($x -match 'x:Name="ProjectDataTitleTextBlock"') {
    $x = [regex]::Replace(
        $x,
        '(<TextBlock\s+x:Name="ProjectDataTitleTextBlock"[^>]*/>)',
        "`$1`r`n$singleLanguageSwitch",
        1
    )
}
elseif ($x -match 'x:Name="ProjectNumberLabel"') {
    Write-Host "ProjectDataTitleTextBlock not found. Using ProjectNumberLabel as fallback insertion point." -ForegroundColor Yellow

    $x = [regex]::Replace(
        $x,
        '(<TextBlock\s+x:Name="ProjectNumberLabel"[^>]*/>)',
        "$singleLanguageSwitch`r`n`$1",
        1
    )
}
else {
    throw "Neither ProjectDataTitleTextBlock nor ProjectNumberLabel found. Cannot place language switch safely."
}

Set-Content $XamlPath -Value $x -Encoding UTF8

# ------------------------------------------------------------
# Patch code-behind safely
# ------------------------------------------------------------

Write-Host "Patching MainWindow.xaml.cs..." -ForegroundColor Yellow

$cs = Get-Content $CodePath -Raw -Encoding UTF8

# Remove existing marked language blocks
$cs = [regex]::Replace(
    $cs,
    '(?s)\s*// OFFICEBRIDGE_LANGUAGE_PATCH_START.*?// OFFICEBRIDGE_LANGUAGE_PATCH_END\s*',
    "`r`n"
)

# Remove duplicate ApplyLanguage("English"); calls
$cs = [regex]::Replace(
    $cs,
    '\s*ApplyLanguage\("English"\);\s*',
    "`r`n"
)

# Add exactly one ApplyLanguage("English") after first InitializeComponent()
$cs = [regex]::Replace(
    $cs,
    'InitializeComponent\(\);',
    "InitializeComponent();`r`n            ApplyLanguage(""English"");",
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

$lastBraceIndex = $cs.LastIndexOf("}")
if ($lastBraceIndex -lt 0) {
    throw "Cannot find final closing brace in MainWindow.xaml.cs"
}

$cs = $cs.Insert($lastBraceIndex, "`r`n$languagePatch`r`n")

Set-Content $CodePath -Value $cs -Encoding UTF8

# ------------------------------------------------------------
# Diagnostics
# ------------------------------------------------------------

Write-Host "Language switch occurrences in XAML:" -ForegroundColor Cyan
Select-String -Path $XamlPath -Pattern "LanguageSwitchPanel|LanguageLabel|LanguageComboBox"

Write-Host "Running dotnet build..." -ForegroundColor Cyan
dotnet build

Write-Host ""
Write-Host "=== DONE ===" -ForegroundColor Green