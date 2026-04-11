using System;
using System.Collections;
using System.Collections.Generic;
using System.DirectoryServices.Protocols;
using System.Linq;
using System.Management.Automation;
using System.Net;
using System.Security.Principal;
using System.Text;
using System.Text.RegularExpressions;

namespace Pxtl.ADServices
{
    internal static class LdapHelper
    {
        public static LdapConnection CreateConnection(string server, PSCredential credential)
        {
            var identifier = new LdapDirectoryIdentifier(server);
            var networkCredential = credential?.GetNetworkCredential();
            var connection = new LdapConnection(identifier, networkCredential);
            connection.Bind();
            return connection;
        }

        public static string ConvertIdentityToFilter(string identity)
        {
            if (identity == null)
            {
                throw new ArgumentNullException(nameof(identity));
            }
            if (identity == "*")
            {
                throw new ArgumentException("'*' cannot be used for -Identity parameters", nameof(identity));
            }
            if (Guid.TryParse(identity, out _))
            {
                return $"(objectGUID={identity})";
            }
            if (Regex.IsMatch(identity, @"^S-\d-\d+-(\d+-){1,14}\d+$", RegexOptions.IgnoreCase))
            {
                return $"(objectSid={identity})";
            }
            var dnPattern = new Regex(@"^(?:(?<cn>CN=(?<name>[^,]*)),)?(?:(?<path>(?:(?:CN|OU)=[^,]+,?)+),)?(?<domain>(?:DC=[^,]+,?)+)$", RegexOptions.IgnoreCase);
            if (dnPattern.IsMatch(identity))
            {
                return $"(distinguishedName={identity})";
            }
            return $"(sAMAccountName={identity})";
        }

        public static string GetDefaultNamingContext(string server, PSCredential credential)
        {
            using var connection = CreateConnection(server, credential);
            var request = new SearchRequest(null, "(objectClass=*)", SearchScope.Base, "defaultNamingContext");
            var response = (SearchResponse)connection.SendRequest(request);
            var entry = response.Entries.Cast<SearchResultEntry>().FirstOrDefault();
            if (entry == null)
            {
                return null;
            }
            var attribute = entry.Attributes["defaultNamingContext"];
            return attribute?.GetValues(typeof(string)).Cast<string>().FirstOrDefault();
        }

        public static IEnumerable<PSObject> SearchObjects(string filter, string searchBase, string server, PSCredential credential, Func<Dictionary<string, object>, Dictionary<string, object>> converter)
        {
            if (string.IsNullOrWhiteSpace(searchBase))
            {
                searchBase = GetDefaultNamingContext(server, credential);
            }
            using var connection = CreateConnection(server, credential);
            var request = new SearchRequest(searchBase, filter, SearchScope.Subtree, "*");
            var response = (SearchResponse)connection.SendRequest(request);
            foreach (SearchResultEntry entry in response.Entries)
            {
                yield return ConvertSearchEntry(entry, converter);
            }
        }

        public static PSObject ConvertSearchEntry(SearchResultEntry entry, Func<Dictionary<string, object>, Dictionary<string, object>> converter)
        {
            var attributes = BuildAttributeTable(entry.Attributes);
            var propertyTable = converter(attributes) ?? new Dictionary<string, object>(StringComparer.OrdinalIgnoreCase);
            var psObject = new PSObject();

            foreach (var pair in propertyTable)
            {
                psObject.Properties.Add(new PSNoteProperty(pair.Key, pair.Value));
            }

            psObject.Properties.Add(new PSNoteProperty("Attributes", attributes));
            psObject.Properties.Add(new PSNoteProperty("Properties", attributes));
            return psObject;
        }

