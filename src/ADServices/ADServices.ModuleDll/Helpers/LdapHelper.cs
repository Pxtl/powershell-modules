using System;
using System.Collections;
using System.Collections.Generic;
using System.DirectoryServices.Protocols;
using System.Linq;
using System.Management.Automation;
using System.Text;
using System.Text.RegularExpressions;

namespace Pxtl.ADServices
{
    public static class LdapHelper
    {
        public static readonly string ADRootDSEFilter = "(objectClass=*)";
        public static LdapConnection CreateConnection(string server, PSCredential credential)
        {
            LdapDirectoryIdentifier identifier = null;
            if (Regex.IsMatch(server, @"^.*:\d+$"))
            {
                // server has a port number.  There's a known bug in .net
                // runtime on linux where port numbers aren't supported in the
                // server name as on Windows.  Extract it and use the alternate
                // LdapDirectoryIdentifier constructor as workaround.
                var port = int.Parse(server.Split(':')[1]);
                server = server.Split(':')[0];
                identifier = new LdapDirectoryIdentifier(server, port);
            } else
            {
                identifier = new LdapDirectoryIdentifier(server);
            }
            var networkCredential = credential?.GetNetworkCredential();
            // TODO: support other connection types
            // NOTE: Linux System.DirectoryServices.Protocols 10.0.5 only supports AuthType.Basic
            var connection = new LdapConnection(identifier, networkCredential, AuthType.Basic);
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
            var entry = SearchObjects<ADRootDSEEntry>(ADRootDSEFilter, null, server, credential, "defaultNamingContext")
                .FirstOrDefault();
            if (entry == null)
            {
                return null;
            }
            return (string)entry.Attributes["defaultNamingContext"];
        }

        public static IEnumerable<T> SearchObjects<T>(string filter, string searchBase, string server, PSCredential credential, params string[] attributeList)
            where T : ADEntry, new()
        {
            var searchScope = SearchScope.Subtree;

            // special search params needed for ADRootDSE.
            if (typeof(T) == typeof(ADRootDSEEntry))
            {
                searchScope = SearchScope.Base;
                searchBase = null;
            }
            else if (string.IsNullOrWhiteSpace(searchBase))
            {
                searchBase = GetDefaultNamingContext(server, credential);
            }

            using var connection = CreateConnection(server, credential);
            var request = new SearchRequest(searchBase, filter, searchScope, attributeList);
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
                            // can't use the SID object provided by the framework or netstandard2.0 complains.
                            values.Add(ConvertByteToStringSid(bytes));
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
            else if (values.All(v => v is int))
            {
                return CreateAttributeModification(name, values.Select(v => v.ToString()), operation);
            }
            else if (values.All(v => v is long))
            {
                return CreateAttributeModification(name, values.Select(v => v.ToString()), operation);
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
                throw new ArgumentException($"{nameof(value)} must be either a byte[], string, int, long, or Uri, or an array thereof.", nameof(value));
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

        /// <summary>
        /// Normally the way to convert a binary SID to a String is to use
        /// System.Security.Principal.SecurityIdentifier, but that class is
        /// incompatible with netstandard2.0, so we must use an alternate
        /// implementation.
        /// </summary>
        /// <remarks>
        /// Adapted from
        /// https://gist.github.com/thohng/8820153f7d1e107b6619b34fd765f887 .
        /// Some modifications were needed to run it on NET48.  This code
        /// requires the use of ReadOnlySpan objects, which are not supported in
        /// netstandard2.0 without the System.Memory polyfill nuget package.
        /// </remarks>
        public static string ConvertByteToStringSid(byte[] sidBytes)
        {
            if (sidBytes == null || sidBytes.Length < 8 ||
                sidBytes.Length > 68)   // maximum 15 sub authorities
                return string.Empty;

            var span = new ReadOnlySpan<byte>(sidBytes);

            var strSid = new StringBuilder("S-");

            // Add SID revision.
            strSid.Append(span[0]);

            // Get sub authority count...
            var subAuthoritiesLength = Convert.ToInt32(span[1]);
            if (sidBytes.Length != 8 + subAuthoritiesLength * 4)
                return string.Empty;

            long identifierAuthority =
                (((long)span[2]) << 40) +
                (((long)span[3]) << 32) +
                (((long)span[4]) << 24) +
                (((long)span[5]) << 16) +
                (((long)span[6]) << 8) +
                span[7];
            strSid.Append('-');
            strSid.Append(identifierAuthority);

            span = span.Slice(8);

            for (int i = 0; i < subAuthoritiesLength; i++, span = span.Slice(4))
            {
                strSid.Append('-');
                strSid.Append(BitConverter.ToUInt32(span.Slice(0, 4).ToArray(), 0));
            }

            return strSid.ToString();
        }
    }
}
