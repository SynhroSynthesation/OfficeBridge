using OfficeBridge.Core.Interfaces;
using OfficeBridge.Core.Models;

namespace OfficeBridge.Infrastructure.Services;

public sealed class DocumentWorkflowService
{
    private readonly IStorageProvider _storageProvider;
    private readonly ITemplateEngine _templateEngine;
    private readonly IOfficeProvider _officeProvider;

    public DocumentWorkflowService(
        IStorageProvider storageProvider,
        ITemplateEngine templateEngine,
        IOfficeProvider officeProvider)
    {
        _storageProvider = storageProvider;
        _templateEngine = templateEngine;
        _officeProvider = officeProvider;
    }

    public async Task<(string docxPath, string pdfPath)> GenerateAsync(
        TemplateRequest request,
        string targetFolderId,
        CancellationToken cancellationToken = default)
    {
        var sourceFile = await _storageProvider.DownloadAsync(
            request.TemplateIdOrPath,
            cancellationToken);

        string outputDocx = Path.Combine(
            request.OutputDirectory,
            request.OutputFileName);

        string outputPdf = Path.ChangeExtension(outputDocx, ".pdf")!;

        await _templateEngine.FillTemplateAsync(
            sourceFile.LocalPath,
            request.Placeholders,
            outputDocx,
            cancellationToken);

        if (_officeProvider.IsAvailable())
        {
            try
            {
                if (_officeProvider.IsAvailable())
                {
                    await _officeProvider.ExportToPdfAsync(
                        outputDocx,
                        outputPdf,
                        cancellationToken);
                }
            }
            catch
            {
                // PDF export is optional.
                // DOCX generation must remain successful even if LibreOffice is missing
                // or PDF conversion fails.
            }
        }

        if (!string.IsNullOrWhiteSpace(targetFolderId))
        {
            await _storageProvider.UploadAsync(
                outputDocx,
                targetFolderId,
                cancellationToken);

            if (File.Exists(outputPdf))
            {
                await _storageProvider.UploadAsync(
                    outputPdf,
                    targetFolderId,
                    cancellationToken);
            }
        }

        return (outputDocx, outputPdf);
    }
}