        public static Dictionary<string, object> BuildAttributeTable(SearchResultAttributeCollection attributes)
        {
            var table = new Dictionary<string, object>(StringComparer.OrdinalIgnoreCase);
            foreach (DirectoryAttribute attribute in attributes)
            {
                var values = new List<object>();
                foreach (var item in attribute)
                {
                    if (item is byte[] bytes)
                    {
                        if (string.Equals(attribute.Name, "objectSid", StringComparison.OrdinalIgnoreCase))
                        {
                            values.Add(new SecurityIdentifier(bytes, 0));
                            continue;
                        }
                        if (string.Equals(attribute.Name, "objectGuid", StringComparison.OrdinalIgnoreCase))
                        {
                            values.Add(new Guid(bytes));
                            continue;
                        }
                        values.Add(Encoding.UTF8.GetString(bytes));
                    }
                    else
                    {
                        values.Add(item);
                    }
                }

                if (values.Count == 0)
                {
                    table[attribute.Name] = null;
                }
                else if (values.Count == 1)
                {
                    table[attribute.Name] = values[0];
                }
                else
                {
                    table[attribute.Name] = values.ToArray();
                }
            }

            return table;
        }

        private static IEnumerable<Object> Arrayify(object value)
            => (!(value is string) && (value is IEnumerable valueAsEnumerable))
                ? valueAsEnumerable.Cast<Object>()
                : new object[] { value };

        public static DirectoryAttributeModification CreateAttributeModification(string name, object value, DirectoryAttributeOperation operation)
        {
            var values = Arrayify(value);
            if (values.All(v => v is string)) {
                return CreateAttributeModification(name, values.Cast<string>(), operation);
            } else if (values.All(value => value is byte[])) {
                return CreateAttributeModification(name, values.Cast<byte[]>(), operation);
            } else if (values.All(value => value is Uri)) {
                return CreateAttributeModification(name, values.Cast<Uri>(), operation);
            } else {
                throw new ArgumentException($"{nameof(value)} must be either a byte[], string, or Uri, or an array thereof.", nameof(value));
            }
        }

        public static DirectoryAttributeModification CreateAttributeModification(string name, IEnumerable<string> values, DirectoryAttributeOperation operation)
        {
            var modification = new DirectoryAttributeModification { Name = name, Operation = operation };
            if (values != null)
            {
                foreach (var value in values) {
                    modification.Add(value);
                }
            }
            return modification;
        }

        public static DirectoryAttributeModification CreateAttributeModification(string name, IEnumerable<byte[]> values, DirectoryAttributeOperation operation)
        {
            var modification = new DirectoryAttributeModification { Name = name, Operation = operation };
            if (values != null)
            {
                foreach (var value in values) {
                    modification.Add(value);
                }
            }
            return modification;
        }

        public static DirectoryAttributeModification CreateAttributeModification(string name, IEnumerable<Uri> values, DirectoryAttributeOperation operation)
        {
            var modification = new DirectoryAttributeModification { Name = name, Operation = operation };
            if (values != null)
            {
                foreach (var value in values) {
                    modification.Add(value);
                }
            }
            return modification;
        }

        public static object[] NormalizeAttributeValue(object value)
        {
            if (value == null)
            {
                return Array.Empty<object>();
            }
            if (value is string stringValue)
            {
                return new object[] { stringValue };
            }
            if (value is IEnumerable enumerable)
            {
                return enumerable.Cast<object>().ToArray();
            }
            return new object[] { value };
        }

        public static string BuildObjectClassFilter(string type)
        {
            return $"(objectClass={type})";
        }

        public static DateTime? ConvertFileTime(object fileTimeValue)
        {
            if (fileTimeValue == null)
            {
                return null;
            }
            if (fileTimeValue is long l)
            {
                if (l == long.MaxValue)
                {
                    return DateTime.MaxValue.ToLocalTime();
                }
                return DateTime.FromFileTime(l).ToLocalTime();
            }
            if (long.TryParse(fileTimeValue.ToString(), out var parsed))
            {
                if (parsed == long.MaxValue)
                {
                    return DateTime.MaxValue.ToLocalTime();
                }
                return DateTime.FromFileTime(parsed).ToLocalTime();
            }
            return null;
        }
    }

    internal static class ADPropertyConverters
    {
        private static object GetValue(Dictionary<string, object> table, string key)
        {
            return table.TryGetValue(key, out var value) ? value : null;
        }

