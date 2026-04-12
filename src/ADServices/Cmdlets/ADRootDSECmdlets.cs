using System;
using System.Management.Automation;

namespace Pxtl.ADServices.Cmdlets
{
    [Cmdlet(VerbsCommon.Get, "ADRootDSE")]
    [OutputType(typeof(PSObject))]
    public class GetADRootDSECommand : PSCmdlet
    {
        [Parameter(ValueFromPipelineByPropertyName = true)]
        public string Server { get; set; }

        [Parameter(ValueFromPipelineByPropertyName = true)]
        public PSCredential Credential { get; set; }

        protected override void ProcessRecord()
        {
            var rootDse = ADCommandUtils.TryGetADObject(ADEntryType.RootDSE, "(objectClass=*)", null, null, Server, Credential);
            if (rootDse != null)
            {
                WriteObject(rootDse);
            }
        }
    }

    [Cmdlet(VerbsDiagnostic.Test, "ADRootDSE")]
    [OutputType(typeof(bool))]
    public class TestADRootDSECommand : PSCmdlet 
    {
        [Parameter(ValueFromPipelineByPropertyName = true)]
        public string Server { get; set; }

        [Parameter(ValueFromPipelineByPropertyName = true)]
        public PSCredential Credential { get; set; }

        protected override void ProcessRecord()
        {
            var rootDse = ADCommandUtils.TryGetADObject(ADEntryType.RootDSE, "(objectClass=*)", null, null, Server, Credential);
            if (rootDse != null)
            {
                WriteObject(true);
            }
        }
    }
}

