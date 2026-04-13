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
    }
}
