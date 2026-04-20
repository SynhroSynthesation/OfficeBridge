using OfficeBridge.Core.Interfaces;
using OfficeBridge.Core.Models;

namespace OfficeBridge.Infrastructure.Storage;

public sealed class LocalStorageProvider : IStorageProvider
{
    public Task<DocumentFile> DownloadAsync(
        string fileIdOrPath,
        CancellationToken cancellationToken = default)
    {
        if (!File.Exists(fileIdOrPath))
            throw new FileNotFoundException("Локальный файл не найден.", fileIdOrPath);

        var file = new DocumentFile
        {
            FileId = fileIdOrPath,
            FileName = Path.GetFileName(fileIdOrPath),
            LocalPath = fileIdOrPath,
            MimeType = string.Empty,
            IsTemporary = false
        };

        return Task.FromResult(file);
    }

    public Task<DocumentFile> UploadAsync(
        string localFilePath,
        string targetFolderId,
        CancellationToken cancellationToken = default)
    {
        if (!File.Exists(localFilePath))
            throw new FileNotFoundException("Файл для сохранения не найден.", localFilePath);

        Directory.CreateDirectory(targetFolderId);

        var targetPath = Path.Combine(targetFolderId, Path.GetFileName(localFilePath));

        File.Copy(localFilePath, targetPath, true);

        var file = new DocumentFile
        {
            FileId = targetPath,
            FileName = Path.GetFileName(targetPath),
            LocalPath = targetPath,
            MimeType = string.Empty,
            IsTemporary = false
        };

        return Task.FromResult(file);
    }

    public Task<IReadOnlyList<DocumentFile>> SearchAsync(
        string query,
        CancellationToken cancellationToken = default)
    {
        IReadOnlyList<DocumentFile> result = Array.Empty<DocumentFile>();
        return Task.FromResult(result);
    }
}