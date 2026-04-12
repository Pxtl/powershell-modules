using System.Collections.Generic;
namespace Pxtl.ADServices
{
    internal class ADOrganizationalUnitEntry : ADObjectEntry
    {
        public string City { get; set; }
        public string Country { get; set; }
        public object LinkedGroupPolicyObjects { get; set; }
        public string ManagedBy { get; set; }
        public string PostalCode { get; set; }
        public string State { get; set; }
        public string StreetAddress { get; set; }

        public override void Hydrate(Dictionary<string, object> ldapAttributes)
        {
            base.Hydrate(ldapAttributes);
            City = ADAttributeHelper.NormalizeString(ADAttributeHelper.GetValue(ldapAttributes, "l"));
            Country = ADAttributeHelper.NormalizeString(ADAttributeHelper.GetValue(ldapAttributes, "c"));
            LinkedGroupPolicyObjects = ADAttributeHelper.GetValue(ldapAttributes, "gPLink");
            ManagedBy = ADAttributeHelper.NormalizeString(ADAttributeHelper.GetValue(ldapAttributes, "managedBy"));
            Name = ADAttributeHelper.NormalizeString(ADAttributeHelper.GetValue(ldapAttributes, "ou"));
            PostalCode = ADAttributeHelper.NormalizeString(ADAttributeHelper.GetValue(ldapAttributes, "postalCode"));
            State = ADAttributeHelper.NormalizeString(ADAttributeHelper.GetValue(ldapAttributes, "st"));
            StreetAddress = ADAttributeHelper.NormalizeString(ADAttributeHelper.GetValue(ldapAttributes, "streetAddress"));
        }
    }
}
