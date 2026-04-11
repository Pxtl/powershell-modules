using System;
using System.Collections;
using System.Collections.Generic;
using System.Linq;
using System.Management.Automation;

namespace Pxtl.ADServices.Cmdlets
{
    [Cmdlet(VerbsCommon.Get, "ADUser", DefaultParameterSetName = "Filter")]
    [OutputType(typeof(PSObject))]
    public class GetADUserCommand : PSCmdlet
    {
        [Parameter(Mandatory = true, ValueFromPipeline = true, ParameterSetName = "Filter")]
        public string LDAPFilter { get; set; }

        [Parameter(Mandatory = true, ValueFromPipeline = true, ParameterSetName = "Identity")]
        public string Identity { get; set; }

        [Parameter]
        public string Server { get; set; }

        [Parameter]
        public PSCredential Credential { get; set; }

        protected override void ProcessRecord()
        {
            var results = ADCommandUtils.GetADObjects("user", LDAPFilter, Identity, null, Server, Credential, ADPropertyConverters.ConvertAdUser);
            foreach (var result in results)
            {
                WriteObject(result);
            }
        }
    }

    [Cmdlet(VerbsCommon.New, "ADUser")]
    [OutputType(typeof(PSObject))]
    public class NewADUserCommand : PSCmdlet
    {
        [Parameter(Mandatory = true)]
        public string Name { get; set; }

        [Parameter]
        public string Path { get; set; }

        [Parameter]
        public bool? Enabled { get; set; }

        [Parameter]
        public Hashtable OtherAttributes { get; set; }

        [Parameter]
        public string Server { get; set; }

        [Parameter]
        public PSCredential Credential { get; set; }

        [Parameter]
        public SwitchParameter PassThru { get; set; }

        protected override void BeginProcessing()
        {
            if (!Enabled.HasValue)
            {
                Enabled = true;
            }
        }

        protected override void ProcessRecord()
        {
            var entry = ADCommandUtils.NewADObject("user", "CN", Name, OtherAttributes, Path, "CN=Users", Server, Credential, true, true, ADPropertyConverters.ConvertAdUser);
            var identity = ADCommandUtils.GetDistinguishedName(entry) ?? Name;
            if (Enabled.HasValue || OtherAttributes != null)
            {
                var currentValue = ADCommandUtils.GetAttributeIntValue(entry, "userAccountControl");
                ADCommandUtils.SetADObject("user", identity, null, null, BuildUserReplace(Enabled, currentValue), Server, Credential, false, ADPropertyConverters.ConvertAdUser);
                if (PassThru.IsPresent)
                {
                    entry = ADCommandUtils.GetADObject("user", null, identity, null, Server, Credential, ADPropertyConverters.ConvertAdUser);
                }
            }
            if (PassThru.IsPresent && entry != null)
            {
                WriteObject(entry);
            }
        }

        private Hashtable BuildUserReplace(bool? enabled, int currentValue)
        {
            var table = new Hashtable(StringComparer.OrdinalIgnoreCase);
            if (enabled.HasValue)
            {
                table["userAccountControl"] = enabled.Value ? (currentValue & ~2) : (currentValue | 2);
            }
            return table;
        }
    }

    [Cmdlet(VerbsCommon.Set, "ADUser")]
    [OutputType(typeof(PSObject))]
    public class SetADUserCommand : PSCmdlet
    {
        [Parameter(Mandatory = true, ValueFromPipeline = true)]
        public string Identity { get; set; }

