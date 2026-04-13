using System.Collections.Generic;

namespace Pxtl.ADServices
{
    public class ADGroupEntry : ADObjectEntry
    {
        public string SamAccountName { get; set; }
        public object Members { get; set; }
        public string GroupCategory { get; set; }
        public string GroupScope { get; set; }
        public string HomePage { get; set; }
        public string ManagedBy { get; set; }

        /// <summary>
        /// Takes a table of raw LDAP properties and converts them into object
        /// properties for an ADGroupEntry.
        /// </summary>
        /// <remarks>
        /// Adapted from
        /// https://learn.microsoft.com/en-us/archive/technet-wiki/12079.active-directory-get-adgroup-default-and-extended-properties
        /// </remarks>
        public override void Hydrate(Dictionary<string, object> ldapAttributes)
        {
            base.Hydrate(ldapAttributes);
            var groupType = ADAttributeHelper.GetLongValue(ldapAttributes, "groupType");
            GroupCategory = (groupType & GroupTypeFlags.SECURITY_ENABLED) != 0 ? "Security" : "Distribution";
            if ((groupType & GroupTypeFlags.ACCOUNT_GROUP) != 0)
            {
                GroupScope = "Global";
            }
            else if ((groupType & GroupTypeFlags.RESOURCE_GROUP) != 0)
            {
                GroupScope = "DomainLocal";
            }
            else if ((groupType & GroupTypeFlags.UNIVERSAL_GROUP) != 0)
            {
                GroupScope = "Universal";
            }
            HomePage = ADAttributeHelper.NormalizeString(ADAttributeHelper.GetValue(ldapAttributes, "wWWHomePage"));
            ManagedBy = ADAttributeHelper.NormalizeString(ADAttributeHelper.GetValue(ldapAttributes, "managedBy"));
            Members = ADAttributeHelper.GetValue(ldapAttributes, "member");
            SamAccountName = ADAttributeHelper.NormalizeString(ADAttributeHelper.GetValue(ldapAttributes, "sAMAccountName"));
        }
    }
}
