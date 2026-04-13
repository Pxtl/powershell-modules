using System;
using System.Collections;
using System.Collections.Generic;
using System.Management.Automation;

namespace Pxtl.ADServices.Cmdlets
{
    [Cmdlet(VerbsCommon.Add, "ADGroupMember")]
    public class AddADGroupMemberCommand : PSCmdlet
    {
        [Parameter(Mandatory = true, ValueFromPipelineByPropertyName = true, Position = 0)]
        public string Identity { get; set; }

        [Parameter(ValueFromPipelineByPropertyName = true, Position = 1)]
        public string[] Members { get; set; }

        [Parameter]
        public string Server { get; set; }

        [Parameter]
        public PSCredential Credential { get; set; }

        [Parameter]
        public SwitchParameter PassThru { get; set; }

        protected override void ProcessRecord()
        {
            var group = ADEntryRepository.TryGetADObject(ADEntryType.Group, null, Identity, null, Server, Credential);
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
                var memberObject = ADEntryRepository.TryGetADObject(null, null, memberIdentity, null, Server, Credential);
                if (memberObject == null)
                {
                    WriteError(new ErrorRecord(new InvalidOperationException($"Object '{memberIdentity}' not found."), "MemberNotFound", ErrorCategory.ObjectNotFound, memberIdentity));
                    continue;
                }
                var memberDn = memberObject?.MaybeGetDistinguishedName();
                if (string.IsNullOrWhiteSpace(memberDn))
                {
                    WriteError(new ErrorRecord(new InvalidOperationException($"Unable to resolve DN for object '{memberIdentity}'."), "MemberDNMissing", ErrorCategory.InvalidData, memberIdentity));
                    continue;
                }
                ADEntryRepository.SetADObject(ADEntryType.Group, Identity, new Hashtable { ["member"] = memberDn }, null, null, Server, Credential, false);
            }
            if (PassThru.ToBool())
            {
                var result = ADEntryRepository.TryGetADObject(ADEntryType.Group, null, Identity, null, Server, Credential);
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
        [Parameter(Mandatory = true, ValueFromPipelineByPropertyName = true, Position = 0)]
        public string Identity { get; set; }

        [Parameter(ValueFromPipelineByPropertyName = true, Position = 1)]
        public string[] Members { get; set; }

        [Parameter]
        public string Server { get; set; }

        [Parameter]
        public PSCredential Credential { get; set; }

        [Parameter]
        public SwitchParameter PassThru { get; set; }

        protected override void ProcessRecord()
        {
            var group = ADEntryRepository.TryGetADObject(ADEntryType.Group, null, Identity, null, Server, Credential);
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
                var memberObject = ADEntryRepository.TryGetADObject(null, null, memberIdentity, null, Server, Credential);
                if (memberObject == null)
                {
                    WriteError(new ErrorRecord(new InvalidOperationException($"Object '{memberIdentity}' not found."), "MemberNotFound", ErrorCategory.ObjectNotFound, memberIdentity));
                    continue;
                }
                var memberDn = memberObject?.MaybeGetDistinguishedName();
                if (string.IsNullOrWhiteSpace(memberDn))
                {
                    WriteError(new ErrorRecord(new InvalidOperationException($"Unable to resolve DN for object '{memberIdentity}'."), "MemberDNMissing", ErrorCategory.InvalidData, memberIdentity));
                    continue;
                }
                ADEntryRepository.SetADObject(ADEntryType.Group, Identity, null, new Hashtable { ["member"] = memberDn }, null, Server, Credential, false);
            }
            if (PassThru.ToBool())
            {
                var result = ADEntryRepository.TryGetADObject(ADEntryType.Group, null, Identity, null, Server, Credential);
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
        [Parameter(Mandatory = true, ValueFromPipeline = true, Position = 0)]
        public string Identity { get; set; }

        [Parameter]
        public string Server { get; set; }

        [Parameter]
        public PSCredential Credential { get; set; }

        [Parameter]
        public SwitchParameter Recursive { get; set; }

        protected override void ProcessRecord()
        {
            var group = ADEntryRepository.TryGetADObject(ADEntryType.Group, null, Identity, null, Server, Credential);
            if (group == null)
            {
                return;
            }
            var groupDn = group.MaybeGetDistinguishedName();
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

        private IEnumerable<ADObjectEntry> GetGroupMemberObjects(string groupDn, HashSet<string> visited)
        {
            if (!visited.Add(groupDn))
            {
                yield break;
            }

            var members = ADEntryRepository.TryGetADObjects<ADObjectEntry>($"(memberOf={groupDn})", null, null, Server, Credential);
            foreach (var member in members)
            {
                yield return member;
                if (Recursive.ToBool())
                {
                    var memberDn = member?.MaybeGetDistinguishedName();
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


