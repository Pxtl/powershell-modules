using System;
using System.Collections;
using System.Collections.Generic;
using System.DirectoryServices.Protocols;
using System.Linq;
using System.Management.Automation;

namespace Pxtl.ADServices
{
    public static class ADEntryRepository
    {
        private readonly static ADEntryType[] UnfilteredADEntryTypes = { ADEntryType.Object, ADEntryType.RootDSE };

        public static IEnumerable<T> MaybeGetADObjects<T>(string ldapFilter, string identity, string searchBase, string server, PSCredential credential)
            where T : ADEntry, new()
        {
            var type = GetEntryTypeFromEntryClass(typeof(T));
            if (!string.IsNullOrEmpty(identity))
            {
                ldapFilter = LdapHelper.ConvertIdentityToFilter(identity);
            }
            if (string.IsNullOrEmpty(ldapFilter))
            {
                throw new ArgumentException("LDAPFilter or Identity must be supplied.", nameof(ldapFilter));
            }
            string filter;
            // NOTE: Linux System.DirectoryServices.Protocols 10.0.5 does not currently allow redundant parentheses unlike Windows.
            if (UnfilteredADEntryTypes.Contains(type))
            {
                filter = $"{ldapFilter}";
            }
            else
            {
                filter = $"(&{LdapHelper.BuildObjectClassFilter(type)}{ldapFilter})";
            }
            return LdapHelper.SearchObjects<T>(filter, searchBase, server, credential, "*");
        }

        public static IEnumerable<ADEntry> MaybeGetADObjects(ADEntryType? type, string ldapFilter, string identity, string searchBase, string server, PSCredential credential)
        {
            type ??= ADEntryType.Object;
            return type.Value switch
            {
                ADEntryType.User => MaybeGetADObjects<ADUserEntry>(ldapFilter, identity, searchBase, server, credential),
                ADEntryType.Group => MaybeGetADObjects<ADGroupEntry>(ldapFilter, identity, searchBase, server, credential),
                ADEntryType.OrganizationalUnit => MaybeGetADObjects<ADOrganizationalUnitEntry>(ldapFilter, identity, searchBase, server, credential),
                ADEntryType.RootDSE => MaybeGetADObjects<ADRootDSEEntry>(ldapFilter, identity, searchBase, server, credential),
                _ => MaybeGetADObjects<ADObjectEntry>(ldapFilter, identity, searchBase, server, credential),
            };
        }

        public static T MaybeGetADObject<T>(string ldapFilter, string identity, string searchBase, string server, PSCredential credential)
            where T : ADEntry, new()
        {
            return MaybeGetADObjects<T>(ldapFilter, identity, searchBase, server, credential).FirstOrDefault();
        }

        public static T GetADObject<T>(string ldapFilter, string identity, string searchBase, string server, PSCredential credential)
            where T : ADEntry, new()
        {
            var entry = MaybeGetADObjects<T>(ldapFilter, identity, searchBase, server, credential).FirstOrDefault();
            return (entry == null)
                ? throw new KeyNotFoundException($"LDAP object '{identity} was not found on '{server}'.")
                : entry;
        }

        public static ADEntry MaybeGetADObject(ADEntryType? type, string ldapFilter, string identity, string searchBase, string server, PSCredential credential)
        {
            return MaybeGetADObjects(type, ldapFilter, identity, searchBase, server, credential).FirstOrDefault();
        }

        public static ADEntry GetADObject(ADEntryType? type, string ldapFilter, string identity, string searchBase, string server, PSCredential credential)
        {
            var entry = MaybeGetADObjects(type, ldapFilter, identity, searchBase, server, credential).FirstOrDefault();
            return (entry == null)
                ? throw new KeyNotFoundException($"LDAP object '{identity} was not found on '{server}'.")
                : entry;
        }

        public static bool TestADObject(ADEntryType? type, string identity, string server, PSCredential credential)
        {
            return MaybeGetADObjects(type, null, identity, null, server, credential).Any();
        }

