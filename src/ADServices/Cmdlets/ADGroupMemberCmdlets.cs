using System;
using System.Collections;
using System.Collections.Generic;
using System.Management.Automation;

namespace Pxtl.ADServices.Cmdlets
{
    [Cmdlet(VerbsCommon.Add, "ADGroupMember")]
    public class AddADGroupMemberCommand : PSCmdlet
    {
        [Parameter(Mandatory = true, ValueFromPipelineByPropertyName = true)]
        public string Identity { get; set; }

        [Parameter(ValueFromPipelineByPropertyName = true)]
        public string[] Members { get; set; }

        [Parameter]
        public string Server { get; set; }

        [Parameter]
        public PSCredential Credential { get; set; }

        [Parameter]
        public SwitchParameter PassThru { get; set; }

        protected override void ProcessRecord()
        {
            var group = ADCommandUtils.GetADObject("group", null, Identity, null, Server, Credential, ADPropertyConverters.ConvertAdGroup);
            if (group == null)
            {
                ThrowTerminatingError(new ErrorRecord(new InvalidOperationException($"Group '{Identity}' not found."), "GroupNotFound", ErrorCategory.ObjectNotFound, Identity));
                return;
            }
            if (Members == null || Members.Length == 0)
            {
                WriteWarning($"Can't update group '{Identity}' membership, nothing to do.");
                return;
            }
            foreach (var memberIdentity in Members)
            {
                var memberObject = ADCommandUtils.GetADObject(null, null, memberIdentity, null, Server, Credential, ADPropertyConverters.ConvertAdObject);
                if (memberObject == null)
                {
                    WriteError(new ErrorRecord(new InvalidOperationException($"Object '{memberIdentity}' not found."), "MemberNotFound", ErrorCategory.ObjectNotFound, memberIdentity));
                    continue;
                }
                var memberDn = ADCommandUtils.GetDistinguishedName(memberObject);
                if (string.IsNullOrWhiteSpace(memberDn))
                {
                    WriteError(new ErrorRecord(new InvalidOperationException($"Unable to resolve DN for object '{memberIdentity}'."), "MemberDNMissing", ErrorCategory.InvalidData, memberIdentity));
                    continue;
                }
                ADCommandUtils.SetADObject("group", Identity, new Hashtable { ["member"] = memberDn }, null, null, Server, Credential, false, ADPropertyConverters.ConvertAdGroup);
            }
            if (PassThru.IsPresent)
            {
                var result = ADCommandUtils.GetADObject("group", null, Identity, null, Server, Credential, ADPropertyConverters.ConvertAdGroup);
                if (result != null)
                {
                    WriteObject(result);
                }
            }
        }
    }

    [Cmdlet(VerbsCommon.Remove, "ADGroupMember")]
    public class RemoveADGroupMemberCommand : PSCmdlet
    {
        [Parameter(Mandatory = true, ValueFromPipelineByPropertyName = true)]
        public string Identity { get; set; }

        [Parameter(ValueFromPipelineByPropertyName = true)]
        public string[] Members { get; set; }

        [Parameter]
        public string Server { get; set; }

        [Parameter]
        public PSCredential Credential { get; set; }

        [Parameter]
        public SwitchParameter PassThru { get; set; }

        protected override void ProcessRecord()
        {
            var group = ADCommandUtils.GetADObject("group", null, Identity, null, Server, Credential, ADPropertyConverters.ConvertAdGroup);
            if (group == null)
            {
                ThrowTerminatingError(new ErrorRecord(new InvalidOperationException($"Group '{Identity}' not found."), "GroupNotFound", ErrorCategory.ObjectNotFound, Identity));
                return;
            }
            if (Members == null || Members.Length == 0)
            {
                WriteWarning($"Can't update group '{Identity}' membership, nothing to do.");
                return;
            }
            foreach (var memberIdentity in Members)
            {
                var memberObject = ADCommandUtils.GetADObject(null, null, memberIdentity, null, Server, Credential, ADPropertyConverters.ConvertAdObject);
                if (memberObject == null)
                {
                    WriteError(new ErrorRecord(new InvalidOperationException($"Object '{memberIdentity}' not found."), "MemberNotFound", ErrorCategory.ObjectNotFound, memberIdentity));
                    continue;
                }
                var memberDn = ADCommandUtils.GetDistinguishedName(memberObject);
                if (string.IsNullOrWhiteSpace(memberDn))
                {
                    WriteError(new ErrorRecord(new InvalidOperationException($"Unable to resolve DN for object '{memberIdentity}'."), "MemberDNMissing", ErrorCategory.InvalidData, memberIdentity));
                    continue;
                }
                ADCommandUtils.SetADObject("group", Identity, null, new Hashtable { ["member"] = memberDn }, null, Server, Credential, false, ADPropertyConverters.ConvertAdGroup);
            }
            if (PassThru.IsPresent)
            {
                var result = ADCommandUtils.GetADObject("group", null, Identity, null, Server, Credential, ADPropertyConverters.ConvertAdGroup);
                if (result != null)
                {
                    WriteObject(result);
                }
            }
        }
    }

    [Cmdlet(VerbsCommon.Get, "ADGroupMember")]
    [OutputType(typeof(PSObject))]
    public class GetADGroupMemberCommand : PSCmdlet
    {
        [Parameter(Mandatory = true, ValueFromPipeline = true)]
        public string Identity { get; set; }

        [Parameter]
        public string Server { get; set; }

        [Parameter]
        public PSCredential Credential { get; set; }

        [Parameter]
        public SwitchParameter Recursive { get; set; }

        protected override void ProcessRecord()
        {
            var group = ADCommandUtils.GetADObject("group", null, Identity, null, Server, Credential, ADPropertyConverters.ConvertAdGroup);
            if (group == null)
            {
                return;
            }
            var groupDn = ADCommandUtils.GetDistinguishedName(group);
            if (string.IsNullOrWhiteSpace(groupDn))
            {
                return;
            }
            var members = GetGroupMemberObjects(groupDn, new HashSet<string>(StringComparer.OrdinalIgnoreCase));
            foreach (var member in members)
            {
                WriteObject(member);
            }
        }

        private IEnumerable<PSObject> GetGroupMemberObjects(string groupDn, HashSet<string> visited)
        {
            if (!visited.Add(groupDn))
            {
                yield break;
            }

            var members = ADCommandUtils.GetADObjects(null, $"(memberOf={groupDn})", null, null, Server, Credential, ADPropertyConverters.ConvertAdObject);
            foreach (var member in members)
            {
                yield return member;
                if (Recursive.IsPresent)
                {
                    var memberDn = ADCommandUtils.GetDistinguishedName(member);
                    if (!string.IsNullOrWhiteSpace(memberDn))
                    {
                        foreach (var nestedMember in GetGroupMemberObjects(memberDn, visited))
                        {
                            yield return nestedMember;
                        }
                    }
                }
            }
        }
    }
}
