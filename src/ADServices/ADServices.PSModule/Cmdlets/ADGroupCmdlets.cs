using System;
using System.Collections;
using System.Management.Automation;
using System.ComponentModel;

namespace Pxtl.ADServices.Cmdlets
{
    /// <summary>
    /// Retrieves an Active Directory group by Identity or LDAP Filter. Returns
    /// nothing if not found.
    /// </summary>
    [Cmdlet(VerbsCommon.Get, "ADGroup", DefaultParameterSetName = "Filter")]
    [OutputType(typeof(PSObject))]
    public class GetADGroupCommand : PSCmdlet
    {
        
        /// <summary>
        /// The LDAP filter to search for groups. Uses normal LDAP Search
        /// syntax, *not* PS ActiveDirectory search.
        /// </summary>
        [Parameter(Mandatory = true, ValueFromPipeline = true, ParameterSetName = "Filter")]
        public string LDAPFilter { get; set; }

        /// <summary>
        /// The identity of the group to retrieve. Can be sAMAcountName, SID,
        /// LDAP path, or distinguished name.
        /// </summary>
        [Parameter(Mandatory = true, ValueFromPipeline = true, ParameterSetName = "Identity")]
        public string Identity { get; set; }

        /// <summary>
        /// The domain controller to query.
        /// </summary>
        [Parameter]
        public string Server { get; set; }

        /// <summary>
        /// Credentials for the domain controller.
        /// </summary>
        [Parameter]
        public PSCredential Credential { get; set; }

        protected override void ProcessRecord()
        {
            var results = ADEntryRepository.MaybeGetADObjects<ADGroupEntry>(LDAPFilter, Identity, null, Server, Credential);
            foreach (var result in results)
            {
                WriteObject(result);
            }
        }
    }

    [Cmdlet(VerbsCommon.New, "ADGroup")]
    [OutputType(typeof(PSObject))]
    public class NewADGroupCommand : PSCmdlet
    {
        [Parameter(Mandatory = true, ValueFromPipeline = true, Position = 0)]
        public string Name { get; set; }

        [Parameter]
        [ValidateSet("", "Distribution", "Security")]
        public string GroupCategory { get; set; }

        [Parameter]
        [ValidateSet("", "Global", "DomainLocal", "Universal")]
        public string GroupScope { get; set; }

        [Parameter]
        public Hashtable OtherAttributes { get; set; }

        [Parameter]
        public string Server { get; set; }

        [Parameter]
        public PSCredential Credential { get; set; }

        [Parameter]
        public SwitchParameter PassThru { get; set; }

        protected override void ProcessRecord()
        {
            var entry = ADEntryRepository.NewADObject(ADEntryType.Group, "CN", Name, OtherAttributes, null, "CN=Users", Server, Credential, true, true);
            var identity = entry?.MaybeGetDistinguishedName() ?? Name;
            if (!string.IsNullOrWhiteSpace(GroupCategory) || !string.IsNullOrWhiteSpace(GroupScope))
            {
                ADEntryRepository.SetADObject(ADEntryType.Group, identity, null, null, BuildGroupUpdates(GroupCategory, GroupScope), Server, Credential, false);
            }
            if (PassThru.ToBool() && entry != null)
            {
                WriteObject(entry);
            }
        }

        private Hashtable BuildGroupUpdates(string category, string scope)
        {
            var table = new Hashtable(StringComparer.OrdinalIgnoreCase);
            if (!string.IsNullOrWhiteSpace(category) || !string.IsNullOrWhiteSpace(scope))
            {
                var current = ADEntryRepository.MaybeGetADObject<ADGroupEntry>(null, Name, null, Server, Credential);
                var currentType = current.GetAttributeIntValue("groupType");
                table["groupType"] = ComputeGroupType(currentType, category, scope);
            }
            return table;
        }

