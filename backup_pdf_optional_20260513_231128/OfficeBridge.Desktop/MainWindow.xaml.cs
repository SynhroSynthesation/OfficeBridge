using OfficeBridge.Core.Models;
using OfficeBridge.Infrastructure.Office;
using OfficeBridge.Infrastructure.Services;
using OfficeBridge.Infrastructure.Storage;
using OfficeBridge.TemplateEngine.Docx;
using System.Diagnostics;
using System.IO;
using System.Text.Json;
using System.Windows;
using System.Windows.Controls;
using System.Windows.Media;
using Forms = System.Windows.Forms;
using MessageBox = System.Windows.MessageBox;
using OpenFileDialog = Microsoft.Win32.OpenFileDialog;

namespace OfficeBridge.Desktop;

public partial class MainWindow : Window
{
    private sealed class DesktopAppSettings
    {
        public LibreOfficeSettings LibreOffice { get; set; } = new();
        public PathSettings Paths { get; set; } = new();
    }

    private sealed class LibreOfficeSettings
    {
        public string SofficePath { get; set; } = @"C:\Program Files\LibreOffice\program\soffice.exe";
    }

    private sealed class PathSettings
    {
        public string DefaultTemplate { get; set; } = @"C:\SOFTWARE\Fast_Tag-process\TAG-process_HARNESS.docx";
        public string DefaultJson { get; set; } = @"Data\tagprocess.sample.json";
        public string DefaultOutputFolder { get; set; } = "Output";
        public string DefaultArchiveFolder { get; set; } = "Archive";
    }

        private DesktopAppSettings _settings = new();
    private bool _uiReadyForLanguage;

    public MainWindow()
    {
        InitializeComponent();
        InitializeDefaults();
    }

    private void InitializeDefaults()
    {
        _settings = LoadSettings();

        var appDir = AppContext.BaseDirectory;
        var currentDir = Directory.GetCurrentDirectory();

        TemplatePathTextBox.Text = ResolvePath(appDir, currentDir, _settings.Paths.DefaultTemplate);
        JsonPathTextBox.Text = ResolvePath(appDir, currentDir, _settings.Paths.DefaultJson);
        OutputFolderTextBox.Text = ResolvePath(appDir, currentDir, _settings.Paths.DefaultOutputFolder);
        ArchiveFolderTextBox.Text = ResolvePath(appDir, currentDir, _settings.Paths.DefaultArchiveFolder);

        TitleTextBox.Text = "Control Box Assembly";
        ProjectNumberTextBox.Text = "PR260000xx";
        SigmaPnTextBox.Text = "BN12345A";
        SerialNumberTextBox.Text = "SIGM-2613-001";

        ProjectManagerTextBox.Text = "Yuri F";
        ProductionQuantityTextBox.Text = "1";
        RevisionTextBox.Text = "A";
        ClosureStatusComboBox.SelectedIndex = 0;

        MechanicalDrawingCheckBox.IsChecked = true;
        ElectricalDrawingCheckBox.IsChecked = true;
        SpecificationCheckBox.IsChecked = true;
        CableCrimpCheckBox.IsChecked = false;
        FaiCheckBox.IsChecked = false;
        InspectorRequirementCheckBox.IsChecked = false;
        AutomaticTestCheckBox.IsChecked = true;
        AdditionalRequirementsCheckBox.IsChecked = false;

        AppendLog("Application initialized.");
        AppendLog($"LibreOffice path: {_settings.LibreOffice.SofficePath}");
    
        
        _uiReadyForLanguage = true;
        ApplyLanguage();_uiReadyForLanguage = true;
        ApplyLanguage();}

    private static DesktopAppSettings LoadSettings()
    {
        try
        {
            var settingsPath = Path.Combine(AppContext.BaseDirectory, "appsettings.json");

            if (!File.Exists(settingsPath))
                return new DesktopAppSettings();

            var json = File.ReadAllText(settingsPath);
            var settings = JsonSerializer.Deserialize<DesktopAppSettings>(json, new JsonSerializerOptions
            {
                PropertyNameCaseInsensitive = true
            });

            return settings ?? new DesktopAppSettings();
        }
        catch
        {
            return new DesktopAppSettings();
        }
    }

