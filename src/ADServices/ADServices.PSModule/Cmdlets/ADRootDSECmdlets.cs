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
            var rootDse = ADEntryRepository.MaybeGetADObject<ADRootDSEEntry>("(objectClass=*)", null, null, Server, Credential);
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
            ADRootDSEEntry entry = null;
            try 
            {
                entry = ADEntryRepository.MaybeGetADObject<ADRootDSEEntry>("(objectClass=*)", null, null, Server, Credential);
            } catch (Exception) {
                // do nothing.
            }
            if (entry != null)
            {
                WriteObject(true);
            }
        }
    }
}

