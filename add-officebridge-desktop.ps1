param(
    [string]$Root = (Get-Location).Path
)

$ErrorActionPreference = "Stop"

[Console]::InputEncoding = [System.Text.UTF8Encoding]::new($false)
[Console]::OutputEncoding = [System.Text.UTF8Encoding]::new($false)
$OutputEncoding = [System.Text.UTF8Encoding]::new($false)
chcp 65001 | Out-Null

function Ensure-Dir($path) {
    if (-not (Test-Path $path)) {
        New-Item -ItemType Directory -Path $path -Force | Out-Null
    }
}

function Write-Utf8File($path, $content) {
    $fullPath = [System.IO.Path]::GetFullPath((Join-Path $Root $path))
    $dir = Split-Path $fullPath -Parent
    Ensure-Dir $dir
    [System.IO.File]::WriteAllText($fullPath, $content, [System.Text.UTF8Encoding]::new($false))
    Write-Host "Created: $fullPath" -ForegroundColor Green
}

Set-Location $Root

# ---------------------------------
# 1. Create WPF project if missing
# ---------------------------------
if (-not (Test-Path ".\OfficeBridge.Desktop\OfficeBridge.Desktop.csproj")) {
    dotnet new wpf -n OfficeBridge.Desktop -f net9.0
}

# ---------------------------------
# 2. Add to solution
# ---------------------------------
if (-not ((dotnet sln list) -like "*OfficeBridge.Desktop\OfficeBridge.Desktop.csproj*")) {
    dotnet sln add ".\OfficeBridge.Desktop\OfficeBridge.Desktop.csproj"
}