    private static string ResolvePath(string appDir, string currentDir, string value)
    {
        if (string.IsNullOrWhiteSpace(value))
            return currentDir;

        if (Path.IsPathRooted(value))
            return value;

        var appRelative = Path.GetFullPath(Path.Combine(appDir, value));
        if (File.Exists(appRelative) || Directory.Exists(appRelative))
            return appRelative;

        return Path.GetFullPath(Path.Combine(currentDir, value));
    }

    private void AppendLog(string message)
    {
        LogTextBox.AppendText($"[{DateTime.Now:HH:mm:ss}] {message}{Environment.NewLine}");
        LogTextBox.ScrollToEnd();
    }

    private bool ValidateBeforeGeneration()
    {
        if (string.IsNullOrWhiteSpace(TitleTextBox.Text))
        {
            MessageBox.Show("Title is required.", "Validation", MessageBoxButton.OK, MessageBoxImage.Warning);
            return false;
        }

        if (string.IsNullOrWhiteSpace(ProjectNumberTextBox.Text))
        {
            MessageBox.Show("Project Number is required.", "Validation", MessageBoxButton.OK, MessageBoxImage.Warning);
            return false;
        }

        if (string.IsNullOrWhiteSpace(SerialNumberTextBox.Text))
        {
            MessageBox.Show("Serial Number is required.", "Validation", MessageBoxButton.OK, MessageBoxImage.Warning);
            return false;
        }

        if (!File.Exists(TemplatePathTextBox.Text.Trim()))
        {
            MessageBox.Show("Template file was not found.", "Validation", MessageBoxButton.OK, MessageBoxImage.Warning);
            return false;
        }

        return true;
    }

    private TagProcessModel BuildModelFromUi()
    {
        return new TagProcessModel
        {
            Title = TitleTextBox.Text.Trim(),
            ProjectNumber = ProjectNumberTextBox.Text.Trim(),
            SigmaPn = SigmaPnTextBox.Text.Trim(),
            SerialNumber = SerialNumberTextBox.Text.Trim(),

            ProjectManager = ProjectManagerTextBox.Text.Trim(),
            ProductionQuantity = ProductionQuantityTextBox.Text.Trim(),
            Revision = RevisionTextBox.Text.Trim(),
            ClosureStatus = (ClosureStatusComboBox.SelectedItem as ComboBoxItem)?.Content?.ToString() ?? string.Empty,

            IncludeMechanicalDrawing = MechanicalDrawingCheckBox.IsChecked == true,
            IncludeElectricalDrawing = ElectricalDrawingCheckBox.IsChecked == true,
            IncludeSpecification = SpecificationCheckBox.IsChecked == true,
            IncludeCableCrimpVerification = CableCrimpCheckBox.IsChecked == true,
            IncludeFai = FaiCheckBox.IsChecked == true,
            IncludeInspectorRequirement = InspectorRequirementCheckBox.IsChecked == true,
            IncludeAutomaticTest = AutomaticTestCheckBox.IsChecked == true,
            IncludeAdditionalRequirements = AdditionalRequirementsCheckBox.IsChecked == true
        };
    }

    private static string MakeSafeFileName(string value)
    {
        return string.Concat(value.Where(c => !Path.GetInvalidFileNameChars().Contains(c)));
    }

