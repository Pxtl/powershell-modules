using System;
using System.Collections;
using System.Collections.Generic;
using System.DirectoryServices.Protocols;
using System.Linq;
using System.Management.Automation;

namespace Pxtl.ADServices
{
    internal static class ADCommandUtils
    {
        public static IEnumerable<T> TryGetADObjects<T>(ADEntryType? type, string ldapFilter, string identity, string searchBase, string server, PSCredential credential)
            where T : ADEntry, new()
        {
            if (!string.IsNullOrEmpty(identity))
            {
                ldapFilter = LdapHelper.ConvertIdentityToFilter(identity);
            }
            if (string.IsNullOrEmpty(ldapFilter))
            {
                throw new ArgumentException("LDAPFilter or Identity must be supplied.", nameof(ldapFilter));
            }
            string filter;
            if (!type.HasValue)
            {
                filter = $"(&({LdapHelper.BuildObjectClassFilter(type.Value)})({ldapFilter}))";
            }
            else
            {
                filter = $"({ldapFilter})";
            }
            return LdapHelper.SearchObjects<T>(filter, searchBase, server, credential);
        }

        public static IEnumerable<ADEntry> TryGetADObjects(ADEntryType? type, string ldapFilter, string identity, string searchBase, string server, PSCredential credential)
        {
            type ??= ADEntryType.Object;
            return type.Value switch
            {
                ADEntryType.User => TryGetADObjects<ADUserEntry>(type, ldapFilter, identity, searchBase, server, credential),
                ADEntryType.Group => TryGetADObjects<ADGroupEntry>(type, ldapFilter, identity, searchBase, server, credential),
                ADEntryType.OrganizationalUnit => TryGetADObjects<ADOrganizationalUnitEntry>(type, ldapFilter, identity, searchBase, server, credential),
                ADEntryType.RootDSE => TryGetADObjects<ADRootDSEEntry>(type, ldapFilter, identity, searchBase, server, credential),
                _ => TryGetADObjects<ADObjectEntry>(type, ldapFilter, identity, searchBase, server, credential),
            };
        }

        public static T TryGetADObject<T>(ADEntryType? type, string ldapFilter, string identity, string searchBase, string server, PSCredential credential)
            where T : ADEntry, new()
        {
            return TryGetADObjects<T>(type, ldapFilter, identity, searchBase, server, credential).FirstOrDefault();
        }

        public static T GetADObject<T>(ADEntryType? type, string ldapFilter, string identity, string searchBase, string server, PSCredential credential)
            where T : ADEntry, new()
        {
            var entry = TryGetADObjects<T>(type, ldapFilter, identity, searchBase, server, credential).FirstOrDefault();
            return (entry == null)
                ? throw new KeyNotFoundException($"LDAP object '{identity} was not found on '{server}'.")
                : entry;
        }

        public static ADEntry TryGetADObject(ADEntryType? type, string ldapFilter, string identity, string searchBase, string server, PSCredential credential)
        {
            return TryGetADObjects(type, ldapFilter, identity, searchBase, server, credential).FirstOrDefault();
        }

        public static ADEntry GetADObject(ADEntryType? type, string ldapFilter, string identity, string searchBase, string server, PSCredential credential)
        {
            var entry = TryGetADObjects(type, ldapFilter, identity, searchBase, server, credential).FirstOrDefault();
            return (entry == null)
                ? throw new KeyNotFoundException($"LDAP object '{identity} was not found on '{server}'.")
                : entry;
        }

        public static bool TestADObject(ADEntryType? type, string identity, string server, PSCredential credential)
        {
            return TryGetADObjects(type, null, identity, null, server, credential).Any();
        }

        public static bool TestADObject<T>(ADEntryType? type, string identity, string server, PSCredential credential)
            where T : ADEntry, new()
        {
            return TryGetADObjects<T>(type, null, identity, null, server, credential).Any();
        }

        public static T NewADObject<T>(ADEntryType type, string distinguishedComponentType, string name, Hashtable otherAttributes, string path, string defaultRelativePath, string server, PSCredential credential, bool doSamAccountName, bool passThru)
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

