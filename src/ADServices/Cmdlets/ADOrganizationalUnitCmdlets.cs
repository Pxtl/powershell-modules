using System;
using System.Collections;
using System.Management.Automation;

namespace Pxtl.ADServices.Cmdlets
{
    [Cmdlet(VerbsCommon.Get, "ADOrganizationalUnit", DefaultParameterSetName = "Filter")]
    [OutputType(typeof(ADOrganizationalUnitEntry))]
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
            var results = ADCommandUtils.TryGetADObjects(ADEntryType.OrganizationalUnit, LDAPFilter, Identity, null, Server, Credential);
            foreach (var result in results)
            {
                WriteObject(result);
            }
        }
    }

    [Cmdlet(VerbsCommon.New, "ADOrganizationalUnit")]
    [OutputType(typeof(ADOrganizationalUnitEntry))]
    public class NewADOrganizationalUnitCommand : PSCmdlet
    {
        [Parameter(Mandatory = true, ValueFromPipeline = true, Position = 0)]
        public string Name { get; set; }

        [Parameter(Position = 1)]
        public string Path { get; set; }

        [Parameter]
        public Hashtable OtherAttributes { get; set; }

        [Parameter]
        public string Server { get; set; }

        [Parameter]
        public PSCredential Credential { get; set; }

        [Parameter]
        public SwitchParameter PassThru { get; set; }

        protected override void BeginProcessing()
        {}

        protected override void ProcessRecord()
        {
            var entry = ADCommandUtils.NewADObject(ADEntryType.OrganizationalUnit, "OU", Name, OtherAttributes, Path, null, Server, Credential, true, true);
            var identity = entry?.MaybeGetDistinguishedName() ?? Name;
            if (OtherAttributes != null)
            {
                ADCommandUtils.SetADObject(ADEntryType.OrganizationalUnit, identity, null, null, OtherAttributes, Server, Credential, false);
                if (PassThru.IsPresent)
                {
                    entry = ADCommandUtils.GetADObject(ADEntryType.OrganizationalUnit, null, identity, null, Server, Credential);
                }
            }
            if (PassThru.IsPresent && entry != null)
            {
                WriteObject(entry);
            }
        }
    }

    [Cmdlet(VerbsCommon.Set, "ADOrganizationalUnit")]
    [OutputType(typeof(ADOrganizationalUnitEntry))]
    public class SetADOrganizationalUnitCommand : PSCmdlet
    {
        [Parameter(Mandatory = true, ValueFromPipeline = true, Position = 0)]
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
            var result = ADCommandUtils.SetADObject(ADEntryType.OrganizationalUnit, Identity, Add, Remove, Replace, Server, Credential, PassThru.IsPresent);
            if (PassThru.IsPresent && result != null)
            {
                WriteObject(result);
            }
        }
    }

    [Cmdlet(VerbsCommon.Remove, "ADOrganizationalUnit")]
    public class RemoveADOrganizationalUnitCommand : PSCmdlet
    {
        [Parameter(Mandatory = true, ValueFromPipeline = true, Position = 0)]
        public string Identity { get; set; }

        [Parameter]
        public string Server { get; set; }

        [Parameter]
        public PSCredential Credential { get; set; }

        protected override void ProcessRecord()
        {
            ADCommandUtils.RemoveADObject(ADEntryType.OrganizationalUnit, Identity, Server, Credential);
        }
    }

    [Cmdlet(VerbsDiagnostic.Test, "ADOrganizationalUnit")]
    [OutputType(typeof(bool))]
    public class TestADOrganizationalUnitCommand : PSCmdlet
    {
        [Parameter(Mandatory = true, ValueFromPipeline = true, Position = 0)]
        public string Identity { get; set; }

        [Parameter]
        public string Server { get; set; }

        [Parameter]
        public PSCredential Credential { get; set; }

        protected override void ProcessRecord()
        {
            var result = ADCommandUtils.TestADObject(ADEntryType.OrganizationalUnit, Identity, Server, Credential);
            WriteObject(result);
        }
    }
}


