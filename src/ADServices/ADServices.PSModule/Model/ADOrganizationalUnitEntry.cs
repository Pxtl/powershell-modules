using System.Collections.Generic;
namespace Pxtl.ADServices
{
    public class ADOrganizationalUnitEntry : ADObjectEntry
    {
        public string City { get; set; }
        public string Country { get; set; }
        public object LinkedGroupPolicyObjects { get; set; }
        public string ManagedBy { get; set; }
        public string PostalCode { get; set; }
        public string State { get; set; }
        public string StreetAddress { get; set; }

        /// <summary>
        /// Takes a table of raw LDAP properties and converts them into object
        /// properties for an ADOrganizationalUnitEntry.
        /// </summary>
        /// <remarks>
        /// Adapted from
        /// https://learn.microsoft.com/en-us/archive/technet-wiki/12089.active-directory-get-adorganizationalunit-default-and-extended-properties
        /// </remarks>
        public override void Hydrate(Dictionary<string, object> ldapAttributes)
        {
            base.Hydrate(ldapAttributes);
            City = ADAttributeHelper.NormalizeString(ADAttributeHelper.GetValue(ldapAttributes, "l"));
            Country = ADAttributeHelper.NormalizeString(ADAttributeHelper.GetValue(ldapAttributes, "c"));
            LinkedGroupPolicyObjects = ADAttributeHelper.GetValue(ldapAttributes, "gPLink");
            ManagedBy = ADAttributeHelper.NormalizeString(ADAttributeHelper.GetValue(ldapAttributes, "managedBy"));
            // replaces the name set in ADObjectEntry.Hydrate
            Name = ADAttributeHelper.NormalizeString(ADAttributeHelper.GetValue(ldapAttributes, "ou"));
            PostalCode = ADAttributeHelper.NormalizeString(ADAttributeHelper.GetValue(ldapAttributes, "postalCode"));
            State = ADAttributeHelper.NormalizeString(ADAttributeHelper.GetValue(ldapAttributes, "st"));
            StreetAddress = ADAttributeHelper.NormalizeString(ADAttributeHelper.GetValue(ldapAttributes, "streetAddress"));
        }
    }
}