        private static long ComputeGroupType(long groupType, string category, string scope)
        {
            if (!string.IsNullOrWhiteSpace(category))
            {
                if (category.Equals("Security", StringComparison.OrdinalIgnoreCase))
                {
                    groupType |= GroupTypeFlags.SECURITY_ENABLED;
                }
                else
                {
                    groupType &= ~GroupTypeFlags.SECURITY_ENABLED;
                }
            }
            if (!string.IsNullOrWhiteSpace(scope))
            {
                groupType &= ~(GroupTypeFlags.ACCOUNT_GROUP | GroupTypeFlags.RESOURCE_GROUP | GroupTypeFlags.UNIVERSAL_GROUP);
                groupType |= scope switch
                {
                    "Global" => GroupTypeFlags.ACCOUNT_GROUP,
                    "DomainLocal" => GroupTypeFlags.RESOURCE_GROUP,
                    "Universal" => GroupTypeFlags.UNIVERSAL_GROUP,
                    _ => throw new InvalidOperationException($"{nameof(scope)} was not a possible value.")
                };
            }
            return groupType;
        }
    }

    [Cmdlet(VerbsCommon.Set, "ADGroup")]
    [OutputType(typeof(PSObject))]
    public class SetADGroupCommand : PSCmdlet
    {
        [Parameter(Mandatory = true, ValueFromPipeline = true, Position = 0)]
        public string Identity { get; set; }

        [Parameter]
        [ValidateSet("", "Distribution", "Security")]
        public string GroupCategory { get; set; }

        [Parameter]
        [ValidateSet("", "Global", "DomainLocal", "Universal")]
        public string GroupScope { get; set; }

        [Parameter]
        public Hashtable Add { get; set; }

        [Parameter]
        public Hashtable Remove { get; set; }

        [Parameter]
        public Hashtable Replace { get; set; }

        [Parameter]
        public string Server { get; set; }

        [Parameter]
        public PSCredential Credential { get; set; }

        [Parameter]
        public SwitchParameter PassThru { get; set; }

        protected override void ProcessRecord()
        {
            var replacements = Replace != null ? new Hashtable(Replace, StringComparer.OrdinalIgnoreCase) : new Hashtable(StringComparer.OrdinalIgnoreCase);
            var current = ADEntryRepository.GetADObject(ADEntryType.Group, null, Identity, null, Server, Credential);
            var currentType = current.GetAttributeIntValue("groupType");
            if (!string.IsNullOrWhiteSpace(GroupCategory) || !string.IsNullOrWhiteSpace(GroupScope))
            {
                replacements["groupType"] = ComputeGroupType(currentType, GroupCategory, GroupScope);
            }
            var result = ADEntryRepository.SetADObject(ADEntryType.Group, Identity, Add, Remove, replacements, Server, Credential, PassThru.ToBool());
            if (PassThru.ToBool() && result != null)
            {
                WriteObject(result);
            }
        }

        private static int ComputeGroupType(int currentType, string category, string scope)
        {
            var typeValue = currentType;
            if (!string.IsNullOrWhiteSpace(category))
            {
                if (category.Equals("Security", StringComparison.OrdinalIgnoreCase))
                {
                    typeValue |= unchecked((int)0x80000000);
                }
                else
                {
                    typeValue &= ~unchecked((int)0x80000000);
                }
            }
            if (!string.IsNullOrWhiteSpace(scope))
            {
                typeValue &= ~(0x02 | 0x04 | 0x08);
                typeValue |= scope switch
                {
                    "Global" => 0x02,
                    "DomainLocal" => 0x04,
                    "Universal" => 0x08,
                    _ => 0
                };
            }
            return typeValue;
        }
    }

    [Cmdlet(VerbsCommon.Remove, "ADGroup")]
    public class RemoveADGroupCommand : PSCmdlet
    {
        [Parameter(Mandatory = true, ValueFromPipeline = true, Position = 0)]
        public string Identity { get; set; }

        [Parameter]
        public string Server { get; set; }

        [Parameter]
        public PSCredential Credential { get; set; }

        protected override void ProcessRecord()
        {
            ADEntryRepository.RemoveADObject(ADEntryType.Group, Identity, Server, Credential);
        }
    }

    [Cmdlet(VerbsDiagnostic.Test, "ADGroup")]
    [OutputType(typeof(bool))]
    public class TestADGroupCommand : PSCmdlet
    {
        [Parameter(Mandatory = true, ValueFromPipeline = true, Position = 0)]
        public string Identity { get; set; }

        [Parameter]
        public string Server { get; set; }

        [Parameter]
        public PSCredential Credential { get; set; }

        protected override void ProcessRecord()
        {
            var result = ADEntryRepository.TestADObject(ADEntryType.Group, Identity, Server, Credential);
            WriteObject(result);
        }
    }
}


