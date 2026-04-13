using System;
using System.Collections.Generic;
using System.Linq;

namespace Pxtl.ADServices
{
    internal static class ADAttributeHelper
    {
        internal static object GetValue(Dictionary<string, object> table, string key)
        {
            return table.TryGetValue(key, out var value) ? value : null;
        }

        internal static bool HasFlag(Dictionary<string, object> table, string key, long mask)
        {
            if (!table.TryGetValue(key, out var raw) || raw == null)
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

        internal static string NormalizeString(object value)
        {
            return value?.ToString();
        }

        internal static long GetLongValue(Dictionary<string, object> table, string key)
        {
            if (table.TryGetValue(key, out var raw) && raw != null)
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

        internal static int GetIntValue(Dictionary<string, object> table, string key)
        {
            if (table.TryGetValue(key, out var raw) && raw != null)
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
