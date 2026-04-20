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
var templatePath = Path.GetFullPath(Path.Combine(solutionRoot, "..", "TAG-procees.docx"));
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

var safeProjectNumber = string.Concat(
    model.ProjectNumber.Where(c => !Path.GetInvalidFileNameChars().Contains(c)));

var safeSerialNumber = string.Concat(
    model.SerialNumber.Where(c => !Path.GetInvalidFileNameChars().Contains(c)));
var title = string.Concat(
    model.Title.Where(c => !Path.GetInvalidFileNameChars().Contains(c)));
var partNumber = string.Concat(
    model.SigmaPn.Where(c => !Path.GetInvalidFileNameChars().Contains(c)));

var outputFileName =
    $"TAG_{partNumber}_{title}_{safeSerialNumber}_{DateTime.Now:yyyyMMdd_HHmmss}.docx";

var request = new TemplateRequest
{
    TemplateIdOrPath = templatePath,
    OutputDirectory = outputDir,
    OutputFileName = outputFileName,
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