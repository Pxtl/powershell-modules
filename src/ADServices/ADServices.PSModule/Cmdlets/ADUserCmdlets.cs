using System;
using System.Collections;
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
            var results = ADEntryRepository.TryGetADObjects(ADEntryType.User, LDAPFilter, Identity, null, Server, Credential);
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
        [Parameter(Mandatory = true, ValueFromPipeline = true, Position = 0)]
        public string Name { get; set; }

        [Parameter(Position = 1)]
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
            var entry = ADEntryRepository.NewADObject(ADEntryType.User, "CN", Name, OtherAttributes, Path, "CN=Users", Server, Credential, true, true);
            var identity = entry?.MaybeGetDistinguishedName() ?? Name;
            if (Enabled.HasValue || OtherAttributes != null)
            {
                var currentValue = entry.GetAttributeIntValue("userAccountControl");
                ADEntryRepository.SetADObject(ADEntryType.User, identity, null, null, BuildUserReplace(Enabled, currentValue), Server, Credential, false);
                if (PassThru.ToBool())
                {
                    entry = ADEntryRepository.GetADObject(ADEntryType.User, null, identity, null, Server, Credential);
                }
            }
            if (PassThru.ToBool() && entry != null)
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
        [Parameter(Mandatory = true, ValueFromPipeline = true, Position = 0)]
        public string Identity { get; set; }

        [Parameter(Position = 1)]
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
                var currentValue = ADEntryRepository.GetADObject(ADEntryType.User, null, Identity, null, Server, Credential)
                    .GetAttributeIntValue("userAccountControl");
                replaceTable["userAccountControl"] = Enabled.Value ? (currentValue & ~2) : (currentValue | 2);
            }
            var result = ADEntryRepository.SetADObject(ADEntryType.User, Identity, Add, Remove, replaceTable, Server, Credential, PassThru.ToBool());
            if (PassThru.ToBool() && result != null)
            {
                WriteObject(result);
            }
        }
    }

    [Cmdlet(VerbsCommon.Remove, "ADUser")]
    public class RemoveADUserCommand : PSCmdlet
    {
        [Parameter(Mandatory = true, ValueFromPipeline = true, Position = 0)]
        public string Identity { get; set; }

        [Parameter]
        public string Server { get; set; }

        [Parameter]
        public PSCredential Credential { get; set; }

        protected override void ProcessRecord()
        {
            ADEntryRepository.RemoveADObject(ADEntryType.User, Identity, Server, Credential);
        }
    }

    [Cmdlet(VerbsDiagnostic.Test, "ADUser")]
    [OutputType(typeof(bool))]
    public class TestADUserCommand : PSCmdlet
    {
        [Parameter(Mandatory = true, ValueFromPipeline = true, Position = 0)]
        public string Identity { get; set; }

        [Parameter]
        public string Server { get; set; }

        [Parameter]
        public PSCredential Credential { get; set; }

        protected override void ProcessRecord()
        {
            var result = ADEntryRepository.TestADObject(ADEntryType.User, Identity, Server, Credential);
            WriteObject(result);
        }
    }
}


