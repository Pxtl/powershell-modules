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

        public static IEnumerable<T> SearchObjects<T>(string filter, string searchBase, string server, PSCredential credential)
            where T : ADEntry, new()
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
                yield return ConvertSearchEntryToADObjectEntry<T>(entry);
            }
        }

        public static T ConvertSearchEntryToADObjectEntry<T>(SearchResultEntry entry)
            where T : ADEntry, new()
        {
            var attributes = BuildAttributeDictionary(entry.Attributes);
            var result = new T();
            result.Hydrate(attributes);
            return result;
        }

        public static Dictionary<string, object> BuildAttributeDictionary(SearchResultAttributeCollection attributes)
        {
            var table = new Dictionary<string, object>(StringComparer.OrdinalIgnoreCase);
            foreach (string attributeName in attributes.AttributeNames)
            {
                var attribute = attributes[attributeName];
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

                table[attribute.Name] = (values.Count == 0)
                    ? null
                    : (values.Count == 1)
                    ? values[0]
                    : values.ToArray();
            }

            return table;
        }

        public static DirectoryAttributeModification CreateAttributeModification(string name, object value, DirectoryAttributeOperation operation)
        {
            var values = Arrayify(value);
            if (values.All(v => v is string))
            {
                return CreateAttributeModification(name, values.Cast<string>(), operation);
            }
            else if (values.All(v => v is byte[]))
            {
                return CreateAttributeModification(name, values.Cast<byte[]>(), operation);
            }
            else if (values.All(v => v is Uri))
            {
                return CreateAttributeModification(name, values.Cast<Uri>(), operation);
            }
            else
            {
                throw new ArgumentException($"{nameof(value)} must be either a byte[], string, or Uri, or an array thereof.", nameof(value));
            }
        }

        public static DirectoryAttributeModification CreateAttributeModification(string name, IEnumerable<string> values, DirectoryAttributeOperation operation)
        {
            var modification = new DirectoryAttributeModification { Name = name, Operation = operation };
            if (values != null)
            {
                foreach (var value in values)
                {
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
                foreach (var value in values)
                {
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
                foreach (var value in values)
                {
                    modification.Add(value);
                }
            }
            return modification;
        }

        public static object[] Arrayify(object value)
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

        public static string BuildObjectClassFilter(ADEntryType type)
        {
            return $"(objectClass={type.ToADObjectClassName()})";
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
}
