using System;
using System.Collections.Generic;
using System.Linq;
namespace Pxtl.ADServices
{
    internal class ADRootDSEEntry : ADEntry
    {
        public override void Hydrate(Dictionary<string, object> ldapAttributes)
        {
            base.Hydrate(ldapAttributes);
        }
        public override string MaybeGetDistinguishedName()
            => null;
    }
}
