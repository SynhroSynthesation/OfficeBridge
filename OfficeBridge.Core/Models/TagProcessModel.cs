namespace OfficeBridge.Core.Models;

public sealed class TagProcessModel
{
    public string Title { get; set; } = string.Empty;
    public string ProjectNumber { get; set; } = string.Empty;
    public string SigmaPn { get; set; } = string.Empty;
    public string SerialNumber { get; set; } = string.Empty;

    public string ProjectManager { get; set; } = string.Empty;
    public string ProductionQuantity { get; set; } = string.Empty;
    public string Revision { get; set; } = string.Empty;
    public string ClosureStatus { get; set; } = string.Empty;

    public bool IncludeMechanicalDrawing { get; set; }
    public bool IncludeElectricalDrawing { get; set; }
    public bool IncludeSpecification { get; set; }
    public bool IncludeCableCrimpVerification { get; set; }
    public bool IncludeFai { get; set; }
    public bool IncludeInspectorRequirement { get; set; }
    public bool IncludeAutomaticTest { get; set; }
    public bool IncludeAdditionalRequirements { get; set; }

    public string AdditionalRequirementsText { get; set; } = string.Empty;
}