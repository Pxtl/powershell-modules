using System;
using System.Collections;
using System.Collections.Generic;
using System.Management.Automation;

namespace Pxtl.ADServices.Cmdlets
{
    [Cmdlet(VerbsData.Convert, "ADIdentityToFilter")]
    [OutputType(typeof(PSObject))]
    public class ConvertADIdentityToFilter : PSCmdlet
    {
        [Parameter(Mandatory = true, ValueFromPipeline = true, Position = 0)]
        public string Identity { get; set; }

        protected override void ProcessRecord()
        {
            WriteObject(LdapHelper.ConvertIdentityToFilter(Identity));
        }
    }
}