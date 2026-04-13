using System;
using System.Collections;
using System.Collections.Generic;
using System.Management.Automation;

namespace Pxtl.ADServices.Cmdlets
{
    [Cmdlet(VerbsLifecycle.Enable, "ADAccount")]
    [OutputType(typeof(PSObject))]
    public class EnableADAccountCommand : PSCmdlet
    {
        [Parameter(Mandatory = true, ValueFromPipeline = true, Position = 0)]
        public string Identity { get; set; }

        [Parameter]
        public string Server { get; set; }

        [Parameter]
        public PSCredential Credential { get; set; }

        [Parameter]
        public SwitchParameter PassThru { get; set; }

        protected override void ProcessRecord()
        {
            var existing = ADEntryRepository.TryGetADObject(ADEntryType.User, null, Identity, null, Server, Credential);
            var currentValue = existing.GetAttributeIntValue("userAccountControl");
            var result = ADEntryRepository.SetADObject(ADEntryType.User, Identity, null, null, new Hashtable { ["userAccountControl"] = currentValue & ~2 }, Server, Credential, PassThru.ToBool());
            if (PassThru.ToBool() && result != null)
            {
                WriteObject(result);
            }
        }
    }

    [Cmdlet(VerbsLifecycle.Disable, "ADAccount")]
    [OutputType(typeof(PSObject))]
    public class DisableADAccountCommand : PSCmdlet
    {
        [Parameter(Mandatory = true, ValueFromPipeline = true, Position = 0)]
        public string Identity { get; set; }

        [Parameter]
        public string Server { get; set; }

        [Parameter]
        public PSCredential Credential { get; set; }

        [Parameter]
        public SwitchParameter PassThru { get; set; }

        protected override void ProcessRecord()
        {
            var existing = ADEntryRepository.TryGetADObject(ADEntryType.User, null, Identity, null, Server, Credential);
            var currentValue = existing.GetAttributeIntValue("userAccountControl");
            var result = ADEntryRepository.SetADObject(ADEntryType.User, Identity, null, null, new Hashtable { ["userAccountControl"] = currentValue | 2 }, Server, Credential, PassThru.ToBool());
            if (PassThru.ToBool() && result != null)
            {
                WriteObject(result);
            }
        }
    }
}