        private static bool HasFlag(Dictionary<string, object> table, string key, int mask)
        {
            if (!table.TryGetValue(key, out var raw) || raw == null)
            {
                return false;
            }

            if (raw is int intValue)
            {
                return (intValue & mask) != 0;
            }
            if (raw is long longValue)
            {
                return (longValue & mask) != 0;
            }
            if (int.TryParse(raw.ToString(), out var parsed))
            {
                return (parsed & mask) != 0;
            }
            return false;
        }

        private static string NormalizeString(object value)
        {
            return value?.ToString();
        }

        public static Dictionary<string, object> ConvertRootDse(Dictionary<string, object> ldapAttributes)
        {
            return ConvertRootDse(ldapAttributes, null);
        }

        public static Dictionary<string, object> ConvertRootDse(Dictionary<string, object> ldapAttributes, Dictionary<string, object> propertyTable = null)
        {
            propertyTable ??= new Dictionary<string, object>(StringComparer.OrdinalIgnoreCase);
            foreach (var pair in ldapAttributes.OrderBy(p => p.Key, StringComparer.OrdinalIgnoreCase))
            {
                propertyTable[pair.Key] = pair.Value;
            }
            return propertyTable;
        }

        public static Dictionary<string, object> ConvertAdObject(Dictionary<string, object> ldapAttributes)
        {
            return ConvertAdObject(ldapAttributes, null);
        }

        public static Dictionary<string, object> ConvertAdObject(Dictionary<string, object> ldapAttributes, Dictionary<string, object> propertyTable = null)
        {
            propertyTable ??= new Dictionary<string, object>(StringComparer.OrdinalIgnoreCase);
            propertyTable["CanonicalName"] = GetValue(ldapAttributes, "canonicalName");
            propertyTable["CN"] = GetValue(ldapAttributes, "cn");
            propertyTable["Created"] = GetValue(ldapAttributes, "createTimeStamp");
            propertyTable["Deleted"] = GetValue(ldapAttributes, "isDeleted");
            propertyTable["Description"] = GetValue(ldapAttributes, "description");
            propertyTable["DisplayName"] = GetValue(ldapAttributes, "displayName");
            propertyTable["DistinguishedName"] = GetValue(ldapAttributes, "distinguishedName");
            propertyTable["LastKnownParent"] = GetValue(ldapAttributes, "lastKnownParent");
            propertyTable["Modified"] = GetValue(ldapAttributes, "modifyTimeStamp");
            propertyTable["Name"] = GetValue(ldapAttributes, "name");
            propertyTable["ObjectCategory"] = GetValue(ldapAttributes, "objectCategory");

            var objectClass = GetValue(ldapAttributes, "objectClass");
            if (objectClass is object[] array)
            {
                propertyTable["ObjectClass"] = array.LastOrDefault();
            }
            else
            {
                propertyTable["ObjectClass"] = objectClass;
            }

            propertyTable["ObjectGUID"] = NormalizeString(GetValue(ldapAttributes, "objectGUID"));
            propertyTable["ProtectedFromAccidentalDeletion"] = GetValue(ldapAttributes, "nTSecurityDescriptor");
            return propertyTable;
        }

        public static Dictionary<string, object> ConvertAdUser(Dictionary<string, object> ldapAttributes)
        {
            return ConvertAdUser(ldapAttributes, null);
        }