# ---------------------------------
# 3. Add project references
# ---------------------------------
dotnet add ".\OfficeBridge.Desktop\OfficeBridge.Desktop.csproj" reference `
    ".\OfficeBridge.Core\OfficeBridge.Core.csproj" `
    ".\OfficeBridge.Infrastructure\OfficeBridge.Infrastructure.csproj" `
    ".\OfficeBridge.TemplateEngine\OfficeBridge.TemplateEngine.csproj"

# ---------------------------------
# 4. Create folders
# ---------------------------------
Ensure-Dir ".\OfficeBridge.Desktop\Models"
Ensure-Dir ".\OfficeBridge.Desktop\Services"

# ---------------------------------
# 5. App.xaml
# ---------------------------------
Write-Utf8File "OfficeBridge.Desktop\App.xaml" @'
<Application x:Class="OfficeBridge.Desktop.App"
             xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
             xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
             StartupUri="MainWindow.xaml">
    <Application.Resources>
    </Application.Resources>
</Application>
'@

# ---------------------------------
# 6. MainWindow.xaml
# ---------------------------------
Write-Utf8File "OfficeBridge.Desktop\MainWindow.xaml" @'
<Window x:Class="OfficeBridge.Desktop.MainWindow"
        xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
        xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
        xmlns:d="http://schemas.microsoft.com/expression/blend/2008"
        xmlns:mc="http://schemas.openxmlformats.org/markup-compatibility/2006"
        mc:Ignorable="d"
        Title="OfficeBridge Desktop"
        Height="720"
        Width="1100"
        MinHeight="620"
        MinWidth="900"
        WindowStartupLocation="CenterScreen">
    <Grid Margin="12">
        <Grid.ColumnDefinitions>
            <ColumnDefinition Width="2*" />
            <ColumnDefinition Width="14" />
            <ColumnDefinition Width="3*" />
        </Grid.ColumnDefinitions>

        <Border Grid.Column="0"
                Padding="14"
                BorderBrush="#DDD"
                BorderThickness="1"
                CornerRadius="8">
            <ScrollViewer VerticalScrollBarVisibility="Auto">
                <StackPanel>
                    <TextBlock Text="Генерация TAG Process"
                               FontSize="22"
                               FontWeight="SemiBold"
                               Margin="0,0,0,16"/>

                    <TextBlock Text="Title"/>
                    <TextBox x:Name="TitleTextBox" Margin="0,4,0,12" Height="30"/>

                    <TextBlock Text="Project Number"/>
                    <TextBox x:Name="ProjectNumberTextBox" Margin="0,4,0,12" Height="30"/>

                    <TextBlock Text="Sigma P/N"/>
                    <TextBox x:Name="SigmaPnTextBox" Margin="0,4,0,12" Height="30"/>

                    <TextBlock Text="Serial Number"/>
                    <TextBox x:Name="SerialNumberTextBox" Margin="0,4,0,12" Height="30"/>

                    <Separator Margin="0,8,0,12"/>

                    <TextBlock Text="Template Path"/>
                    <DockPanel Margin="0,4,0,12">
                        <Button x:Name="BrowseTemplateButton"
                                Content="..."
                                Width="36"
                                Margin="8,0,0,0"
                                DockPanel.Dock="Right"
                                Click="BrowseTemplateButton_Click"/>
                        <TextBox x:Name="TemplatePathTextBox" Height="30"/>
                    </DockPanel>

                    <TextBlock Text="JSON Path"/>
                    <DockPanel Margin="0,4,0,12">
                        <Button x:Name="BrowseJsonButton"
                                Content="..."
                                Width="36"
                                Margin="8,0,0,0"
                                DockPanel.Dock="Right"
                                Click="BrowseJsonButton_Click"/>
                        <TextBox x:Name="JsonPathTextBox" Height="30"/>
                    </DockPanel>

                    <TextBlock Text="Output Folder"/>
                    <DockPanel Margin="0,4,0,12">
                        <Button x:Name="BrowseOutputButton"
                                Content="..."
                                Width="36"
                                Margin="8,0,0,0"
                                DockPanel.Dock="Right"
                                Click="BrowseOutputButton_Click"/>
                        <TextBox x:Name="OutputFolderTextBox" Height="30"/>
                    </DockPanel>

                    <TextBlock Text="Archive Folder"/>
                    <DockPanel Margin="0,4,0,20">
                        <Button x:Name="BrowseArchiveButton"
                                Content="..."
                                Width="36"
                                Margin="8,0,0,0"
                                DockPanel.Dock="Right"
                                Click="BrowseArchiveButton_Click"/>
                        <TextBox x:Name="ArchiveFolderTextBox" Height="30"/>
                    </DockPanel>

                    <WrapPanel>
                        <Button x:Name="LoadJsonButton"
                                Content="Загрузить JSON"
                                Width="140"
                                Height="34"
                                Margin="0,0,8,8"
                                Click="LoadJsonButton_Click"/>

                        <Button x:Name="GenerateButton"
                                Content="Сгенерировать DOCX + PDF"
                                Width="220"
                                Height="34"
                                Margin="0,0,8,8"
                                Click="GenerateButton_Click"/>

                        <Button x:Name="OpenOutputButton"
                                Content="Открыть Output"
                                Width="130"
                                Height="34"
                                Margin="0,0,8,8"
                                Click="OpenOutputButton_Click"/>
                    </WrapPanel>
                </StackPanel>
            </ScrollViewer>
        </Border>

        <Border Grid.Column="2"
                Padding="14"
                BorderBrush="#DDD"
                BorderThickness="1"
                CornerRadius="8">
            <Grid>
                <Grid.RowDefinitions>
                    <RowDefinition Height="Auto"/>
                    <RowDefinition Height="10"/>
                    <RowDefinition Height="*"/>
                </Grid.RowDefinitions>

                <TextBlock Text="Лог"
                           FontSize="18"
                           FontWeight="SemiBold"/>

                <TextBox Grid.Row="2"
                         x:Name="LogTextBox"
                         IsReadOnly="True"
                         TextWrapping="Wrap"
                         VerticalScrollBarVisibility="Auto"
                         HorizontalScrollBarVisibility="Auto"
                         AcceptsReturn="True"
                         FontFamily="Consolas"/>
            </Grid>
        </Border>
    </Grid>
</Window>
'@

# ---------------------------------
# 7. MainWindow.xaml.cs
# ---------------------------------
Write-Utf8File "OfficeBridge.Desktop\MainWindow.xaml.cs" @'
using System.Diagnostics;
using System.Text.Json;
using System.Windows;
using Microsoft.Win32;
using OfficeBridge.Core.Models;
using OfficeBridge.Infrastructure.Office;
using OfficeBridge.Infrastructure.Services;
using OfficeBridge.Infrastructure.Storage;
using OfficeBridge.TemplateEngine.Docx;
using Forms = System.Windows.Forms;

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

        TemplatePathTextBox.Text = Path.Combine(root, "TAG-procees(2).docx");
        JsonPathTextBox.Text = Path.Combine(solutionRoot, "OfficeBridge.App", "Data", "tagprocess.sample.json");
        OutputFolderTextBox.Text = Path.Combine(root, "Output");
        ArchiveFolderTextBox.Text = Path.Combine(root, "Archive");

        TitleTextBox.Text = "Control Box Assembly";
        ProjectNumberTextBox.Text = "PRJ-4587";
        SigmaPnTextBox.Text = "SIG-BOX-001";
        SerialNumberTextBox.Text = "SN-2026-001";
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
            SerialNumber = SerialNumberTextBox.Text.Trim()
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
                MessageBox.Show("Шаблон не найден.", "Ошибка", MessageBoxButton.OK, MessageBoxImage.Error);
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

            AppendLog("Старт генерации...");
            AppendLog($"Template: {templatePath}");

            var result = await workflow.GenerateAsync(request, archiveDir);

            AppendLog($"DOCX: {result.docxPath}");
            AppendLog($"PDF : {result.pdfPath}");

            MessageBox.Show("Документы успешно созданы.", "Готово", MessageBoxButton.OK, MessageBoxImage.Information);
        }
        catch (Exception ex)
        {
            AppendLog("Ошибка:");
            AppendLog(ex.ToString());
            MessageBox.Show(ex.Message, "Ошибка", MessageBoxButton.OK, MessageBoxImage.Error);
        }
    }

    private void LoadJsonButton_Click(object sender, RoutedEventArgs e)
    {
        try
        {
            var jsonPath = JsonPathTextBox.Text.Trim();

            if (!File.Exists(jsonPath))
            {
                MessageBox.Show("JSON файл не найден.", "Ошибка", MessageBoxButton.OK, MessageBoxImage.Error);
                return;
            }

            var json = File.ReadAllText(jsonPath);
            var model = JsonSerializer.Deserialize<TagProcessModel>(json, new JsonSerializerOptions
            {
                PropertyNameCaseInsensitive = true
            });

            if (model is null)
            {
                MessageBox.Show("Не удалось прочитать JSON.", "Ошибка", MessageBoxButton.OK, MessageBoxImage.Error);
                return;
            }

            TitleTextBox.Text = model.Title;
            ProjectNumberTextBox.Text = model.ProjectNumber;
            SigmaPnTextBox.Text = model.SigmaPn;
            SerialNumberTextBox.Text = model.SerialNumber;

            AppendLog($"JSON загружен: {jsonPath}");
        }
        catch (Exception ex)
        {
            AppendLog(ex.ToString());
            MessageBox.Show(ex.Message, "Ошибка", MessageBoxButton.OK, MessageBoxImage.Error);
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
            MessageBox.Show("Папка Output не найдена.", "Ошибка", MessageBoxButton.OK, MessageBoxImage.Error);
            return;
        }

        Process.Start(new ProcessStartInfo
        {
            FileName = path,
            UseShellExecute = true
        });
    }
}
'@

# ---------------------------------
# 8. Ensure Windows Forms enabled
# ---------------------------------
$csprojPath = ".\OfficeBridge.Desktop\OfficeBridge.Desktop.csproj"
$csproj = Get-Content $csprojPath -Raw

if ($csproj -notmatch "<UseWindowsForms>true</UseWindowsForms>") {
    $csproj = $csproj -replace "</PropertyGroup>", "  <UseWindowsForms>true</UseWindowsForms>`r`n  </PropertyGroup>"
    [System.IO.File]::WriteAllText((Resolve-Path $csprojPath), $csproj, [System.Text.UTF8Encoding]::new($false))
}

Write-Host ""
Write-Host "Done." -ForegroundColor Cyan
Write-Host "Next commands:" -ForegroundColor Yellow
Write-Host "dotnet build"
Write-Host "dotnet run --project .\OfficeBridge.Desktop"