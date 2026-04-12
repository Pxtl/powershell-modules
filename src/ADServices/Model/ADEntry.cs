using System;
using System.Collections.Generic;
using System.Linq;

namespace Pxtl.ADServices
{
    public abstract class ADEntry
    {
        #region Constructors
        public ADEntry()
        {
            Attributes = new Dictionary<string, object>(StringComparer.OrdinalIgnoreCase);
        }
        #endregion

        #region Properties
        public Dictionary<string, object> Attributes { get; }
        public IReadOnlyDictionary<string, object> Properties => Attributes;
        #endregion

        #region Methods
        public virtual void Hydrate(Dictionary<string, object> ldapAttributes)
        {
            Attributes.Clear();
            foreach (var pair in ldapAttributes.AsEnumerable().OrderBy(p => p.Key, StringComparer.OrdinalIgnoreCase))
            {
                Attributes[pair.Key] = pair.Value;
            }
        }

        public int GetAttributeIntValue(string attributeName)
        {
            if (Attributes.TryGetValue(attributeName, out var raw) == true)
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

        /// <summary>
        /// Not all ADEntry objects have a DistinguishedName (ADRootDSE does
        /// not), but the DistinguishedName is used for logging so need a method
        /// that will not fail.
        /// </summary>
        /// <remarks>
        /// TODO: Come up with a better name. Should this just be ToString?
        /// Should type ObjectClass be logged as well?
        /// </remarks>
        public abstract string MaybeGetDistinguishedName();
        #endregion
    }
}