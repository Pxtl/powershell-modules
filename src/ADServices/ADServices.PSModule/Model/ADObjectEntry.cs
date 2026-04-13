using System;
using System.Collections.Generic;
using System.Linq;

namespace Pxtl.ADServices
{
    public class ADObjectEntry : ADEntry
    {
        public string ObjectClass { get; set; }
        public string DistinguishedName { get; set; }
        public string Name { get; set; }
        public object CanonicalName { get; set; }
        public object CN { get; set; }
        public object Created { get; set; }
        public object Deleted { get; set; }
        public object Description { get; set; }
        public object DisplayName { get; set; }
        public object LastKnownParent { get; set; }
        public object Modified { get; set; }
        public object ObjectCategory { get; set; }
        public string ObjectGUID { get; set; }
        public object ProtectedFromAccidentalDeletion { get; set; }

        /// <summary>
        /// Takes a table of raw LDAP properties and converts them into object
        /// properties for an ADObjectEntry.
        /// </summary>
        /// <remarks>
        /// Adapted from
        /// https://learn.microsoft.com/en-us/archive/technet-wiki/12103.active-directory-get-adobject-default-and-extended-properties
        /// </remarks>
        public override void Hydrate(Dictionary<string, object> ldapAttributes)
        {
            base.Hydrate(ldapAttributes);
            DistinguishedName = ADAttributeHelper.NormalizeString(ADAttributeHelper.GetValue(ldapAttributes, "distinguishedName"));
            Name = ADAttributeHelper.NormalizeString(ADAttributeHelper.GetValue(ldapAttributes, "name"));
            var objectClass = ADAttributeHelper.GetValue(ldapAttributes, "objectClass");
            if (objectClass is object[] array)
            {
                ObjectClass = array.LastOrDefault()?.ToString();
            }
            else
            {
                ObjectClass = ADAttributeHelper.NormalizeString(objectClass);
            }

            CanonicalName = ADAttributeHelper.GetValue(ldapAttributes, "canonicalName");
            CN = ADAttributeHelper.GetValue(ldapAttributes, "cn");
            Created = ADAttributeHelper.GetValue(ldapAttributes, "createTimeStamp");
            Deleted = ADAttributeHelper.GetValue(ldapAttributes, "isDeleted");
            Description = ADAttributeHelper.GetValue(ldapAttributes, "description");
            DisplayName = ADAttributeHelper.GetValue(ldapAttributes, "displayName");
            LastKnownParent = ADAttributeHelper.GetValue(ldapAttributes, "lastKnownParent");
            Modified = ADAttributeHelper.GetValue(ldapAttributes, "modifyTimeStamp");
            ObjectCategory = ADAttributeHelper.GetValue(ldapAttributes, "objectCategory");
            ObjectGUID = ADAttributeHelper.NormalizeString(ADAttributeHelper.GetValue(ldapAttributes, "objectGUID"));
            ProtectedFromAccidentalDeletion = ADAttributeHelper.GetValue(ldapAttributes, "nTSecurityDescriptor");
        }

        public override string ToString()
            => DistinguishedName ?? base.ToString();
        public override string MaybeGetDistinguishedName()
            => DistinguishedName;
    }
}