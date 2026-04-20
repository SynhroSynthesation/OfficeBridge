using OfficeBridge.Core.Models;

namespace OfficeBridge.Infrastructure.Services;

public static class TagProcessPlaceholderMapper
{
    public static Dictionary<string, string> Map(TagProcessModel model)
    {
        return new Dictionary<string, string>
        {
            ["TITLE"] = model.Title,
            ["PROJECT_NUMBER"] = model.ProjectNumber,
            ["SIGMA_PN"] = model.SigmaPn,
            ["SERIAL_NUMBER"] = model.SerialNumber,

            ["PROJECT_MANAGER"] = model.ProjectManager,
            ["PRODUCTION_QUANTITY"] = model.ProductionQuantity,
            ["REVISION"] = model.Revision,
            ["CLOSURE_STATUS"] = model.ClosureStatus,

            ["MECHANICAL_DRAWING"] = model.IncludeMechanicalDrawing ? "Mechanical Drawing" : string.Empty,
            ["ELECTRICAL_DRAWING"] = model.IncludeElectricalDrawing ? "Electrical Drawing" : string.Empty,
            ["SPECIFICATION"] = model.IncludeSpecification ? "Specification" : string.Empty,
            ["CABLE_CRIMP_VERIFICATION"] = model.IncludeCableCrimpVerification ? "Cable Lug Crimp Force Verification" : string.Empty,
            ["FAI"] = model.IncludeFai ? "FAI" : string.Empty,
            ["INSPECTOR_REQUIREMENT"] = model.IncludeInspectorRequirement ? "Inspector Requirement" : string.Empty,
            ["AUTOMATIC_TEST"] = model.IncludeAutomaticTest ? "Automatic Test" : string.Empty,
            ["ADDITIONAL_REQUIREMENTS"] = model.IncludeAdditionalRequirements ? "Additional Requirements" : string.Empty,
        };
    }
}