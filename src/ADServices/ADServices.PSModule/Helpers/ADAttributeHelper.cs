using System;
using System.Collections.Generic;
using System.Linq;

namespace Pxtl.ADServices
{
    internal static class ADAttributeHelper
    {
        /// <summary>
        /// Get value from attributes dictionary. Returns null if not found.
        /// </summary>
        internal static object GetValue(Dictionary<string, object> attributes, string key)
        {
            return attributes.TryGetValue(key, out var value) ? value : null;
        }


        /// <summary>
        /// Gets a bitfield flag within the elements of a given Attributes dictionary
        /// </summary>
        /// <returns></returns>
        internal static bool HasFlag(Dictionary<string, object> attributes, string key, long mask)
        {
            if (!attributes.TryGetValue(key, out var raw) || raw == null)
            {
                return false;
            }

            if (raw is int intValue)
            {
                return ((long)intValue & mask) != 0;
            }
            if (raw is long longValue)
            {
                return (longValue & mask) != 0;
            }
            if (long.TryParse(raw.ToString(), out var parsed))
            {
                return (parsed & mask) != 0;
            }
            return false;
        }

        /// <summary>
        /// Convert object reference to string, even if the object is null.
        /// </summary>
        internal static string NormalizeString(object value)
        {
            return value?.ToString();
        }

        /// <summary>
        /// Get long value from dictionary.  Convert to long if it's not already
        /// a long if possible.
        /// </summary>
        internal static long GetLongValue(Dictionary<string, object> attributes, string key)
        {
            if (attributes.TryGetValue(key, out var raw) && raw != null)
            {
                return raw switch
                {
                    int i => i,
                    long l => l,
                    string s when long.TryParse(s, out var result) => result,
                    _ when long.TryParse(raw.ToString(), out var result) => result,
                    _ => 0L
                };
            }
            return 0L;
        }

        /// <summary>
        /// Get int value from dictionary.  Convert to int if it's not already
        /// an int if possible.
        /// </summary>
        internal static int GetIntValue(Dictionary<string, object> attributes, string key)
        {
            if (attributes.TryGetValue(key, out var raw) && raw != null)
            {
                return raw switch
                {
                    int i => i,
                    string s when int.TryParse(s, out var result) => result,
                    _ when int.TryParse(raw.ToString(), out var result) => result,
                    _ => 0
                };
            }
            return 0;
        }
    }
}