        public static bool TestADObject<T>(string identity, string server, PSCredential credential)
            where T : ADEntry, new()
        {
            return MaybeGetADObjects<T>(null, identity, null, server, credential).Any();
        }

        public static T NewADObject<T>(string distinguishedComponentType, string name, Hashtable otherAttributes, string path, string defaultRelativePath, string server, PSCredential credential, bool doSamAccountName, bool passThru)
            where T : ADEntry, new()
        {
            if (string.IsNullOrWhiteSpace(path))
            {
                path = LdapHelper.GetDefaultNamingContext(server, credential);
                if (!string.IsNullOrWhiteSpace(defaultRelativePath))
                {
                    path = $"{defaultRelativePath},{path}";
                }
            }

            if (!TestADObject<ADObjectEntry>(path, server, credential))
            {
                throw new InvalidOperationException($"Parent container node '{path}' not found.");
            }

            var attributes = new Dictionary<string, object>(StringComparer.OrdinalIgnoreCase);
            if (otherAttributes != null)
            {
                foreach (DictionaryEntry entry in otherAttributes)
                {
                    attributes[entry.Key.ToString()] = entry.Value;
                }
            }

            if (doSamAccountName)
            {
                if (typeof(T) == typeof(ADOrganizationalUnitEntry))
                {
                    throw new InvalidOperationException($"{nameof(ADOrganizationalUnitEntry)} cannot have a sAMAccountName");
                }
                var existing = MaybeGetADObjects<ADObjectEntry>("sAMAccountName=" + name, null, null, server, credential);
                if (existing.Any())
                {
                    throw new InvalidOperationException($"There is already an existing entry with sAMAccountName '{name}'.");
                }
                attributes["sAMAccountName"] = name;
            }

            var distinguishedName = $"{distinguishedComponentType}={name},{path}";
            using var connection = LdapHelper.CreateConnection(server, credential);
            var type = GetEntryTypeFromEntryClass(typeof(T));
            var addRequest = new AddRequest(distinguishedName, type.ToADObjectClassName());
            foreach (var attr in attributes)
            {
                addRequest.Attributes.Add(new DirectoryAttribute(attr.Key, LdapHelper.Arrayify(attr.Value)));
            }
            connection.SendRequest(addRequest);

            if (passThru)
            {
                return MaybeGetADObject<T>(null, distinguishedName, null, server, credential);
            }
            return null;
        }

        public static ADEntry NewADObject(ADEntryType type, string distinguishedComponentType, string name, Hashtable otherAttributes, string path, string defaultRelativePath, string server, PSCredential credential, bool doSamAccountName, bool passThru)
        {
            return type switch
            {
                ADEntryType.User => NewADObject<ADUserEntry>(distinguishedComponentType, name, otherAttributes, path, defaultRelativePath, server, credential, doSamAccountName, passThru),
                ADEntryType.Group => NewADObject<ADGroupEntry>(distinguishedComponentType, name, otherAttributes, path, defaultRelativePath, server, credential, doSamAccountName, passThru),
                ADEntryType.OrganizationalUnit => NewADObject<ADOrganizationalUnitEntry>(distinguishedComponentType, name, otherAttributes, path, defaultRelativePath, server, credential, doSamAccountName, passThru),
                _ => NewADObject<ADObjectEntry>(distinguishedComponentType, name, otherAttributes, path, defaultRelativePath, server, credential, doSamAccountName, passThru),
            };
        }