    private async void GenerateButton_Click(object sender, RoutedEventArgs e)
    {
        try
        {
            if (!ValidateBeforeGeneration())
                return;

            var templatePath = TemplatePathTextBox.Text.Trim();
            var outputDir = OutputFolderTextBox.Text.Trim();
            var archiveDir = ArchiveFolderTextBox.Text.Trim();

            Directory.CreateDirectory(outputDir);
            Directory.CreateDirectory(archiveDir);

            var model = BuildModelFromUi();

            var safeProjectNumber = MakeSafeFileName(model.ProjectNumber);
            var safeSerialNumber = MakeSafeFileName(model.SerialNumber);

            var outputFileName =
                $"TAG_{safeProjectNumber}_{safeSerialNumber}_{DateTime.Now:yyyyMMdd_HHmmss}.docx";

            var templateEngine = new DocxTemplateEngine();
            var storage = new LocalStorageProvider();

            var sofficePath = _settings.LibreOffice.SofficePath;
            var officeProvider = new LibreOfficeProvider(sofficePath);

            if (!officeProvider.IsAvailable())
            {
                AppendLog("Warning: LibreOffice was not found. DOCX will be created, PDF export may be skipped.");
                AppendLog($"Expected LibreOffice path: {sofficePath}");
            }

            var workflow = new DocumentWorkflowService(storage, templateEngine, officeProvider);

            var request = new TemplateRequest
            {
                TemplateIdOrPath = templatePath,
                OutputDirectory = outputDir,
                OutputFileName = outputFileName,
                Placeholders = TagProcessPlaceholderMapper.Map(model)
            };

            AppendLog("Generation started...");
            AppendLog($"Template: {templatePath}");

            var result = await workflow.GenerateAsync(request, archiveDir);

            AppendLog($"DOCX: {result.docxPath}");

            if (File.Exists(result.pdfPath))
            {
                AppendLog($"PDF : {result.pdfPath}");
                MessageBox.Show("DOCX and PDF were created successfully.", "Done", MessageBoxButton.OK, MessageBoxImage.Information);
            }
            else
            {
                AppendLog("PDF : was not created.");
                MessageBox.Show(
                    "DOCX was created, but PDF was not created. Check LibreOffice path in appsettings.json.",
                    "Done with warning",
                    MessageBoxButton.OK,
                    MessageBoxImage.Warning);
            }
        }
        catch (Exception ex)
        {
            AppendLog("Error:");
            AppendLog(ex.ToString());
            MessageBox.Show(ex.Message, "Error", MessageBoxButton.OK, MessageBoxImage.Error);
        }
    }

    private void LoadJsonButton_Click(object sender, RoutedEventArgs e)
    {
        try
        {
            var jsonPath = JsonPathTextBox.Text.Trim();

            if (!File.Exists(jsonPath))
            {
                MessageBox.Show("JSON file was not found.", "Error", MessageBoxButton.OK, MessageBoxImage.Error);
                return;
            }

            var json = File.ReadAllText(jsonPath);
            var model = JsonSerializer.Deserialize<TagProcessModel>(json, new JsonSerializerOptions
            {
                PropertyNameCaseInsensitive = true
            });

            if (model is null)
            {
                MessageBox.Show("Could not deserialize JSON.", "Error", MessageBoxButton.OK, MessageBoxImage.Error);
                return;
            }

            TitleTextBox.Text = model.Title;
            ProjectNumberTextBox.Text = model.ProjectNumber;
            SigmaPnTextBox.Text = model.SigmaPn;
            SerialNumberTextBox.Text = model.SerialNumber;

            ProjectManagerTextBox.Text = model.ProjectManager;
            ProductionQuantityTextBox.Text = model.ProductionQuantity;
            RevisionTextBox.Text = model.Revision;

            AppendLog($"JSON loaded: {jsonPath}");
        }
        catch (Exception ex)
        {
            AppendLog(ex.ToString());
            MessageBox.Show(ex.Message, "Error", MessageBoxButton.OK, MessageBoxImage.Error);
        }
    }

    private void BrowseTemplateButton_Click(object sender, RoutedEventArgs e)
    {
        var dialog = new OpenFileDialog
        {
            Filter = "Word documents (*.docx)|*.docx|All files (*.*)|*.*"
        };

        if (dialog.ShowDialog() == true)
        {
            TemplatePathTextBox.Text = dialog.FileName;
        }
    }

    private void BrowseJsonButton_Click(object sender, RoutedEventArgs e)
    {
        var dialog = new OpenFileDialog
        {
            Filter = "JSON files (*.json)|*.json|All files (*.*)|*.*"
        };

        if (dialog.ShowDialog() == true)
        {
            JsonPathTextBox.Text = dialog.FileName;
        }
    }

    private void BrowseOutputButton_Click(object sender, RoutedEventArgs e)
    {
        using var dialog = new Forms.FolderBrowserDialog();
        if (dialog.ShowDialog() == Forms.DialogResult.OK)
        {
            OutputFolderTextBox.Text = dialog.SelectedPath;
        }
    }

