namespace Pxtl.ADServices
{
    /// <summary>
    /// LDAP groupType attribute bit-flags
    /// </summary>
    /// <remarks>
    /// See https://learn.microsoft.com/en-us/openspecs/windows_protocols/ms-adts/11972272-09ec-4a42-bf5e-3e99b321cf55
    /// </remarks>
    internal static class GroupTypeFlags
    {
        public const long ACCOUNT_GROUP = 0x02L;
        public const long RESOURCE_GROUP = 0x04L;
        public const long UNIVERSAL_GROUP = 0x08L;
        public const long SECURITY_ENABLED = 0x80000000L;
    }
}