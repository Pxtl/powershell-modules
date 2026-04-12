namespace Pxtl.ADServices
{
    public enum ADEntryType
    {
        Object = 0,
        RootDSE = 1,
        User = 2,
        Group = 3,
        OrganizationalUnit = 4
    }
    public static class ADEntryTypeExtensions
    {
        public static string ToADObjectClassName(this ADEntryType entryType)
            => entryType.ToString().ToLower();
        public static string ToADObjectClassName(this ADEntryType? entryType)
            => (entryType ?? ADEntryType.Object).ToADObjectClassName();
    }
}