        public static Dictionary<string, object> ConvertAdUser(Dictionary<string, object> ldapAttributes, Dictionary<string, object> propertyTable = null)
        {
            propertyTable = ConvertAdObject(ldapAttributes, propertyTable);
            propertyTable["AccountExpirationDate"] = LdapHelper.ConvertFileTime(GetValue(ldapAttributes, "accountExpires"));
            propertyTable["AccountLockoutTime"] = LdapHelper.ConvertFileTime(GetValue(ldapAttributes, "lockoutTime"));
            propertyTable["AccountNotDelegated"] = HasFlag(ldapAttributes, "userAccountControl", UserAccountControlConstants.ACCOUNT_DISABLED);
            propertyTable["AllowReversiblePasswordEncryption"] = HasFlag(ldapAttributes, "userAccountControl", UserAccountControlConstants.ENCRYPTED_TEXT_PWD_ALLOWED);
            propertyTable["BadLogonCount"] = GetValue(ldapAttributes, "badPwdCount");
            propertyTable["CannotChangePassword"] = GetValue(ldapAttributes, "nTSecurityDescriptor");
            propertyTable["Certificates"] = GetValue(ldapAttributes, "userCertificate");
            propertyTable["ChangePasswordAtLogon"] = LdapHelper.ConvertFileTime(GetValue(ldapAttributes, "pwdLastSet")) == DateTime.MinValue;
            propertyTable["City"] = GetValue(ldapAttributes, "l");
            propertyTable["Company"] = GetValue(ldapAttributes, "company");
            propertyTable["Country"] = GetValue(ldapAttributes, "c");
            propertyTable["Department"] = GetValue(ldapAttributes, "department");
            propertyTable["Division"] = GetValue(ldapAttributes, "division");
            propertyTable["DoesNotRequirePreAuth"] = HasFlag(ldapAttributes, "userAccountControl", UserAccountControlConstants.DONT_REQ_PREAUTH);
            propertyTable["EmailAddress"] = GetValue(ldapAttributes, "mail");
            propertyTable["EmployeeID"] = GetValue(ldapAttributes, "employeeID");
            propertyTable["EmployeeNumber"] = GetValue(ldapAttributes, "employeeNumber");
            propertyTable["Enabled"] = !HasFlag(ldapAttributes, "userAccountControl", UserAccountControlConstants.ACCOUNT_DISABLED);
            propertyTable["Fax"] = GetValue(ldapAttributes, "facsimileTelephoneNumber");
            propertyTable["GivenName"] = GetValue(ldapAttributes, "givenName");
            propertyTable["HomeDirectory"] = GetValue(ldapAttributes, "homeDirectory");
            propertyTable["HomedirRequired"] = HasFlag(ldapAttributes, "userAccountControl", UserAccountControlConstants.HOMEDIR_REQUIRED);
            propertyTable["HomeDrive"] = GetValue(ldapAttributes, "homeDrive");
            propertyTable["HomePage"] = GetValue(ldapAttributes, "wWWHomePage");
            propertyTable["HomePhone"] = GetValue(ldapAttributes, "homePhone");
            propertyTable["Initials"] = GetValue(ldapAttributes, "initials");
            propertyTable["LastBadPasswordAttempt"] = LdapHelper.ConvertFileTime(GetValue(ldapAttributes, "badPasswordTime"));
            propertyTable["LastLogonDate"] = LdapHelper.ConvertFileTime(GetValue(ldapAttributes, "lastLogonTimeStamp"));
            propertyTable["LockedOut"] = HasFlag(ldapAttributes, "msDS-User-Account-Control-Computed", UserAccountControlConstants.LOCKOUT);
            propertyTable["LogonWorkstations"] = GetValue(ldapAttributes, "userWorkstations");
            propertyTable["Manager"] = GetValue(ldapAttributes, "manager");
            propertyTable["MemberOf"] = GetValue(ldapAttributes, "memberOf");
            propertyTable["MNSLogonAccount"] = HasFlag(ldapAttributes, "userAccountControl", UserAccountControlConstants.MNS_LOGON_ACCOUNT);
            propertyTable["MobilePhone"] = GetValue(ldapAttributes, "mobile");
            propertyTable["Office"] = GetValue(ldapAttributes, "physicalDeliveryOfficeName");
            propertyTable["OfficePhone"] = GetValue(ldapAttributes, "telephoneNumber");
            propertyTable["Organization"] = GetValue(ldapAttributes, "o");
            propertyTable["OtherName"] = GetValue(ldapAttributes, "middleName");
            propertyTable["PasswordExpired"] = HasFlag(ldapAttributes, "msDS-User-Account-Control-Computed", UserAccountControlConstants.PASSWORD_EXPIRED);
            propertyTable["PasswordLastSet"] = LdapHelper.ConvertFileTime(GetValue(ldapAttributes, "pwdLastSet"));
            propertyTable["PasswordNeverExpires"] = HasFlag(ldapAttributes, "userAccountControl", UserAccountControlConstants.DONT_EXPIRE_PASSWORD);
            propertyTable["PasswordNotRequired"] = HasFlag(ldapAttributes, "userAccountControl", UserAccountControlConstants.PASSWD_NOTREQD);
            propertyTable["POBox"] = GetValue(ldapAttributes, "postOfficeBox");
            propertyTable["PostalCode"] = GetValue(ldapAttributes, "postalCode");
            propertyTable["PrimaryGroup"] = GetValue(ldapAttributes, "primaryGroupID");
            propertyTable["ProfilePath"] = GetValue(ldapAttributes, "profilePath");
            propertyTable["SamAccountName"] = GetValue(ldapAttributes, "sAMAccountName");
            propertyTable["ScriptPath"] = GetValue(ldapAttributes, "scriptPath");
            propertyTable["ServicePrincipalNames"] = GetValue(ldapAttributes, "servicePrincipalName");
            propertyTable["SID"] = NormalizeString(GetValue(ldapAttributes, "objectSID"));
            propertyTable["SIDHistory"] = GetValue(ldapAttributes, "sIDHistory");
            propertyTable["SmartcardLogonRequired"] = HasFlag(ldapAttributes, "userAccountControl", UserAccountControlConstants.SMARTCARD_REQUIRED);
            propertyTable["State"] = GetValue(ldapAttributes, "st");
            propertyTable["StreetAddress"] = GetValue(ldapAttributes, "streetAddress");
            propertyTable["Surname"] = GetValue(ldapAttributes, "sn");
            propertyTable["Title"] = GetValue(ldapAttributes, "title");
            propertyTable["TrustedForDelegation"] = HasFlag(ldapAttributes, "userAccountControl", UserAccountControlConstants.TRUSTED_FOR_DELEGATION);
            propertyTable["TrustedToAuthForDelegation"] = HasFlag(ldapAttributes, "userAccountControl", UserAccountControlConstants.TRUSTED_TO_AUTH_FOR_DELEGATION);
            propertyTable["UseDESKeyOnly"] = HasFlag(ldapAttributes, "userAccountControl", UserAccountControlConstants.USE_DES_KEY_ONLY);
            propertyTable["UserPrincipalName"] = GetValue(ldapAttributes, "userPrincipalName");
            return propertyTable;
        }