    private void BrowseArchiveButton_Click(object sender, RoutedEventArgs e)
    {
        using var dialog = new Forms.FolderBrowserDialog();
        if (dialog.ShowDialog() == Forms.DialogResult.OK)
        {
            ArchiveFolderTextBox.Text = dialog.SelectedPath;
        }
    }

    private void OpenOutputButton_Click(object sender, RoutedEventArgs e)
    {
        var path = OutputFolderTextBox.Text.Trim();

        if (!Directory.Exists(path))
        {
            MessageBox.Show("Output folder was not found.", "Error", MessageBoxButton.OK, MessageBoxImage.Error);
            return;
        }

        Process.Start(new ProcessStartInfo
        {
            FileName = path,
            UseShellExecute = true
        });
    }

    private void CheckLibreOfficeButton_Click(object sender, RoutedEventArgs e)
    {
        var sofficePath = _settings.LibreOffice.SofficePath;

        if (File.Exists(sofficePath))
        {
            AppendLog($"LibreOffice found: {sofficePath}");
            MessageBox.Show("LibreOffice was found.", "LibreOffice", MessageBoxButton.OK, MessageBoxImage.Information);
        }
        else
        {
            AppendLog($"LibreOffice not found: {sofficePath}");
            MessageBox.Show(
                $"LibreOffice was not found.\n\nExpected path:\n{sofficePath}\n\nEdit appsettings.json if LibreOffice is installed in another folder.",
                "LibreOffice",
                MessageBoxButton.OK,
                MessageBoxImage.Warning);
        }
    }
    private void OpenArchiveButton_Click(object sender, RoutedEventArgs e)
    {
        var path = ArchiveFolderTextBox.Text.Trim();

        if (!Directory.Exists(path))
        {
            MessageBox.Show("Archive folder was not found.", "Error", MessageBoxButton.OK, MessageBoxImage.Error);
            return;
        }

        Process.Start(new ProcessStartInfo
        {
            FileName = path,
            UseShellExecute = true
        });
    }
    
    private static void SetTextIfExists(TextBlock? textBlock, string text)
    {
        if (textBlock is not null)
            textBlock.Text = text;
    }

    private static void SetContentIfExists(ContentControl? control, object content)
    {
        if (control is not null)
            control.Content = content;
    }

    private static void SetHeaderIfExists(HeaderedContentControl? control, object header)
    {
        if (control is not null)
            control.Header = header;
    }
    private void LanguageRadioButton_Checked(object sender, RoutedEventArgs e)
    {
        if (!_uiReadyForLanguage)
            return;

        ApplyLanguage();
    }


    private int GetSelectedLanguageIndex()
    {
        if (HebrewLanguageRadioButton?.IsChecked == true)
            return 1;

        if (RussianLanguageRadioButton?.IsChecked == true)
            return 2;

        return 0;
    }
    private void ApplyLanguage()
    {
        if (!_uiReadyForLanguage)
            return;

        if (EnglishLanguageRadioButton is null || HebrewLanguageRadioButton is null || RussianLanguageRadioButton is null)
            return;
        var index = GetSelectedLanguageIndex();

        if (index == 1)
        {
            ApplyHebrewLanguage();
            ApplyClosureStatusLabels();
            return;
        }

        if (index == 2)
        {
            ApplyRussianLanguage();
            ApplyClosureStatusLabels();
            return;
        }

        ApplyEnglishLanguage();
        ApplyClosureStatusLabels();
    }


