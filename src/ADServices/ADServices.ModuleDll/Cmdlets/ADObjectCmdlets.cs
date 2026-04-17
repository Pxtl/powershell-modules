using System;
using System.Collections;
using System.Collections.Generic;
using System.Linq;
using System.Management.Automation;

namespace Pxtl.ADServices.Cmdlets
{
    [Cmdlet(VerbsCommon.Get, "ADObject", DefaultParameterSetName = "Filter")]
    [OutputType(typeof(PSObject))]
    public class GetADObjectCommand : PSCmdlet
    {
        [Parameter(Position = 0)]
        public ADEntryType Type { get; set; }

        [Parameter(Mandatory = true, ValueFromPipeline = true, ParameterSetName = "Filter")]
        public string LDAPFilter { get; set; }

        [Parameter(Mandatory = true, ValueFromPipeline = true, ParameterSetName = "Identity")]
        public string Identity { get; set; }

        [Parameter]
        public string SearchBase { get; set; }

        [Parameter]
        public string Server { get; set; }

        [Parameter]
        public PSCredential Credential { get; set; }

        protected override void ProcessRecord()
        {
            var entries = ADEntryRepository.MaybeGetADObjects(Type, LDAPFilter, Identity, SearchBase, Server, Credential);
            if (!string.IsNullOrEmpty(Identity))
            {
                var list = entries.ToList();
                if (list.Count > 1)
                {
                    throw new InvalidOperationException($"Request for identity value '{Identity}' returned multiple values of class '{Type}'.");
                }
                foreach (var entry in list)
                {
                    WriteObject(entry);
                }
            }
            else
            {
                foreach (var entry in entries)
                {
                    WriteObject(entry);
                }
            }
        }
    }

    [Cmdlet(VerbsCommon.New, "ADObject")]
    [OutputType(typeof(PSObject))]
    public class NewADObjectCommand : PSCmdlet
    {
        [Parameter(Mandatory = true, Position = 0)]
        public ADEntryType Type { get; set; }

        [Parameter(Position = 1)]
        [ValidateSet("CN", "OU")]
        public string DistinguishedComponentType { get; set; } = "CN";

        [Parameter(Mandatory = true, Position = 2, ValueFromPipeline = true)]
        public string Name { get; set; }

        [Parameter(Position = 3)]
        public string Path { get; set; }

        [Parameter]
        public Hashtable OtherAttributes { get; set; }

        [Parameter]
        public string DefaultRelativePath { get; set; }

        [Parameter]
        public string Server { get; set; }

        [Parameter]
        public PSCredential Credential { get; set; }

        [Parameter]
        public SwitchParameter DoSamAccountName { get; set; }

        [Parameter]
        public SwitchParameter PassThru { get; set; }

        protected override void ProcessRecord()
        {
            var passThru = PassThru.ToBool();
            var entry = ADEntryRepository.NewADObject(Type, DistinguishedComponentType, Name, OtherAttributes, Path, DefaultRelativePath, Server, Credential, DoSamAccountName.ToBool(), PassThru);
            if (passThru && entry != null)
            {
                WriteObject(entry);
            }
        }
    }

    [Cmdlet(VerbsCommon.Set, "ADObject")]
    [OutputType(typeof(PSObject))]
    public class SetADObjectCommand : PSCmdlet
    {
        [Parameter(Position = 0)]
        public ADEntryType Type { get; set; }

        [Parameter(Mandatory = true, Position = 1, ValueFromPipeline = true)]
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
            var result = ADEntryRepository.SetADObject(Type, Identity, Add, Remove, Replace, Server, Credential, PassThru.ToBool());
            if (PassThru.ToBool() && result != null)
            {
                WriteObject(result);
            }
        }
    }

    [Cmdlet(VerbsCommon.Remove, "ADObject")]
    public class RemoveADObjectCommand : PSCmdlet
    {
        [Parameter(Position = 0)]
        public ADEntryType Type { get; set; }

        [Parameter(Mandatory = true, Position = 1, ValueFromPipeline = true)]
        public string Identity { get; set; }

        [Parameter]
        public string Server { get; set; }

        [Parameter]
        public PSCredential Credential { get; set; }

        protected override void ProcessRecord()
        {
            ADEntryRepository.RemoveADObject(Type, Identity, Server, Credential);
        }
    }

    [Cmdlet(VerbsDiagnostic.Test, "ADObject")]
    [OutputType(typeof(bool))]
    public class TestADObjectCommand : PSCmdlet
    {
        [Parameter(Position = 0)]
        public ADEntryType Type { get; set; }

        [Parameter(Mandatory = true, Position = 1, ValueFromPipeline = true)]
        public string Identity { get; set; }

        [Parameter]
        public string Server { get; set; }

        [Parameter]
        public PSCredential Credential { get; set; }

        protected override void ProcessRecord()
        {
            var result = ADEntryRepository.TestADObject(Type, Identity, Server, Credential);
            WriteObject(result);
        }
    }
}