        [Parameter]
        public bool? Enabled { get; set; }

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
            var replaceTable = Replace != null ? new Hashtable(Replace, StringComparer.OrdinalIgnoreCase) : new Hashtable(StringComparer.OrdinalIgnoreCase);
            if (Enabled.HasValue)
            {
                var currentValue = ADCommandUtils.GetAttributeIntValue(ADCommandUtils.GetADObject("user", null, Identity, null, Server, Credential, ADPropertyConverters.ConvertAdUser), "userAccountControl");
                replaceTable["userAccountControl"] = Enabled.Value ? (currentValue & ~2) : (currentValue | 2);
            }
            var result = ADCommandUtils.SetADObject("user", Identity, Add, Remove, replaceTable, Server, Credential, PassThru.IsPresent, ADPropertyConverters.ConvertAdUser);
            if (PassThru.IsPresent && result != null)
            {
                WriteObject(result);
            }
        }
    }

    [Cmdlet(VerbsCommon.Remove, "ADUser")]
    public class RemoveADUserCommand : PSCmdlet
    {
        [Parameter(Mandatory = true, ValueFromPipeline = true)]
        public string Identity { get; set; }

        [Parameter]
        public string Server { get; set; }

        [Parameter]
        public PSCredential Credential { get; set; }

        protected override void ProcessRecord()
        {
            ADCommandUtils.RemoveADObject("user", Identity, Server, Credential, ADPropertyConverters.ConvertAdUser);
        }
    }

    [Cmdlet(VerbsDiagnostic.Test, "ADUser")]
    [OutputType(typeof(bool))]
    public class TestADUserCommand : PSCmdlet
    {
        [Parameter(Mandatory = true, ValueFromPipeline = true)]
        public string Identity { get; set; }

        [Parameter]
        public string Server { get; set; }

        [Parameter]
        public PSCredential Credential { get; set; }

        protected override void ProcessRecord()
        {
            var result = ADCommandUtils.TestADObject("user", Identity, Server, Credential, ADPropertyConverters.ConvertAdUser);
            WriteObject(result);
        }
    }

    [Cmdlet(VerbsLifecycle.Enable, "ADAccount")]
    [OutputType(typeof(PSObject))]
    public class EnableADAccountCommand : PSCmdlet
    {
        [Parameter(Mandatory = true, ValueFromPipeline = true)]
        public string Identity { get; set; }

        [Parameter]
        public string Server { get; set; }

        [Parameter]
        public PSCredential Credential { get; set; }

        [Parameter]
        public SwitchParameter PassThru { get; set; }

        protected override void ProcessRecord()
        {
            var existing = ADCommandUtils.GetADObject("user", null, Identity, null, Server, Credential, ADPropertyConverters.ConvertAdUser);
            var currentValue = ADCommandUtils.GetAttributeIntValue(existing, "userAccountControl");
            var result = ADCommandUtils.SetADObject("user", Identity, null, null, new Hashtable { ["userAccountControl"] = currentValue & ~2 }, Server, Credential, PassThru.IsPresent, ADPropertyConverters.ConvertAdUser);
            if (PassThru.IsPresent && result != null)
            {
                WriteObject(result);
            }
        }
    }

    [Cmdlet(VerbsLifecycle.Disable, "ADAccount")]
    [OutputType(typeof(PSObject))]
    public class DisableADAccountCommand : PSCmdlet
    {
        [Parameter(Mandatory = true, ValueFromPipeline = true)]
        public string Identity { get; set; }

        [Parameter]
        public string Server { get; set; }

        [Parameter]
        public PSCredential Credential { get; set; }

        [Parameter]
        public SwitchParameter PassThru { get; set; }

        protected override void ProcessRecord()
        {
            var existing = ADCommandUtils.GetADObject("user", null, Identity, null, Server, Credential, ADPropertyConverters.ConvertAdUser);
            var currentValue = ADCommandUtils.GetAttributeIntValue(existing, "userAccountControl");
            var result = ADCommandUtils.SetADObject("user", Identity, null, null, new Hashtable { ["userAccountControl"] = currentValue | 2 }, Server, Credential, PassThru.IsPresent, ADPropertyConverters.ConvertAdUser);
            if (PassThru.IsPresent && result != null)
            {
                WriteObject(result);
            }
        }
    }

    [Cmdlet(VerbsCommon.Get, "ADGroup", DefaultParameterSetName = "Filter")]
    [OutputType(typeof(PSObject))]
    public class GetADGroupCommand : PSCmdlet
    {
        [Parameter(Mandatory = true, ValueFromPipeline = true, ParameterSetName = "Filter")]
        public string LDAPFilter { get; set; }

        [Parameter(Mandatory = true, ValueFromPipeline = true, ParameterSetName = "Identity")]
        public string Identity { get; set; }

        [Parameter]
        public string Server { get; set; }

        [Parameter]
        public PSCredential Credential { get; set; }

        protected override void ProcessRecord()
        {
            var results = ADCommandUtils.GetADObjects("group", LDAPFilter, Identity, null, Server, Credential, ADPropertyConverters.ConvertAdGroup);
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
        [Parameter(Mandatory = true, ValueFromPipeline = true)]
        public string Name { get; set; }

        [Parameter]
        public string Path { get; set; }

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
            var entry = ADCommandUtils.NewADObject("group", "CN", Name, OtherAttributes, Path, "CN=Users", Server, Credential, true, true, ADPropertyConverters.ConvertAdGroup);
            var identity = ADCommandUtils.GetDistinguishedName(entry) ?? Name;
            if (!string.IsNullOrWhiteSpace(GroupCategory) || !string.IsNullOrWhiteSpace(GroupScope))
            {
                ADCommandUtils.SetADObject("group", identity, null, null, BuildGroupUpdates(GroupCategory, GroupScope), Server, Credential, false, ADPropertyConverters.ConvertAdGroup);
            }
            if (PassThru.IsPresent && entry != null)
            {
                WriteObject(entry);
            }
        }

        private Hashtable BuildGroupUpdates(string category, string scope)
        {
            var table = new Hashtable(StringComparer.OrdinalIgnoreCase);
            if (!string.IsNullOrWhiteSpace(category) || !string.IsNullOrWhiteSpace(scope))
            {
                var current = ADCommandUtils.GetADObject("group", null, Name, null, Server, Credential, ADPropertyConverters.ConvertAdGroup);
                var currentType = ADCommandUtils.GetAttributeIntValue(current, "groupType");
                table["groupType"] = ComputeGroupType(currentType, category, scope);
            }
            return table;
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

    [Cmdlet(VerbsCommon.Set, "ADGroup")]
    [OutputType(typeof(PSObject))]
    public class SetADGroupCommand : PSCmdlet
    {
        [Parameter(Mandatory = true, ValueFromPipeline = true)]
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
            var current = ADCommandUtils.GetADObject("group", null, Identity, null, Server, Credential, ADPropertyConverters.ConvertAdGroup);
            var currentType = 0;
            if (current?.Properties["groupType"]?.Value is int intValue)
            {
                currentType = intValue;
            }
            else if (current?.Properties["groupType"]?.Value is long longValue)
            {
                currentType = (int)longValue;
            }
            if (!string.IsNullOrWhiteSpace(GroupCategory) || !string.IsNullOrWhiteSpace(GroupScope))
            {
                replacements["groupType"] = ComputeGroupType(currentType, GroupCategory, GroupScope);
            }
            var result = ADCommandUtils.SetADObject("group", Identity, Add, Remove, replacements, Server, Credential, PassThru.IsPresent, ADPropertyConverters.ConvertAdGroup);
            if (PassThru.IsPresent && result != null)
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
        [Parameter(Mandatory = true, ValueFromPipeline = true)]
        public string Identity { get; set; }

        [Parameter]
        public string Server { get; set; }

        [Parameter]
        public PSCredential Credential { get; set; }

        protected override void ProcessRecord()
        {
            ADCommandUtils.RemoveADObject("group", Identity, Server, Credential, ADPropertyConverters.ConvertAdGroup);
        }
    }

    [Cmdlet(VerbsDiagnostic.Test, "ADGroup")]
    [OutputType(typeof(bool))]
    public class TestADGroupCommand : PSCmdlet
    {
        [Parameter(Mandatory = true, ValueFromPipeline = true)]
        public string Identity { get; set; }

        [Parameter]
        public string Server { get; set; }

        [Parameter]
        public PSCredential Credential { get; set; }

        protected override void ProcessRecord()
        {
            var result = ADCommandUtils.TestADObject("group", Identity, Server, Credential, ADPropertyConverters.ConvertAdGroup);
            WriteObject(result);
        }
    }

    [Cmdlet(VerbsCommon.Get, "ADOrganizationalUnit", DefaultParameterSetName = "Filter")]
    [OutputType(typeof(PSObject))]
    public class GetADOrganizationalUnitCommand : PSCmdlet
    {
        [Parameter(Mandatory = true, ValueFromPipeline = true, ParameterSetName = "Filter")]
        public string LDAPFilter { get; set; }

        [Parameter(Mandatory = true, ValueFromPipeline = true, ParameterSetName = "Identity")]
        public string Identity { get; set; }

        [Parameter]
        public string Server { get; set; }

        [Parameter]
        public PSCredential Credential { get; set; }

        protected override void ProcessRecord()
        {
            var results = ADCommandUtils.GetADObjects("organizationalUnit", LDAPFilter, Identity, null, Server, Credential, ADPropertyConverters.ConvertAdOrganizationalUnit);
            foreach (var result in results)
            {
                WriteObject(result);
            }
        }
    }

    [Cmdlet(VerbsCommon.New, "ADOrganizationalUnit")]
    [OutputType(typeof(PSObject))]
    public class NewADOrganizationalUnitCommand : PSCmdlet
    {
        [Parameter(Mandatory = true, ValueFromPipeline = true)]
        public string Name { get; set; }

        [Parameter]
        public string Path { get; set; }

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
            var entry = ADCommandUtils.NewADObject("organizationalUnit", "OU", Name, OtherAttributes, Path, null, Server, Credential, false, true, ADPropertyConverters.ConvertAdOrganizationalUnit);
            if (PassThru.IsPresent && entry != null)
            {
                WriteObject(entry);
            }
        }
    }

    [Cmdlet(VerbsCommon.Set, "ADOrganizationalUnit")]
    [OutputType(typeof(PSObject))]
    public class SetADOrganizationalUnitCommand : PSCmdlet
    {
        [Parameter(Mandatory = true, ValueFromPipeline = true)]
        public string Identity { get; set; }

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
            var result = ADCommandUtils.SetADObject("organizationalUnit", Identity, Add, Remove, Replace, Server, Credential, PassThru.IsPresent, ADPropertyConverters.ConvertAdOrganizationalUnit);
            if (PassThru.IsPresent && result != null)
            {
                WriteObject(result);
            }
        }
    }

    [Cmdlet(VerbsCommon.Remove, "ADOrganizationalUnit")]
    public class RemoveADOrganizationalUnitCommand : PSCmdlet
    {
        [Parameter(Mandatory = true, ValueFromPipeline = true)]
        public string Identity { get; set; }

        [Parameter]
        public string Server { get; set; }

        [Parameter]
        public PSCredential Credential { get; set; }

        protected override void ProcessRecord()
        {
            ADCommandUtils.RemoveADObject("organizationalUnit", Identity, Server, Credential, ADPropertyConverters.ConvertAdOrganizationalUnit);
        }
    }

    [Cmdlet(VerbsDiagnostic.Test, "ADOrganizationalUnit")]
    [OutputType(typeof(bool))]
    public class TestADOrganizationalUnitCommand : PSCmdlet
    {
        [Parameter(Mandatory = true, ValueFromPipeline = true)]
        public string Identity { get; set; }

        [Parameter]
        public string Server { get; set; }

        [Parameter]
        public PSCredential Credential { get; set; }

        protected override void ProcessRecord()
        {
            var result = ADCommandUtils.TestADObject("organizationalUnit", Identity, Server, Credential, ADPropertyConverters.ConvertAdOrganizationalUnit);
            WriteObject(result);
        }
    }
}
