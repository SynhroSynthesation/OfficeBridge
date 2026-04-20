using OfficeBridge.Core.Interfaces;

namespace OfficeBridge.Infrastructure.Services;

public sealed class OfficeProviderResolver
{
    private readonly IEnumerable<IOfficeProvider> _providers;

    public OfficeProviderResolver(IEnumerable<IOfficeProvider> providers)
    {
        _providers = providers;
    }

    public IOfficeProvider? ResolveAvailable()
    {
        return _providers.FirstOrDefault(p => p.IsAvailable());
    }

    public IOfficeProvider? ResolveByName(string name)
    {
        return _providers.FirstOrDefault(p =>
            string.Equals(p.Name, name, StringComparison.OrdinalIgnoreCase));
    }
}