    private void ApplyClosureStatusLabels()
    {
        if (ClosureStatusComboBox is null || ClosureStatusComboBox.Items.Count < 2)
            return;

        if (ClosureStatusComboBox.Items[0] is System.Windows.Controls.ComboBoxItem fullItem)
            fullItem.Content = "FULL";

        if (ClosureStatusComboBox.Items[1] is System.Windows.Controls.ComboBoxItem partialItem)
            partialItem.Content = "PARTIAL";
    }
    private void ApplyEnglishLanguage()
    {
        FlowDirection = System.Windows.FlowDirection.LeftToRight;

        SetTextIfExists(HeaderTitleTextBlock, "Fast and Simple");
        SetTextIfExists(HeaderSubtitleTextBlock, "TAG Process document generation");
        SetTextIfExists(LanguageLabelTextBlock, "Language");

        SetHeaderIfExists(StandardTabItem, "STANDARD");
        SetHeaderIfExists(AdvancedTabItem, "ADVANCED");

        SetTextIfExists(ProjectDataTitleTextBlock, "Project Data");
        SetTextIfExists(DocumentOptionsTitleTextBlock, "Document Options");
        SetTextIfExists(StandardGenerationTitleTextBlock, "Standard Generation");
        SetTextIfExists(AdvancedSettingsTitleTextBlock, "Advanced Settings");
        SetTextIfExists(ExecutionLogTitleTextBlock, "Execution Log");

        SetContentIfExists(GenerateButton, "Generate DOCX + PDF");
        SetContentIfExists(OpenOutputButton, "Open Output");
        SetContentIfExists(LoadJsonButton, "Load JSON");

        TrySetText("Title", "Title");
        TrySetText("Project Number", "Project Number");
        TrySetText("Sigma P/N", "Sigma P/N");
        TrySetText("Serial Number", "Serial Number");
        TrySetText("Project Manager", "Project Manager");
        TrySetText("Production Quantity", "Production Quantity");
        TrySetText("Revision", "Revision");
        TrySetText("Closure Status", "Closure Status");
        TrySetText("Template Path", "Template Path");
        TrySetText("Output Folder", "Output Folder");
        TrySetText("JSON Path", "JSON Path");
        TrySetText("Archive Folder", "Archive Folder");
        TrySetText("Status messages and errors", "Status messages and errors");

        TrySetContent("Mechanical Drawing", "Mechanical Drawing");
        TrySetContent("Electrical Drawing", "Electrical Drawing");
        TrySetContent("Specification", "Specification");
        TrySetContent("Cable Lug Crimp Force Verification", "Cable Lug Crimp Force Verification");
        TrySetContent("FAI", "FAI");
        TrySetContent("Inspector Requirement", "Inspector Requirement");
        TrySetContent("Automatic Test", "Automatic Test");
        TrySetContent("Additional Requirements", "Additional Requirements");

        TrySetGroupBoxHeader("Document Package", "Document Package");
        TrySetComboBoxItem("Full Closure", "FULL");
        TrySetComboBoxItem("Partial Closure", "PARTIAL");
    }

