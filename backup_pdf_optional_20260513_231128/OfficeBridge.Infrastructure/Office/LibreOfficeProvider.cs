using System.Diagnostics;
using System.Threading;
using System.Threading.Tasks;
using OfficeBridge.Core.Interfaces;

namespace OfficeBridge.Infrastructure.Office;

public sealed class LibreOfficeProvider : IOfficeProvider
{
    public string Name => "LibreOffice";

    private readonly string _sofficePath;

    public LibreOfficeProvider(string sofficePath)
    {
        _sofficePath = sofficePath;
    }

    public bool IsAvailable()
    {
        return File.Exists(_sofficePath);
    }

    public Task OpenAsync(
        string filePath,
        CancellationToken cancellationToken = default)
    {
        if (!File.Exists(filePath))
            throw new FileNotFoundException("Файл не найден.", filePath);

        if (!File.Exists(_sofficePath))
            throw new FileNotFoundException("LibreOffice (soffice.exe) не найден.", _sofficePath);

        Process.Start(new ProcessStartInfo
        {
            FileName = _sofficePath,
            Arguments = $"\"{filePath}\"",
            UseShellExecute = true
        });

        return Task.CompletedTask;
    }

    public async Task ExportToPdfAsync(
        string inputPath,
        string outputPdfPath,
        CancellationToken cancellationToken = default)
    {
        if (!File.Exists(inputPath))
            throw new FileNotFoundException("Исходный файл не найден.", inputPath);

        if (!File.Exists(_sofficePath))
            throw new FileNotFoundException("LibreOffice (soffice.exe) не найден.", _sofficePath);

        var outputDir = Path.GetDirectoryName(outputPdfPath)
            ?? throw new InvalidOperationException("Не удалось определить папку вывода.");

        Directory.CreateDirectory(outputDir);

        var psi = new ProcessStartInfo
        {
            FileName = _sofficePath,
            Arguments = $"--headless --convert-to pdf --outdir \"{outputDir}\" \"{inputPath}\"",
            RedirectStandardOutput = true,
            RedirectStandardError = true,
            UseShellExecute = false,
            CreateNoWindow = true
        };

        using var process = new Process
        {
            StartInfo = psi
        };

        process.Start();

        string stdOut = await process.StandardOutput.ReadToEndAsync(cancellationToken);
        string stdErr = await process.StandardError.ReadToEndAsync(cancellationToken);

        await process.WaitForExitAsync(cancellationToken);

        if (process.ExitCode != 0)
        {
            throw new InvalidOperationException(
                $"Ошибка конвертации LibreOffice. Code={process.ExitCode}\nOUT:{stdOut}\nERR:{stdErr}");
        }

        var producedPdf = Path.Combine(
            outputDir,
            Path.GetFileNameWithoutExtension(inputPath) + ".pdf");

        if (!File.Exists(producedPdf))
            throw new FileNotFoundException("LibreOffice не создал PDF.", producedPdf);

        if (!string.Equals(producedPdf, outputPdfPath, StringComparison.OrdinalIgnoreCase))
        {
            File.Copy(producedPdf, outputPdfPath, true);
        }
    }
}