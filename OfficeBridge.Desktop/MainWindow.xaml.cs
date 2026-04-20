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
using Forms = System.Windows.Forms;
using MessageBox = System.Windows.MessageBox;
using OpenFileDialog = Microsoft.Win32.OpenFileDialog;

namespace OfficeBridge.Desktop;

public partial class MainWindow : Window
{
    public MainWindow()
    {
        InitializeComponent();
        InitializeDefaults();
    }

    private void InitializeDefaults()
    {
        var solutionRoot = Directory.GetCurrentDirectory();
        var root = Path.GetFullPath(Path.Combine(solutionRoot, ".."));

        TemplatePathTextBox.Text = Path.Combine(root, "TAG-procees.docx");
        JsonPathTextBox.Text = Path.Combine(solutionRoot, "OfficeBridge.App", "Data", "tagprocess.sample.json");
        OutputFolderTextBox.Text = Path.Combine(root, "Output");
        ArchiveFolderTextBox.Text = Path.Combine(root, "Archive");

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


    }

    private void AppendLog(string message)
    {
        LogTextBox.AppendText($"[{DateTime.Now:HH:mm:ss}] {message}{Environment.NewLine}");
        LogTextBox.ScrollToEnd();
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
            var templatePath = TemplatePathTextBox.Text.Trim();
            var outputDir = OutputFolderTextBox.Text.Trim();
            var archiveDir = ArchiveFolderTextBox.Text.Trim();

            if (!File.Exists(templatePath))
            {
                MessageBox.Show("Template file was not found.", "Error", MessageBoxButton.OK, MessageBoxImage.Error);
                return;
            }

            Directory.CreateDirectory(outputDir);
            Directory.CreateDirectory(archiveDir);

            var model = BuildModelFromUi();

            var safeProjectNumber = MakeSafeFileName(model.ProjectNumber);
            var safeSerialNumber = MakeSafeFileName(model.SerialNumber);

            var outputFileName =
                $"TAG_{safeProjectNumber}_{safeSerialNumber}_{DateTime.Now:yyyyMMdd_HHmmss}.docx";

            var templateEngine = new DocxTemplateEngine();
            var storage = new LocalStorageProvider();

            var sofficePath = @"C:\Program Files\LibreOffice\program\soffice.exe";
            var officeProvider = new LibreOfficeProvider(sofficePath);

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
            AppendLog($"PDF : {result.pdfPath}");

            MessageBox.Show("Documents were created successfully.", "Done", MessageBoxButton.OK, MessageBoxImage.Information);
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
}