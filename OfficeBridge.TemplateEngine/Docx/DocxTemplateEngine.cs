using DocumentFormat.OpenXml;
using DocumentFormat.OpenXml.Packaging;
using DocumentFormat.OpenXml.Wordprocessing;
using OfficeBridge.Core.Interfaces;

namespace OfficeBridge.TemplateEngine.Docx;

public sealed class DocxTemplateEngine : ITemplateEngine
{
    public Task<string> FillTemplateAsync(
        string templatePath,
        Dictionary<string, string> placeholders,
        string outputPath,
        CancellationToken cancellationToken = default)
    {
        if (!File.Exists(templatePath))
            throw new FileNotFoundException("Шаблон не найден.", templatePath);

        var outputDir = Path.GetDirectoryName(outputPath)
            ?? throw new InvalidOperationException("Не удалось определить папку для выходного файла.");

        Directory.CreateDirectory(outputDir);
        File.Copy(templatePath, outputPath, true);

        using var document = WordprocessingDocument.Open(outputPath, true);

        ReplaceInMainDocument(document, placeholders);
        ReplaceInHeaders(document, placeholders);
        ReplaceInFooters(document, placeholders);

        return Task.FromResult(outputPath);
    }

    private static void ReplaceInMainDocument(
        WordprocessingDocument document,
        Dictionary<string, string> placeholders)
    {
        var mainPart = document.MainDocumentPart
            ?? throw new InvalidOperationException("У документа отсутствует MainDocumentPart.");

        ReplaceInOpenXmlElement(mainPart.Document, placeholders);
        mainPart.Document.Save();
    }

    private static void ReplaceInHeaders(
        WordprocessingDocument document,
        Dictionary<string, string> placeholders)
    {
        var mainPart = document.MainDocumentPart;
        if (mainPart is null)
            return;

        foreach (var headerPart in mainPart.HeaderParts)
        {
            if (headerPart.Header is null)
                continue;

            ReplaceInOpenXmlElement(headerPart.Header, placeholders);
            headerPart.Header.Save();
        }
    }

    private static void ReplaceInFooters(
        WordprocessingDocument document,
        Dictionary<string, string> placeholders)
    {
        var mainPart = document.MainDocumentPart;
        if (mainPart is null)
            return;

        foreach (var footerPart in mainPart.FooterParts)
        {
            if (footerPart.Footer is null)
                continue;

            ReplaceInOpenXmlElement(footerPart.Footer, placeholders);
            footerPart.Footer.Save();
        }
    }

    private static void ReplaceInOpenXmlElement(
        OpenXmlElement root,
        Dictionary<string, string> placeholders)
    {
        var paragraphs = root.Descendants<Paragraph>().ToList();

        foreach (var paragraph in paragraphs)
        {
            ReplaceInParagraph(paragraph, placeholders);
        }
    }

    private static void ReplaceInParagraph(
        Paragraph paragraph,
        Dictionary<string, string> placeholders)
    {
        var textElements = paragraph.Descendants<Text>().ToList();
        if (textElements.Count == 0)
            return;

        var fullText = string.Concat(textElements.Select(t => t.Text));
        if (string.IsNullOrEmpty(fullText))
            return;

        var updatedText = fullText;

        foreach (var pair in placeholders)
        {
            string token = "{{" + pair.Key + "}}";
            updatedText = updatedText.Replace(
                token,
                pair.Value ?? string.Empty,
                StringComparison.Ordinal);
        }

        if (updatedText == fullText)
            return;

        textElements[0].Text = updatedText;

        for (int i = 1; i < textElements.Count; i++)
        {
            textElements[i].Text = string.Empty;
        }
    }
}