    private void ApplyRussianLanguage()
    {
        FlowDirection = System.Windows.FlowDirection.LeftToRight;

        SetTextIfExists(HeaderTitleTextBlock, "\u0411\u044B\u0441\u0442\u0440\u043E \u0438 \u043F\u0440\u043E\u0441\u0442\u043E");
        SetTextIfExists(HeaderSubtitleTextBlock, "\u0421\u043E\u0437\u0434\u0430\u043D\u0438\u0435 \u0434\u043E\u043A\u0443\u043C\u0435\u043D\u0442\u043E\u0432 TAG Process");
        SetTextIfExists(LanguageLabelTextBlock, "\u042F\u0437\u044B\u043A");

        SetHeaderIfExists(StandardTabItem, "\u0421\u0422\u0410\u041D\u0414\u0410\u0420\u0422");
        SetHeaderIfExists(AdvancedTabItem, "\u0420\u0410\u0421\u0428\u0418\u0420\u0415\u041D\u041D\u042B\u0419");

        SetTextIfExists(ProjectDataTitleTextBlock, "\u0414\u0430\u043D\u043D\u044B\u0435 \u043F\u0440\u043E\u0435\u043A\u0442\u0430");
        SetTextIfExists(DocumentOptionsTitleTextBlock, "\u041F\u0430\u0440\u0430\u043C\u0435\u0442\u0440\u044B \u0434\u043E\u043A\u0443\u043C\u0435\u043D\u0442\u0430");
        SetTextIfExists(StandardGenerationTitleTextBlock, "\u0421\u0442\u0430\u043D\u0434\u0430\u0440\u0442\u043D\u0430\u044F \u0433\u0435\u043D\u0435\u0440\u0430\u0446\u0438\u044F");
        SetTextIfExists(AdvancedSettingsTitleTextBlock, "\u0420\u0430\u0441\u0448\u0438\u0440\u0435\u043D\u043D\u044B\u0435 \u043D\u0430\u0441\u0442\u0440\u043E\u0439\u043A\u0438");
        SetTextIfExists(ExecutionLogTitleTextBlock, "\u0416\u0443\u0440\u043D\u0430\u043B \u0432\u044B\u043F\u043E\u043B\u043D\u0435\u043D\u0438\u044F");

        SetContentIfExists(GenerateButton, "\u0421\u043E\u0437\u0434\u0430\u0442\u044C DOCX + PDF");
        SetContentIfExists(OpenOutputButton, "\u041E\u0442\u043A\u0440\u044B\u0442\u044C Output");
        SetContentIfExists(LoadJsonButton, "\u0417\u0430\u0433\u0440\u0443\u0437\u0438\u0442\u044C JSON");

        TrySetText("Title", "\u041D\u0430\u0437\u0432\u0430\u043D\u0438\u0435");
        TrySetText("Project Number", "\u041D\u043E\u043C\u0435\u0440 \u043F\u0440\u043E\u0435\u043A\u0442\u0430");
        TrySetText("Sigma P/N", "Sigma P/N");
        TrySetText("Serial Number", "\u0421\u0435\u0440\u0438\u0439\u043D\u044B\u0439 \u043D\u043E\u043C\u0435\u0440");
        TrySetText("Project Manager", "\u041C\u0435\u043D\u0435\u0434\u0436\u0435\u0440 \u043F\u0440\u043E\u0435\u043A\u0442\u0430");
        TrySetText("Production Quantity", "\u041A\u043E\u043B-\u0432\u043E \u0434\u043B\u044F \u043F\u0440\u043E\u0438\u0437\u0432\u043E\u0434\u0441\u0442\u0432\u0430");
        TrySetText("Revision", "\u0420\u0435\u0432\u0438\u0437\u0438\u044F");
        TrySetText("Closure Status", "\u0421\u0442\u0430\u0442\u0443\u0441 \u0437\u0430\u043A\u0440\u044B\u0442\u0438\u044F");
        TrySetText("Template Path", "\u041F\u0443\u0442\u044C \u043A \u0448\u0430\u0431\u043B\u043E\u043D\u0443");
        TrySetText("Output Folder", "\u041F\u0430\u043F\u043A\u0430 \u0432\u044B\u0432\u043E\u0434\u0430");
        TrySetText("JSON Path", "\u041F\u0443\u0442\u044C \u043A JSON");
        TrySetText("Archive Folder", "\u041F\u0430\u043F\u043A\u0430 \u0430\u0440\u0445\u0438\u0432\u0430");
        TrySetText("Status messages and errors", "\u0421\u0442\u0430\u0442\u0443\u0441\u044B \u0438 \u043E\u0448\u0438\u0431\u043A\u0438");

        TrySetContent("Mechanical Drawing", "\u041C\u0435\u0445\u0430\u043D\u0438\u0447\u0435\u0441\u043A\u0438\u0439 \u0447\u0435\u0440\u0442\u0451\u0436");
        TrySetContent("Electrical Drawing", "\u042D\u043B\u0435\u043A\u0442\u0440\u0438\u0447\u0435\u0441\u043A\u0438\u0439 \u0447\u0435\u0440\u0442\u0451\u0436");
        TrySetContent("Specification", "\u0421\u043F\u0435\u0446\u0438\u0444\u0438\u043A\u0430\u0446\u0438\u044F");
        TrySetContent("Cable Lug Crimp Force Verification", "\u041F\u0440\u043E\u0432\u0435\u0440\u043A\u0430 \u0443\u0441\u0438\u043B\u0438\u044F \u043E\u0431\u0436\u0438\u043C\u0430");
        TrySetContent("FAI", "FAI");
        TrySetContent("Inspector Requirement", "\u0422\u0440\u0435\u0431\u043E\u0432\u0430\u043D\u0438\u0435 \u0438\u043D\u0441\u043F\u0435\u043A\u0442\u043E\u0440\u0430");
        TrySetContent("Automatic Test", "\u0410\u0432\u0442\u043E\u0442\u0435\u0441\u0442");
        TrySetContent("Additional Requirements", "\u0414\u043E\u043F. \u0442\u0440\u0435\u0431\u043E\u0432\u0430\u043D\u0438\u044F");

        TrySetGroupBoxHeader("Document Package", "\u041F\u0430\u043A\u0435\u0442 \u0434\u043E\u043A\u0443\u043C\u0435\u043D\u0442\u043E\u0432");
        TrySetComboBoxItem("Full Closure", "FULL");
        TrySetComboBoxItem("Partial Closure", "PARTIAL");
    }

