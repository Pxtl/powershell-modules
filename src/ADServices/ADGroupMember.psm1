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
    begin {
        $commonParams = @{
            WhatIf = $WhatIfPreference
            Verbose = $VerbosePreference
        }
    }
    process {
        $group = Get-ADGroup -Server $Server -Credential $Credential -Identity $Identity
        if (-not $group) {
            Write-Error "Group '$Identity' not found."
            return
        }
        foreach ($MemberIdentity in $Members) {
            $newMember = Get-ADObject -Server $Server -Credential $Credential -Identity $MemberIdentity
            $newMemberType = $newMember.ObjectClass
            
            # TODO: This doesn't need to be one request per-member. Should only
            # use that mode as fallback if the Members' identities aren't all
            # DistinguishedNames.
            if ($group -and $newMember) {
                [string] $memberKey = $newMember.DistinguishedName
                if ($PSCmdlet.ShouldProcess("adding $newMemberType '$memberKey' to group '$Identity'")) {
                    $additions = @{ member = $memberKey }
                    Set-ADObject 'Group' -Identity $Identity -Add $additions -Server $Server -Credential $Credential @commonParams
                    Set-ADObjectEntry $group -Add $additions @commonParams
                }
            } else {
                Write-Error "Object '$MemberIdentity' not found."
            }
        }
        if (-not $Members) {
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
    begin {
        $commonParams = @{
            WhatIf = $WhatIfPreference
            Verbose = $VerbosePreference
        }
    }
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
                [string] $memberKey = $newMember.DistinguishedName # does not work if $memberKey is typed [object]
                $targetSummary = "removing $newMemberType '$memberKey' from group '$Identity'"
                if ($PSCmdlet.ShouldProcess($targetSummary)) {
                    $deletions = @{ member = $memberKey }
                    Set-ADObject 'Group' -Identity $Identity -Remove $deletions -Server $Server -Credential $Credential @commonParams
                    Set-ADObjectEntry $group -Remove $deletions @commonParams
                }
                Write-Verbose "$($MyInvocation.MyCommand): $targetSummary"
            } else {
                Write-Error "Object '$MemberIdentity' not found."
            }
        }
        if (-not $Members) {
            Write-Warning "Can't update group '$Identity' membership, nothing to do."
        }

        if ($PassThru) {
            # Output
            $group
        }
    }
}


function Get-ADGroupMember {
    <#
    .SYNOPSIS
        Get Member ADObjects of a group.
    .OUTPUTS
        [DirectoryServices.DirectoryEntry] of the ADObjects within the group. If the group does not exist, returns Nothing.
    #>
    [OutputType([DirectoryServices.DirectoryEntry])]
    [CmdletBinding()]
    param(
        # Identity of the group.
        [Parameter(Mandatory, ValueFromPipeline)]
        [string] $Identity,

        # The domain controller to query.
        [Parameter()]
        [string] $Server = $null,

        # Credentials for the domain controller.
        [Parameter()]
        [PSCredential] $Credential = $null,

        [switch] $Recursive
    )
    process {
        $group = Get-ADGroup -Identity $Identity -Server $Server -Credential $Credential -Verbose:$VerbosePreference
        if (-not $group) {
            return
        }
        $groupDN = $group.distinguishedName
        $members = Get-ADObject -LDAPFilter "(memberOf=$groupDN)" -Server $Server -Credential $Credential -Verbose:$VerbosePreference
        
        # output
        $members
        if ($Recursive) {
            $members | Foreach-Object {
                Get-ADGroupMember -Identity $_.distinguishedName -Server $Server -Credential $Credential -Recursive
            }
        }
    }
}