            if (!TestADObject<ADObjectEntry>(ADEntryType.Object, path, server, credential))
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
                var existing = TryGetADObjects<ADObjectEntry>(ADEntryType.Object, "sAMAccountName=" + name, null, null, server, credential);
                if (existing.Any())
                {
                    throw new InvalidOperationException($"There is already an existing entry with sAMAccountName '{name}'.");
                }
                attributes["sAMAccountName"] = name;
            }

            var distinguishedName = $"{distinguishedComponentType}={name},{path}";
            using var connection = LdapHelper.CreateConnection(server, credential);
            var addRequest = new AddRequest(distinguishedName, type.ToADObjectClassName());
            foreach (var attr in attributes)
            {
                addRequest.Attributes.Add(new DirectoryAttribute(attr.Key, LdapHelper.Arrayify(attr.Value)));
            }
            connection.SendRequest(addRequest);

            if (passThru)
            {
                return TryGetADObject<T>(type, null, distinguishedName, null, server, credential);
            }
            return null;
        }

        public static ADEntry NewADObject(ADEntryType type, string distinguishedComponentType, string name, Hashtable otherAttributes, string path, string defaultRelativePath, string server, PSCredential credential, bool doSamAccountName, bool passThru)
        {
            return type switch
            {
                ADEntryType.User => NewADObject<ADUserEntry>(type, distinguishedComponentType, name, otherAttributes, path, defaultRelativePath, server, credential, doSamAccountName, passThru),
                ADEntryType.Group => NewADObject<ADGroupEntry>(type, distinguishedComponentType, name, otherAttributes, path, defaultRelativePath, server, credential, doSamAccountName, passThru),
                ADEntryType.OrganizationalUnit => NewADObject<ADOrganizationalUnitEntry>(type, distinguishedComponentType, name, otherAttributes, path, defaultRelativePath, server, credential, doSamAccountName, passThru),
                _ => NewADObject<ADObjectEntry>(type, distinguishedComponentType, name, otherAttributes, path, defaultRelativePath, server, credential, doSamAccountName, passThru),
            };
        }

        public static T SetADObject<T>(ADEntryType type, string identity, Hashtable add, Hashtable remove, Hashtable replace, string server, PSCredential credential, bool passThru)
            where T : ADEntry, new()
        {
            var entry = TryGetADObjects<T>(type, null, identity, null, server, credential).ToList();
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
                    return TryGetADObject<T>(type, null, identity, null, server, credential);
                }
                return null;
            }
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
                ADEntryType.User => SetADObject<ADUserEntry>(type, identity, add, remove, replace, server, credential, passThru),
                ADEntryType.Group => SetADObject<ADGroupEntry>(type, identity, add, remove, replace, server, credential, passThru),
                ADEntryType.OrganizationalUnit => SetADObject<ADOrganizationalUnitEntry>(type, identity, add, remove, replace, server, credential, passThru),
                _ => SetADObject<ADObjectEntry>(type, identity, add, remove, replace, server, credential, passThru),
            };
        }

        public static void RemoveADObject<T>(ADEntryType type, string identity, string server, PSCredential credential)
            where T : ADEntry, new()
        {
            var entry = TryGetADObjects<T>(type, null, identity, null, server, credential).ToList();
            if (entry.Count == 1)
            {
                using var connection = LdapHelper.CreateConnection(server, credential);
                var distinguishedName = entry[0].MaybeGetDistinguishedName();
                var deleteRequest = new DeleteRequest(distinguishedName);
                connection.SendRequest(deleteRequest);
                return;
            }
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
                    RemoveADObject<ADUserEntry>(type, identity, server, credential);
                    break;
                case ADEntryType.Group:
                    RemoveADObject<ADGroupEntry>(type, identity, server, credential);
                    break;
                case ADEntryType.OrganizationalUnit:
                    RemoveADObject<ADOrganizationalUnitEntry>(type, identity, server, credential);
                    break;
                default:
                    RemoveADObject<ADObjectEntry>(type, identity, server, credential);
                    break;
            }
        }
    }
}
