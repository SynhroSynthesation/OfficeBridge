namespace OfficeBridge.Core.Interfaces;

public interface ITemplateEngine
{
    Task<string> FillTemplateAsync(
        string templatePath,
        Dictionary<string, string> placeholders,
        string outputPath,
        CancellationToken cancellationToken = default);
}