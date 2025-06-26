Set-StrictMode -Version Latest
$ErrorActionPreference = [Management.Automation.ActionPreference]::Stop


function Add-ADGroupMember {
    <#
    .SYNOPSIS
        Add one or more members to a Group.

    .OUTPUTS
        Nothing, unless PassThru is set in which case it returns the Group as a
        [DirectoryServices.DirectoryEntry].
    #>
    [OutputType([DirectoryServices.DirectoryEntry])]
    [CmdletBinding(SupportsShouldProcess)]
    param (
        # Identity of the group to add members to.
        [Parameter(Mandatory, ValueFromPipelineByPropertyName)]
        [string] $Identity,

        # Identity entries for new members of the group.
        [Parameter(ValueFromPipelineByPropertyName)]
        [string[]] $Members,

        # The domain controller to query.
        [Parameter()]
        [string] $Server = $null,

        # Credentials for the domain controller.
        [Parameter()]
        [PSCredential] $Credential = $null,

        [Switch]
        $PassThru
    )
    process {
        $group = Get-ADGroup -Server $Server -Credential $Credential -Identity $Identity
        if (-not $group) {
            Write-Error "Group '$Identity' not found."
            return
        }
        foreach ($MemberIdentity in $Members) {
            $newMember = Get-ADObject -Server $Server -Credential $Credential -Identity $MemberIdentity
            $newMemberType = $newMember.objectClass -split ' ' | Select-Object -Last 1

            if ($group -and $newMember) {
                [string] $memberKey = $newMember.distinguishedName.Value # does not work if $memberKey is typed [object]
                $targetSummary = "adding $newMemberType '$memberKey' to group '$Identity'"
                if ($PSCmdlet.ShouldProcess($targetSummary)) {
                    $group.Properties["member"].Add($memberKey)
                }
                Write-Verbose "$($MyInvocation.MyCommand): $targetSummary"
            } else {
                Write-Error "Object '$MemberIdentity' not found."
            }
        }
        if ($Members) {
            if ($PSCmdlet.ShouldProcess($Identity, 'CommitChanges')) {
                $group.CommitChanges()
            }
        } else {
            Write-Warning "Can't update group '$Identity' membership, nothing to do."
        }

        if ($PassThru) {
            # Output
            $group
        }
    }
}


function Remove-ADGroupMember {
    <#
    .SYNOPSIS
        Remove one or more members from a Group.

    .OUTPUTS
        Nothing, unless PassThru is set in which case it returns the Group as a
        [DirectoryServices.DirectoryEntry].
    #>
    [CmdletBinding(SupportsShouldProcess)]
    param (
        # Identity of the group to add members to.
        [Parameter(Mandatory, ValueFromPipelineByPropertyName)]
        [string] $Identity,

        # Identity entries for new members of the group.
        [Parameter(ValueFromPipelineByPropertyName)]
        [string[]] $Members,

        # The domain controller to query.
        [Parameter()]
        [string] $Server = $null,

        # Credentials for the domain controller.
        [Parameter()]
        [PSCredential] $Credential = $null,

        [Switch]
        $PassThru
    )
    process {
        $group = Get-ADGroup -Server $Server -Credential $Credential -Identity $Identity
        if (-not $group) {
            Write-Error "Group '$Identity' not found."
            return
        }
        foreach ($MemberIdentity in $Members) {
            $newMember = $newMember = Get-ADObject -Server $Server -Credential $Credential -Identity $MemberIdentity
            $newMemberType = $newMember.objectClass -split ' ' | Select-Object -Last 1

            if ($group -and $newMember) {
                [string] $memberKey = $newMember.distinguishedName.Value # does not work if $memberKey is typed [object]
                $targetSummary = "removing $newMemberType '$memberKey' from group '$Identity'"
                if ($PSCmdlet.ShouldProcess($targetSummary)) {
                    $group.Properties["member"].Remove($memberKey)
                }
                Write-Verbose "$($MyInvocation.MyCommand): $targetSummary"
            } else {
                Write-Error "Object '$MemberIdentity' not found."
            }
        }
        if ($Members) {
            if ($PSCmdlet.ShouldProcess($Identity, 'CommitChanges')) {
                $group.CommitChanges()
            }
        } else {
            Write-Warning "Can't update group '$Identity' membership, nothing to do."
        }
        if ($PassThru) {
            # Output
            $group
        }
    }
}
