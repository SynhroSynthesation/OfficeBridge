using System.Threading;
using System.Threading.Tasks;

namespace OfficeBridge.Core.Interfaces;

public interface IOfficeProvider
{
    string Name { get; }

    bool IsAvailable();

    Task OpenAsync(
        string filePath,
        CancellationToken cancellationToken = default);

    Task ExportToPdfAsync(
        string inputPath,
        string outputPdfPath,
        CancellationToken cancellationToken = default);
}