    private void ApplyHebrewLanguage()
    {
        FlowDirection = System.Windows.FlowDirection.LeftToRight;

        SetTextIfExists(HeaderTitleTextBlock, "\u05DE\u05D4\u05D9\u05E8 \u05D5\u05E4\u05E9\u05D5\u05D8");
        SetTextIfExists(HeaderSubtitleTextBlock, "\u05D9\u05E6\u05D9\u05E8\u05EA \u05DE\u05E1\u05DE\u05DB\u05D9 TAG Process");
        SetTextIfExists(LanguageLabelTextBlock, "\u05E9\u05E4\u05D4");

        SetHeaderIfExists(StandardTabItem, "\u05E8\u05D2\u05D9\u05DC");
        SetHeaderIfExists(AdvancedTabItem, "\u05DE\u05EA\u05E7\u05D3\u05DD");

        SetTextIfExists(ProjectDataTitleTextBlock, "\u05E0\u05EA\u05D5\u05E0\u05D9 \u05E4\u05E8\u05D5\u05D9\u05E7\u05D8");
        SetTextIfExists(DocumentOptionsTitleTextBlock, "\u05D0\u05E4\u05E9\u05E8\u05D5\u05D9\u05D5\u05EA \u05DE\u05E1\u05DE\u05DA");
        SetTextIfExists(StandardGenerationTitleTextBlock, "\u05D9\u05E6\u05D9\u05E8\u05EA \u05DE\u05E1\u05DE\u05DA");
        SetTextIfExists(AdvancedSettingsTitleTextBlock, "\u05D4\u05D2\u05D3\u05E8\u05D5\u05EA \u05DE\u05EA\u05E7\u05D3\u05DE\u05D5\u05EA");
        SetTextIfExists(ExecutionLogTitleTextBlock, "\u05D9\u05D5\u05DE\u05DF \u05E4\u05E2\u05D5\u05DC\u05D4");

        SetContentIfExists(GenerateButton, "\u05E6\u05D5\u05E8 DOCX + PDF");
        SetContentIfExists(OpenOutputButton, "\u05E4\u05EA\u05D7 Output");
        SetContentIfExists(LoadJsonButton, "\u05D8\u05E2\u05DF JSON");

        TrySetText("Title", "\u05DB\u05D5\u05EA\u05E8\u05EA");
        TrySetText("Project Number", "\u05DE\u05E1\u05E4\u05E8 \u05E4\u05E8\u05D5\u05D9\u05E7\u05D8");
        TrySetText("Sigma P/N", "Sigma P/N");
        TrySetText("Serial Number", "\u05DE\u05E1\u05E4\u05E8 \u05E1\u05D9\u05D3\u05D5\u05E8\u05D9");
        TrySetText("Project Manager", "\u05DE\u05E0\u05D4\u05DC \u05E4\u05E8\u05D5\u05D9\u05E7\u05D8");
        TrySetText("Production Quantity", "\u05DB\u05DE\u05D5\u05EA \u05DC\u05D9\u05D9\u05E6\u05D5\u05E8");
        TrySetText("Revision", "\u05E8\u05D5\u05D5\u05D9\u05D6\u05D9\u05D4");
        TrySetText("Closure Status", "\u05E1\u05D8\u05D8\u05D5\u05E1 \u05E1\u05D2\u05D9\u05E8\u05D4");
        TrySetText("Template Path", "\u05E0\u05EA\u05D9\u05D1 \u05EA\u05D1\u05E0\u05D9\u05EA");
        TrySetText("Output Folder", "\u05EA\u05D9\u05E7\u05D9\u05D9\u05EA \u05E4\u05DC\u05D8");
        TrySetText("JSON Path", "\u05E0\u05EA\u05D9\u05D1 JSON");
        TrySetText("Archive Folder", "\u05EA\u05D9\u05E7\u05D9\u05D9\u05EA \u05D0\u05E8\u05DB\u05D9\u05D5\u05DF");
        TrySetText("Status messages and errors", "\u05D4\u05D5\u05D3\u05E2\u05D5\u05EA \u05DE\u05E6\u05D1 \u05D5\u05E9\u05D2\u05D9\u05D0\u05D5\u05EA");

        TrySetContent("Mechanical Drawing", "\u05E9\u05E8\u05D8\u05D5\u05D8 \u05DE\u05DB\u05E0\u05D9");
        TrySetContent("Electrical Drawing", "\u05E9\u05E8\u05D8\u05D5\u05D8 \u05D7\u05E9\u05DE\u05DC\u05D9");
        TrySetContent("Specification", "\u05DE\u05E4\u05E8\u05D8");
        TrySetContent("Cable Lug Crimp Force Verification", "\u05D1\u05D3\u05D9\u05E7\u05EA \u05DB\u05D5\u05D7 \u05DC\u05D7\u05D9\u05E6\u05D4");
        TrySetContent("FAI", "FAI");
        TrySetContent("Inspector Requirement", "\u05D3\u05E8\u05D9\u05E9\u05EA \u05DE\u05D1\u05E7\u05E8");
        TrySetContent("Automatic Test", "\u05D1\u05D3\u05D9\u05E7\u05D4 \u05D0\u05D5\u05D8\u05D5\u05DE\u05D8\u05D9\u05EA");
        TrySetContent("Additional Requirements", "\u05D3\u05E8\u05D9\u05E9\u05D5\u05EA \u05E0\u05D5\u05E1\u05E4\u05D5\u05EA");

        TrySetGroupBoxHeader("Document Package", "\u05D7\u05D1\u05D9\u05DC\u05EA \u05DE\u05E1\u05DE\u05DB\u05D9\u05DD");
        TrySetComboBoxItem("Full Closure", "FULL");
        TrySetComboBoxItem("Partial Closure", "PARTIAL");
    }