        public static Dictionary<string, object> ConvertAdGroup(Dictionary<string, object> ldapAttributes)
        {
            return ConvertAdGroup(ldapAttributes, null);
        }

        public static Dictionary<string, object> ConvertAdGroup(Dictionary<string, object> ldapAttributes, Dictionary<string, object> propertyTable = null)
        {
            propertyTable = ConvertAdObject(ldapAttributes, propertyTable);
            var groupType = GetIntValue(ldapAttributes, "groupType");
            propertyTable["GroupCategory"] = (groupType & UserAccountControlConstants.SECURITY_ENABLED) != 0 ? "Security" : "Distribution";
            if ((groupType & UserAccountControlConstants.ACCOUNT_GROUP) != 0)
            {
                propertyTable["GroupScope"] = "Global";
            }
            else if ((groupType & UserAccountControlConstants.RESOURCE_GROUP) != 0)
            {
                propertyTable["GroupScope"] = "DomainLocal";
            }
            else if ((groupType & UserAccountControlConstants.UNIVERSAL_GROUP) != 0)
            {
                propertyTable["GroupScope"] = "Universal";
            }
            propertyTable["HomePage"] = GetValue(ldapAttributes, "wWWHomePage");
            propertyTable["ManagedBy"] = GetValue(ldapAttributes, "managedBy");
            propertyTable["MemberOf"] = GetValue(ldapAttributes, "memberOf");
            propertyTable["Members"] = GetValue(ldapAttributes, "member");
            propertyTable["SamAccountName"] = GetValue(ldapAttributes, "sAMAccountName");
            propertyTable["SID"] = NormalizeString(GetValue(ldapAttributes, "objectSID"));
            propertyTable["SIDHistory"] = GetValue(ldapAttributes, "sIDHistory");
            return propertyTable;
        }

