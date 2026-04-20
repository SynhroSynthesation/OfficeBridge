param(
    [string]$Root = (Get-Location).Path
)

$ErrorActionPreference = "Stop"

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

# -----------------------------
# 1. TagProcessModel.cs
# -----------------------------
Write-Utf8File "OfficeBridge.Core\Models\TagProcessModel.cs" @'
namespace OfficeBridge.Core.Models;

public sealed class TagProcessModel
{
    public string Title { get; set; } = string.Empty;
    public string ProjectNumber { get; set; } = string.Empty;
    public string SigmaPn { get; set; } = string.Empty;
    public string SerialNumber { get; set; } = string.Empty;
}
'@

# -----------------------------
# 2. TagProcessPlaceholderMapper.cs
# -----------------------------
Write-Utf8File "OfficeBridge.Infrastructure\Services\TagProcessPlaceholderMapper.cs" @'
using OfficeBridge.Core.Models;

namespace OfficeBridge.Infrastructure.Services;

public static class TagProcessPlaceholderMapper
{
    public static Dictionary<string, string> Map(TagProcessModel model)
    {
        return new Dictionary<string, string>
        {
            ["TITLE"] = model.Title,
            ["PROJECT_NUMBER"] = model.ProjectNumber,
            ["SIGMA_PN"] = model.SigmaPn,
            ["SERIAL_NUMBER"] = model.SerialNumber
        };
    }
}
'@

# -----------------------------
# 3. Program.cs
# -----------------------------
Write-Utf8File "OfficeBridge.App\Program.cs" @'
using OfficeBridge.Core.Models;
using OfficeBridge.Infrastructure.Office;
using OfficeBridge.Infrastructure.Services;
using OfficeBridge.Infrastructure.Storage;
using OfficeBridge.TemplateEngine.Docx;

var templateEngine = new DocxTemplateEngine();
var storage = new LocalStorageProvider();

var sofficePath = @"C:\Program Files\LibreOffice\program\soffice.exe";
var officeProvider = new LibreOfficeProvider(sofficePath);

var workflow = new DocumentWorkflowService(storage, templateEngine, officeProvider);

var templatePath = @"C:\Users\myclu\OneDrive\Рабочий стол\SOFTWARE\Fast_Tag-process\TAG-procees(2).docx";
var outputDir = @"C:\Users\myclu\OneDrive\Рабочий стол\SOFTWARE\Fast_Tag-process\Output";
var archiveDir = @"C:\Users\myclu\OneDrive\Рабочий стол\SOFTWARE\Fast_Tag-process\Archive";

Console.WriteLine("OfficeBridge bootstrap started...");
Console.WriteLine($"Template: {templatePath}");

if (!File.Exists(templatePath))
{
    Console.WriteLine("Шаблон не найден.");
    Console.WriteLine("Проверьте путь:");
    Console.WriteLine(templatePath);
    return;
}

var model = new TagProcessModel
{
    Title = "Control Box Assembly",
    ProjectNumber = "PRJ-4587",
    SigmaPn = "SIG-BOX-001",
    SerialNumber = "SN-2026-001"
};

var request = new TemplateRequest
{
    TemplateIdOrPath = templatePath,
    OutputDirectory = outputDir,
    OutputFileName = "TAG-process-filled.docx",
    Placeholders = TagProcessPlaceholderMapper.Map(model)
};

try
{
    var result = await workflow.GenerateAsync(request, archiveDir);

    Console.WriteLine($"DOCX: {result.docxPath}");
    Console.WriteLine($"PDF : {result.pdfPath}");
}
catch (Exception ex)
{
    Console.WriteLine("Error:");
    Console.WriteLine(ex.Message);
}
'@

Write-Host ""
Write-Host "Done." -ForegroundColor Cyan
Write-Host "Next commands:" -ForegroundColor Yellow
Write-Host "dotnet build"
Write-Host "dotnet run --project OfficeBridge.App"