        public static T SetADObject<T>(string identity, Hashtable add, Hashtable remove, Hashtable replace, string server, PSCredential credential, bool passThru)
            where T : ADEntry, new()
        {
            var entry = MaybeGetADObjects<T>(null, identity, null, server, credential).ToList();
            if (entry.Count == 1)
            {
                var modifications = new List<DirectoryAttributeModification>();
                if (add != null)
                {
                    foreach (DictionaryEntry attr in add)
                    {
                        modifications.Add(LdapHelper.CreateAttributeModification(attr.Key.ToString(), attr.Value, DirectoryAttributeOperation.Add));
                    }
                }
                if (remove != null)
                {
                    foreach (DictionaryEntry attr in remove)
                    {
                        modifications.Add(LdapHelper.CreateAttributeModification(attr.Key.ToString(), attr.Value, DirectoryAttributeOperation.Delete));
                    }
                }
                if (replace != null)
                {
                    foreach (DictionaryEntry attr in replace)
                    {
                        modifications.Add(LdapHelper.CreateAttributeModification(attr.Key.ToString(), attr.Value, DirectoryAttributeOperation.Replace));
                    }
                }
                if (modifications.Any())
                {
                    var distinguishedName = entry[0].MaybeGetDistinguishedName();
                    var modifyRequest = new ModifyRequest(distinguishedName);
                    foreach (var modification in modifications)
                    {
                        modifyRequest.Modifications.Add(modification);
                    }
                    using var connection = LdapHelper.CreateConnection(server, credential);
                    connection.SendRequest(modifyRequest);
                }
                if (passThru)
                {
                    return MaybeGetADObject<T>(null, identity, null, server, credential);
                }
                return null;
            }
            var type = GetEntryTypeFromEntryClass(typeof(T));
            if (!entry.Any())
            {
                throw new InvalidOperationException($"Could not find {type} '{identity}', cannot modify.");
            }
            throw new InvalidOperationException($"Multiple entries of type {type} found matching identity '{identity}', cannot modify.");
        }

        public static ADEntry SetADObject(ADEntryType type, string identity, Hashtable add, Hashtable remove, Hashtable replace, string server, PSCredential credential, bool passThru)
        {
            return type switch
            {
                ADEntryType.User => SetADObject<ADUserEntry>(identity, add, remove, replace, server, credential, passThru),
                ADEntryType.Group => SetADObject<ADGroupEntry>(identity, add, remove, replace, server, credential, passThru),
                ADEntryType.OrganizationalUnit => SetADObject<ADOrganizationalUnitEntry>(identity, add, remove, replace, server, credential, passThru),
                _ => SetADObject<ADObjectEntry>(identity, add, remove, replace, server, credential, passThru),
            };
        }

        public static void RemoveADObject<T>(string identity, string server, PSCredential credential)
            where T : ADEntry, new()
        {
            var entry = MaybeGetADObjects<T>(null, identity, null, server, credential).ToList();
            if (entry.Count == 1)
            {
                using var connection = LdapHelper.CreateConnection(server, credential);
                var distinguishedName = entry[0].MaybeGetDistinguishedName();
                var deleteRequest = new DeleteRequest(distinguishedName);
                connection.SendRequest(deleteRequest);
                return;
            }
            var type = GetEntryTypeFromEntryClass(typeof(T));
            if (!entry.Any())
            {
                throw new InvalidOperationException($"Could not find {type} '{identity}', cannot remove.");
            }
            throw new InvalidOperationException($"Multiple entries of type {type} found matching identity '{identity}', cannot remove.");
        }

        public static void RemoveADObject(ADEntryType type, string identity, string server, PSCredential credential)
        {
            switch (type)
            {
                case ADEntryType.User:
                    RemoveADObject<ADUserEntry>(identity, server, credential);
                    break;
                case ADEntryType.Group:
                    RemoveADObject<ADGroupEntry>(identity, server, credential);
                    break;
                case ADEntryType.OrganizationalUnit:
                    RemoveADObject<ADOrganizationalUnitEntry>(identity, server, credential);
                    break;
                default:
                    RemoveADObject<ADObjectEntry>(identity, server, credential);
                    break;
            }
        }

        public static ADEntryType GetEntryTypeFromEntryClass(Type type)
            => (type == typeof(ADObjectEntry))
            ? ADEntryType.Object
            : (type == typeof(ADRootDSEEntry))
            ? ADEntryType.RootDSE
            : (type == typeof(ADUserEntry))
            ? ADEntryType.User
            : (type == typeof(ADGroupEntry))
            ? ADEntryType.Group
            : (type == typeof(ADOrganizationalUnitEntry))
            ? ADEntryType.OrganizationalUnit
            : throw new InvalidOperationException("Not a valid ADEntry type.");
    }
}