        public static Dictionary<string, object> ConvertAdOrganizationalUnit(Dictionary<string, object> ldapAttributes)
        {
            return ConvertAdOrganizationalUnit(ldapAttributes, null);
        }

        public static Dictionary<string, object> ConvertAdOrganizationalUnit(Dictionary<string, object> ldapAttributes, Dictionary<string, object> propertyTable = null)
        {
            propertyTable = ConvertAdObject(ldapAttributes, propertyTable);
            propertyTable["City"] = GetValue(ldapAttributes, "l");
            propertyTable["Country"] = GetValue(ldapAttributes, "c");
            propertyTable["LinkedGroupPolicyObjects"] = GetValue(ldapAttributes, "gPLink");
            propertyTable["ManagedBy"] = GetValue(ldapAttributes, "managedBy");
            propertyTable["Name"] = GetValue(ldapAttributes, "ou");
            propertyTable["PostalCode"] = GetValue(ldapAttributes, "postalCode");
            propertyTable["State"] = GetValue(ldapAttributes, "st");
            propertyTable["StreetAddress"] = GetValue(ldapAttributes, "streetAddress");
            return propertyTable;
        }

        private static int GetIntValue(Dictionary<string, object> table, string key)
        {
            if (table.TryGetValue(key, out var raw) && raw != null)
            {
                return raw switch
                {
                    int i => i,
                    long l => (int)l,
                    string s when int.TryParse(s, out var result) => result,
                    _ when int.TryParse(raw.ToString(), out var result) => result,
                    _ => 0
                };
            }
            return 0;
        }

        private static class UserAccountControlConstants
        {
            public const int SCRIPT = 0x01;
            public const int ACCOUNT_DISABLED = 0x02;
            public const int HOMEDIR_REQUIRED = 0x08;
            public const int LOCKOUT = 0x10;
            public const int PASSWD_NOTREQD = 0x20;
            public const int PASSWD_CANT_CHANGE = 0x40;
            public const int ENCRYPTED_TEXT_PWD_ALLOWED = 0x80;
            public const int DONT_EXPIRE_PASSWORD = 0x10000;
            public const int MNS_LOGON_ACCOUNT = 0x20000;
            public const int SMARTCARD_REQUIRED = 0x40000;
            public const int TRUSTED_FOR_DELEGATION = 0x80000;
            public const int NOT_DELEGATED = 0x100000;
            public const int USE_DES_KEY_ONLY = 0x200000;
            public const int DONT_REQ_PREAUTH = 0x400000;
            public const int PASSWORD_EXPIRED = 0x800000;
            public const int TRUSTED_TO_AUTH_FOR_DELEGATION = 0x1000000;
            public const int ACCOUNT_GROUP = 0x02;
            public const int RESOURCE_GROUP = 0x04;
            public const int UNIVERSAL_GROUP = 0x08;
            public const int SECURITY_ENABLED = unchecked((int)0x80000000);
        }
    }

    internal static class ADCommandUtils
    {
        public static IEnumerable<PSObject> GetADObjects(string type, string ldapFilter, string identity, string searchBase, string server, PSCredential credential, Func<Dictionary<string, object>, Dictionary<string, object>> converter)
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
            if (!string.IsNullOrEmpty(type))
            {
                filter = $"(&({LdapHelper.BuildObjectClassFilter(type)})({ldapFilter}))";
            }
            else
            {
                filter = $"({ldapFilter})";
            }
            return LdapHelper.SearchObjects(filter, searchBase, server, credential, converter);
        }

        public static PSObject GetADObject(string type, string ldapFilter, string identity, string searchBase, string server, PSCredential credential, Func<Dictionary<string, object>, Dictionary<string, object>> converter)
        {
            return GetADObjects(type, ldapFilter, identity, searchBase, server, credential, converter).FirstOrDefault();
        }

