param(
    [string]$Root = (Get-Location).Path
)

$ErrorActionPreference = "Stop"

# ---------------------------------
# Force UTF-8 for console and files
# ---------------------------------
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

    $utf8NoBom = [System.Text.UTF8Encoding]::new($false)
    [System.IO.File]::WriteAllText($fullPath, $content, $utf8NoBom)

    Write-Host "Created: $fullPath" -ForegroundColor Green
}

# ---------------------------------
# 1. Create sample json
# ---------------------------------
Write-Utf8File "OfficeBridge.App\Data\tagprocess.sample.json" @'
{
  "Title": "Control Box Assembly",
  "ProjectNumber": "PRJ-4587",
  "SigmaPn": "SIG-BOX-001",
  "SerialNumber": "SN-2026-001"
}
'@

# ---------------------------------
# 2. Replace Program.cs
# ---------------------------------
Write-Utf8File "OfficeBridge.App\Program.cs" @'
using System.Text;
using System.Text.Json;
using OfficeBridge.Core.Models;
using OfficeBridge.Infrastructure.Office;
using OfficeBridge.Infrastructure.Services;
using OfficeBridge.Infrastructure.Storage;
using OfficeBridge.TemplateEngine.Docx;

Console.OutputEncoding = Encoding.UTF8;

var templateEngine = new DocxTemplateEngine();
var storage = new LocalStorageProvider();

var sofficePath = @"C:\Program Files\LibreOffice\program\soffice.exe";
var officeProvider = new LibreOfficeProvider(sofficePath);

var workflow = new DocumentWorkflowService(storage, templateEngine, officeProvider);

var solutionRoot = Directory.GetCurrentDirectory();
var templatePath = Path.GetFullPath(Path.Combine(solutionRoot, "..", "TAG-procees(2).docx"));
var outputDir = Path.GetFullPath(Path.Combine(solutionRoot, "..", "Output"));
var archiveDir = Path.GetFullPath(Path.Combine(solutionRoot, "..", "Archive"));
var jsonPath = Path.Combine(solutionRoot, "OfficeBridge.App", "Data", "tagprocess.sample.json");

Console.WriteLine("OfficeBridge bootstrap started...");
Console.WriteLine($"Template: {templatePath}");
Console.WriteLine($"JSON    : {jsonPath}");

if (!File.Exists(templatePath))
{
    Console.WriteLine("Шаблон не найден.");
    Console.WriteLine("Проверьте путь:");
    Console.WriteLine(templatePath);
    return;
}

if (!File.Exists(jsonPath))
{
    Console.WriteLine("JSON файл не найден.");
    Console.WriteLine("Проверьте путь:");
    Console.WriteLine(jsonPath);
    return;
}

TagProcessModel? model;

try
{
    var json = await File.ReadAllTextAsync(jsonPath);
    model = JsonSerializer.Deserialize<TagProcessModel>(json, new JsonSerializerOptions
    {
        PropertyNameCaseInsensitive = true
    });

    if (model is null)
    {
        Console.WriteLine("Не удалось десериализовать JSON в TagProcessModel.");
        return;
    }
}
catch (Exception ex)
{
    Console.WriteLine("Ошибка чтения JSON:");
    Console.WriteLine(ex.ToString());
    return;
}

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
    Console.WriteLine("Ошибка:");
    Console.WriteLine(ex.ToString());
}
'@

Write-Host ""
Write-Host "Done." -ForegroundColor Cyan
Write-Host "Next commands:" -ForegroundColor Yellow
Write-Host "dotnet build"
Write-Host "dotnet run --project OfficeBridge.App"