    private void TrySetText(string currentOrOriginalText, string newText)
    {
        foreach (var textBlock in FindVisualChildren<TextBlock>(this))
        {
            if (textBlock.Text == currentOrOriginalText ||
                textBlock.Tag?.ToString() == currentOrOriginalText)
            {
                textBlock.Tag ??= currentOrOriginalText;
                textBlock.Text = newText;
            }
        }
    }

    private void TrySetContent(string currentOrOriginalContent, string newContent)
    {
        foreach (var control in FindVisualChildren<ContentControl>(this))
        {
            var value = control.Content?.ToString();

            if (value == currentOrOriginalContent ||
                control.Tag?.ToString() == currentOrOriginalContent)
            {
                control.Tag ??= currentOrOriginalContent;
                control.Content = newContent;
            }
        }
    }

    private void TrySetGroupBoxHeader(string currentOrOriginalHeader, string newHeader)
    {
        foreach (var groupBox in FindVisualChildren<System.Windows.Controls.GroupBox>(this))
        {
            var value = groupBox.Header?.ToString();

            if (value == currentOrOriginalHeader ||
                groupBox.Tag?.ToString() == currentOrOriginalHeader)
            {
                groupBox.Tag ??= currentOrOriginalHeader;
                groupBox.Header = newHeader;
            }
        }
    }

    private void TrySetComboBoxItem(string currentOrOriginalContent, string newContent)
    {
        foreach (var comboBoxItem in FindVisualChildren<ComboBoxItem>(this))
        {
            var value = comboBoxItem.Content?.ToString();

            if (value == currentOrOriginalContent ||
                comboBoxItem.Tag?.ToString() == currentOrOriginalContent)
            {
                comboBoxItem.Tag ??= currentOrOriginalContent;
                comboBoxItem.Content = newContent;
            }
        }
    }

    private static IEnumerable<T> FindVisualChildren<T>(DependencyObject parent) where T : DependencyObject
    {
        if (parent is null)
            yield break;

        for (int i = 0; i < System.Windows.Media.VisualTreeHelper.GetChildrenCount(parent); i++)
        {
            var child = System.Windows.Media.VisualTreeHelper.GetChild(parent, i);

            if (child is T typedChild)
                yield return typedChild;

            foreach (var descendant in FindVisualChildren<T>(child))
                yield return descendant;
        }
    }
}







