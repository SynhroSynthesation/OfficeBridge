using System.Threading;
using System.Threading.Tasks;
using OfficeBridge.Core.Interfaces;

namespace OfficeBridge.Infrastructure.Office;

public sealed class MicrosoftOfficeProvider : IOfficeProvider
{
    public string Name => "MicrosoftOffice";

    public bool IsAvailable()
    {
        return false;
    }

    public Task OpenAsync(
        string filePath,
        CancellationToken cancellationToken = default)
    {
        throw new NotImplementedException(
            "Microsoft Office provider is not implemented yet.");
    }

    public Task ExportToPdfAsync(
        string inputPath,
        string outputPdfPath,
        CancellationToken cancellationToken = default)
    {
        throw new NotImplementedException(
            "Microsoft Office PDF export is not implemented yet.");
    }
}