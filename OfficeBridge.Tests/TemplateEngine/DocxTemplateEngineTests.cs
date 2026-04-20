using FluentAssertions;
using OfficeBridge.TemplateEngine.Docx;

namespace OfficeBridge.Tests.TemplateEngine;

public sealed class DocxTemplateEngineTests
{
    [Fact]
    public void Placeholder_test_stub_should_pass()
    {
        var engine = new DocxTemplateEngine();
        engine.Should().NotBeNull();
    }
}