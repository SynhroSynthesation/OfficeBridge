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
            ["SPECIFICATION"] = model.IncludeSpecification ? "PART LIST" : string.Empty,
            ["CABLE_CRIMP_VERIFICATION"] = model.IncludeCableCrimpVerification ? "PULL TEST" : string.Empty,
            ["FAI"] = model.IncludeFai ? "FAI" : string.Empty,
            
            ["PART_LIST"] = model.IncludePartList || model.IncludeSpecification ? "PART LIST" : string.Empty,
            ["DATASHEETS"] = model.IncludeDatasheets ? "DATASHEETS" : string.Empty,
            ["PICTURES"] = model.IncludePictures ? "Pictures" : string.Empty,

            ["PULL_TEST"] = model.IncludePullTest || model.IncludeCableCrimpVerification ? "PULL TEST" : string.Empty,
            ["FAI2"] = model.IncludeFai2 ? "FAI2" : string.Empty,
            ["FAI3"] = model.IncludeFai3 ? "FAI3" : string.Empty,
            ["EXTERNAL_ELECTRICAL_TEST"] = model.IncludeExternalElectricalTest ? "External Electrical TEST" : string.Empty,["INSPECTOR_REQUIREMENT"] = model.IncludeInspectorRequirement ? "Inspector Requirement" : string.Empty,
            ["AUTOMATIC_TEST"] = model.IncludeAutomaticTest ? "Automatic Test" : string.Empty,
            ["ADDITIONAL_REQUIREMENTS"] =
    model.IncludeAdditionalRequirements
        ? (string.IsNullOrWhiteSpace(model.AdditionalRequirementsText)
            ? "Additional Requirements"
            : model.AdditionalRequirementsText)
            : string.Empty,
        };
    }
}
