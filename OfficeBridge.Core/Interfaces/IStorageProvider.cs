using OfficeBridge.Core.Models;

namespace OfficeBridge.Core.Interfaces;

public interface IStorageProvider
{
    Task<DocumentFile> DownloadAsync(string fileIdOrPath, CancellationToken cancellationToken = default);
    Task<DocumentFile> UploadAsync(string localFilePath, string targetFolderId, CancellationToken cancellationToken = default);
    Task<IReadOnlyList<DocumentFile>> SearchAsync(string query, CancellationToken cancellationToken = default);
}