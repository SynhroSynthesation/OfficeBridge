namespace OfficeBridge.Core.Models;

public sealed class DocumentFile
{
    public string FileId { get; set; } = string.Empty;
    public string FileName { get; set; } = string.Empty;
    public string LocalPath { get; set; } = string.Empty;
    public string MimeType { get; set; } = string.Empty;
    public bool IsTemporary { get; set; }
}