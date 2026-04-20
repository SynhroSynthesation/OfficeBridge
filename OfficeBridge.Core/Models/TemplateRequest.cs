namespace OfficeBridge.Core.Models;

public sealed class TemplateRequest
{
    public string TemplateIdOrPath { get; set; } = string.Empty;
    public Dictionary<string, string> Placeholders { get; set; } = new();
    public string OutputDirectory { get; set; } = string.Empty;
    public string OutputFileName { get; set; } = string.Empty;
}