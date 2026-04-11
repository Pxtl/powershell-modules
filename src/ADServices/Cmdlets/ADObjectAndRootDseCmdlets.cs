using System;
using System.Collections;
using System.Collections.Generic;
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
            var rootDse = ADCommandUtils.GetADObject(null, "(objectClass=*)", null, null, Server, Credential, ADPropertyConverters.ConvertRootDse);
            if (rootDse != null)
            {
                WriteObject(rootDse);
            }
        }
    }

    [Cmdlet(VerbsCommon.Get, "ADObject", DefaultParameterSetName = "Filter")]
    [OutputType(typeof(PSObject))]
    public class GetADObjectCommand : PSCmdlet
    {
        [Parameter(Position = 0)]
        public string Type { get; set; }

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
            var converter = GetConverter(Type);
            var entries = ADCommandUtils.GetADObjects(Type, LDAPFilter, Identity, SearchBase, Server, Credential, converter);
            if (!string.IsNullOrEmpty(Identity))
            {
                var list = new List<PSObject>(entries);
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

        private static Func<Dictionary<string, object>, Dictionary<string, object>> GetConverter(string type)
        {
            return type?.ToLowerInvariant() switch
            {
                "user" => ADPropertyConverters.ConvertAdUser,
                "group" => ADPropertyConverters.ConvertAdGroup,
                "organizationalunit" => ADPropertyConverters.ConvertAdOrganizationalUnit,
                _ => ADPropertyConverters.ConvertAdObject,
            };
        }
    }

    [Cmdlet(VerbsCommon.New, "ADObject")]
    [OutputType(typeof(PSObject))]
    public class NewADObjectCommand : PSCmdlet
    {
        [Parameter(Mandatory = true, Position = 0)]
        public string Type { get; set; }

        [Parameter(Position = 1)]
        [ValidateSet("CN", "OU")]
        public string DistinguishedComponentType { get; set; } = "CN";

        [Parameter(Mandatory = true, Position = 2, ValueFromPipeline = true)]
        public string Name { get; set; }

        [Parameter]
        public Hashtable OtherAttributes { get; set; }

        [Parameter]
        public string Path { get; set; }

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
            var passThru = PassThru.IsPresent;
            var entry = ADCommandUtils.NewADObject(Type, DistinguishedComponentType, Name, OtherAttributes, Path, DefaultRelativePath, Server, Credential, DoSamAccountName.IsPresent, passThru, GetConverter(Type));
            if (passThru && entry != null)
            {
                WriteObject(entry);
            }
        }

        private static Func<Dictionary<string, object>, Dictionary<string, object>> GetConverter(string type)
        {
            return type?.ToLowerInvariant() switch
            {
                "user" => ADPropertyConverters.ConvertAdUser,
                "group" => ADPropertyConverters.ConvertAdGroup,
                "organizationalunit" => ADPropertyConverters.ConvertAdOrganizationalUnit,
                _ => ADPropertyConverters.ConvertAdObject,
            };
        }
    }

    [Cmdlet(VerbsCommon.Set, "ADObject")]
    [OutputType(typeof(PSObject))]
    public class SetADObjectCommand : PSCmdlet
    {
        [Parameter(Position = 0)]
        public string Type { get; set; }

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
            var result = ADCommandUtils.SetADObject(Type, Identity, Add, Remove, Replace, Server, Credential, PassThru.IsPresent, GetConverter(Type));
            if (PassThru.IsPresent && result != null)
            {
                WriteObject(result);
            }
        }

        private static Func<Dictionary<string, object>, Dictionary<string, object>> GetConverter(string type)
        {
            return type?.ToLowerInvariant() switch
            {
                "user" => ADPropertyConverters.ConvertAdUser,
                "group" => ADPropertyConverters.ConvertAdGroup,
                "organizationalunit" => ADPropertyConverters.ConvertAdOrganizationalUnit,
                _ => ADPropertyConverters.ConvertAdObject,
            };
        }
    }

    [Cmdlet(VerbsCommon.Remove, "ADObject")]
    public class RemoveADObjectCommand : PSCmdlet
    {
        [Parameter(Position = 0)]
        public string Type { get; set; }

        [Parameter(Mandatory = true, Position = 1, ValueFromPipeline = true)]
        public string Identity { get; set; }

        [Parameter]
        public string Server { get; set; }

        [Parameter]
        public PSCredential Credential { get; set; }

        protected override void ProcessRecord()
        {
            ADCommandUtils.RemoveADObject(Type, Identity, Server, Credential, GetConverter(Type));
        }

        private static Func<Dictionary<string, object>, Dictionary<string, object>> GetConverter(string type)
        {
            return type?.ToLowerInvariant() switch
            {
                "user" => ADPropertyConverters.ConvertAdUser,
                "group" => ADPropertyConverters.ConvertAdGroup,
                "organizationalunit" => ADPropertyConverters.ConvertAdOrganizationalUnit,
                _ => ADPropertyConverters.ConvertAdObject,
            };
        }
    }

    [Cmdlet(VerbsDiagnostic.Test, "ADObject")]
    [OutputType(typeof(bool))]
    public class TestADObjectCommand : PSCmdlet
    {
        [Parameter(Position = 0)]
        public string Type { get; set; }

        [Parameter(Mandatory = true, Position = 1, ValueFromPipeline = true)]
        public string Identity { get; set; }

        [Parameter]
        public string Server { get; set; }

        [Parameter]
        public PSCredential Credential { get; set; }

        protected override void ProcessRecord()
        {
            var result = ADCommandUtils.TestADObject(Type, Identity, Server, Credential, GetConverter(Type));
            WriteObject(result);
        }

        private static Func<Dictionary<string, object>, Dictionary<string, object>> GetConverter(string type)
        {
            return type?.ToLowerInvariant() switch
            {
                "user" => ADPropertyConverters.ConvertAdUser,
                "group" => ADPropertyConverters.ConvertAdGroup,
                "organizationalunit" => ADPropertyConverters.ConvertAdOrganizationalUnit,
                _ => ADPropertyConverters.ConvertAdObject,
            };
        }
    }
}