        public static bool TestADObject(string type, string identity, string server, PSCredential credential, Func<Dictionary<string, object>, Dictionary<string, object>> converter)
        {
            return GetADObjects(type, null, identity, null, server, credential, converter).Any();
        }

        public static PSObject NewADObject(string type, string distinguishedComponentType, string name, Hashtable otherAttributes, string path, string defaultRelativePath, string server, PSCredential credential, bool doSamAccountName, bool passThru, Func<Dictionary<string, object>, Dictionary<string, object>> converter)
        {
            if (string.IsNullOrWhiteSpace(path))
            {
                path = LdapHelper.GetDefaultNamingContext(server, credential);
                if (!string.IsNullOrWhiteSpace(defaultRelativePath))
                {
                    path = $"{defaultRelativePath},{path}";
                }
            }

            if (!TestADObject(null, path, server, credential, ADPropertyConverters.ConvertAdObject))
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
                var existing = GetADObjects(null, "sAMAccountName=" + name, null, null, server, credential, ADPropertyConverters.ConvertAdObject);
                if (existing.Any())
                {
                    throw new InvalidOperationException($"There is already an existing entry with sAMAccountName '{name}'.");
                }
                attributes["sAMAccountName"] = name;
            }

            var distinguishedName = $"{distinguishedComponentType}={name},{path}";
            using var connection = LdapHelper.CreateConnection(server, credential);
            var addRequest = new AddRequest(distinguishedName, type);
            foreach (var attr in attributes)
            {
                addRequest.Attributes.Add(new DirectoryAttribute(attr.Key, LdapHelper.NormalizeAttributeValue(attr.Value)));
            }
            connection.SendRequest(addRequest);

            if (passThru)
            {
                return GetADObject(type, null, distinguishedName, null, server, credential, converter);
            }
            return null;
        }

        public static PSObject SetADObject(string type, string identity, Hashtable add, Hashtable remove, Hashtable replace, string server, PSCredential credential, bool passThru, Func<Dictionary<string, object>, Dictionary<string, object>> converter)
        {
            var entry = GetADObjects(type, null, identity, null, server, credential, converter).ToList();
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
                    var distinguishedName = GetDistinguishedName(entry[0]);
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
                    return GetADObject(type, null, identity, null, server, credential, converter);
                }
                return null;
            }
            if (!entry.Any())
            {
                throw new InvalidOperationException($"Could not find {type} '{identity}', cannot modify.");
            }
            throw new InvalidOperationException($"Multiple entries of type {type} found matching identity '{identity}', cannot modify.");
        }

        public static void RemoveADObject(string type, string identity, string server, PSCredential credential, Func<Dictionary<string, object>, Dictionary<string, object>> converter)
        {
            var entry = GetADObjects(type, null, identity, null, server, credential, converter).ToList();
            if (entry.Count == 1)
            {
                using var connection = LdapHelper.CreateConnection(server, credential);
                var distinguishedName = GetDistinguishedName(entry[0]);
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

        public static string GetDistinguishedName(PSObject entry)
        {
            if (entry == null)
            {
                return null;
            }
            if (entry.Properties["DistinguishedName"]?.Value is string dn)
            {
                return dn;
            }
            if (entry.Properties["distinguishedName"]?.Value is string dn2)
            {
                return dn2;
            }
            if (entry.Properties["Attributes"]?.Value is Dictionary<string, object> attributes && attributes.TryGetValue("distinguishedName", out var rawDn))
            {
                return rawDn?.ToString();
            }
            return null;
        }

        public static int GetAttributeIntValue(PSObject entry, string attributeName)
        {
            if (entry?.Properties["Attributes"]?.Value is Dictionary<string, object> attributes && attributes.TryGetValue(attributeName, out var raw))
            {
                return raw switch
                {
                    int i => i,
                    long l => (int)l,
                    string s when int.TryParse(s, out var parsed) => parsed,
                    _ when int.TryParse(raw?.ToString(), out var parsed) => parsed,
                    _ => 0
                };
            }
            return 0;
        }
    }
}
