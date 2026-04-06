Set-StrictMode -Version Latest
$ErrorActionPreference = [Management.Automation.ActionPreference]::Stop


function Get-ADOrganizationalUnit {
    <#
    .SYNOPSIS
        Retrieves an Active Directory OrganizationalUnit.
    .DESCRIPTION
        Retrieves an Active Directory OrganizationalUnit using
        System.DirectoryServices.
    .OUTPUTS
        [PSCustomObject], none if not found.
    #>
    [OutputType([PSCustomObject])]
    [CmdletBinding(DefaultParameterSetName='Filter')]
    param (
        # The filter to search for OrganizationalUnits. Uses normal AD Search
        # syntax, *not* PS ActiveDirectory search.
        [Parameter(Mandatory, ValueFromPipeline, ParameterSetName='Filter')]
        [string] $LDAPFilter,

        # The identity of the OrganizationalUnit to retrieve. Can be SID, LDAP
        # path, or distinguished name.
        [Parameter(Mandatory, ValueFromPipeline, ParameterSetName='Identity')]
        [string] $Identity,

        # The domain controller to query.
        [Parameter()]
        [string] $Server = $null,

        # Credentials for the domain controller.
        [Parameter()]
        [PSCredential] $Credential = $null
    )
    process {
        $entries = Get-ADObject 'organizationalUnit' @PSBoundParameters
        foreach ($entry in $entries) {
            Update-ADOrganizationalUnitEntry $entry
            
            # output
            $entry
        }
    }
}


function New-ADOrganizationalUnit {
    <#
    .SYNOPSIS
        Creates a new Active Directory OrganizationalUnit.
    .DESCRIPTION
        Creates a new Active Directory OrganizationalUnit using System.DirectoryServices.Protocols
    .OUTPUTS
        [PSCustomObject]
    #>
    [Diagnostics.CodeAnalysis.SuppressMessage(
        'PSShouldProcess','',Scope='Function',Justification='-WhatIf passed through to ADObject func'
    )]
    [OutputType([PSCustomObject])]
    [CmdletBinding(SupportsShouldProcess)]
    param (
        # The name of the new OrganizationalUnit.
        [Parameter(Mandatory, ValueFromPipeline)]
        [string] $Name,

        # DistinguishedName path of the parent container.  If not provided will parent directly to the default Domain.
        [Parameter()]
        [string] $Path,

        # A hashtable of LDAP attributes to set on the object.
        [Parameter()]
        [hashtable] $OtherAttributes,

        # The domain controller to query.
        [string] $Server,

        # Credentials for the domain controller.
        [PSCredential] $Credential,

        [switch] $PassThru
    )
    begin {

    }
    process {
        $entry = New-ADObject 'organizationalUnit' 'OU' $Name `
            -Path $Path `
            -DefaultRelativePath $null `
            -Server $Server `
            -Credential $Credential `
            -WhatIf:$WhatIfPreference `
            -Verbose:$VerbosePreference

        if ($OtherAttributes) {
            Set-ADOrganizationalUnitEntry $entry -OtherAttributes $OtherAttributes -WhatIf:$WhatIfPreference
            $entry.CommitChanges()
        }

        if ($PassThru) {
            Update-ADOrganizationalUnitEntry $entry

            # output
            $entry
        }
    }
}


function Set-ADOrganizationalUnit {
    <#
    .SYNOPSIS
        Modifies an Active Directory OrganizationalUnit.
    .DESCRIPTION
        Modifies an Active Directory OrganizationalUnit using System.DirectoryServices.Protocols
    .OUTPUTS
        [PSCustomObject]
    #>
    [Diagnostics.CodeAnalysis.SuppressMessage(
        'PSShouldProcess','',Scope='Function',Justification='-WhatIf passed through to ADObject func'
    )]
    [OutputType([PSCustomObject])]
    [CmdletBinding(SupportsShouldProcess)]
    param (
        [Parameter(Mandatory, ValueFromPipeline)]
        [string] $Identity,

        # A hashtable of LDAP attributes to set on the OrganizationalUnit.
        [Parameter()]
        [hashtable] $OtherAttributes,

        # The domain controller to query.
        [Parameter()]
        [string] $Server,

        # Credentials for the domain controller.
        [Parameter()]
        [PSCredential] $Credential,

        [switch] $PassThru
    )
    process {
        $entry = Get-ADObject 'organizationalUnit' -Identity $Identity -Server $Server -Credential $Credential
        if ($OtherAttributes) {
            Set-ADOrganizationalUnitEntry $entry -OtherAttributes $OtherAttributes -WhatIf:$WhatIfPreference
            $entry.CommitChanges()
        } else {
            Write-Warning "Can't update OrganizationalUnit '$Identity', nothing to do."
        }

        if ($PassThru) {
            Update-ADOrganizationalUnitEntry $entry

            # output
            $entry
        }
    }
}


function Remove-ADOrganizationalUnit {
    <#
    .SYNOPSIS
        Removes an Active Directory OrganizationalUnit.
    .DESCRIPTION
        Removes an Active Directory OrganizationalUnit using System.DirectoryServices.Protocols
    .OUTPUTS
        None
    #>
    [Diagnostics.CodeAnalysis.SuppressMessage(
        'PSShouldProcess','',Scope='Function',Justification='-WhatIf passed through to ADObject func'
    )]
    [CmdletBinding(SupportsShouldProcess)]
    param (
        [Parameter(Mandatory, ValueFromPipeline)]
        [string] $Identity,

        # The domain controller to query.
        [Parameter()]
        [string] $Server,

        # Credentials for the domain controller.
        [Parameter()]
        [PSCredential] $Credential = $null
    )
    process {
        Remove-ADObject 'organizationalUnit' @PSBoundParameters
    }
}


function Test-ADOrganizationalUnit {
    <#
    .SYNOPSIS
        Tests the existence of an Active Directory OrganizationalUnit.
    .DESCRIPTION
        Tests the existence of an Active Directory OrganizationalUnit using System.DirectoryServices.Protocols
    .OUTPUTS
        [bool]
    #>
    [OutputType([bool])]
    [CmdletBinding()]
    param (
        [Parameter(Mandatory, ValueFromPipeline)]
        [string] $Identity,

        # The domain controller to query.
        [Parameter()]
        [string] $Server,

        # Credentials for the domain controller.
        [Parameter()]
        [PSCredential] $Credential = $null
    )
    process {
        Test-ADObject 'organizationalUnit' @PSBoundParameters
    }
}


#private
function Update-ADOrganizationalUnitEntry {
    param (
        [Parameter(Mandatory, ValueFromPipeline)]
        [PSCustomObject] $Entry
    )
    process {
        # no-op.
    }
}


#private
function Set-ADOrganizationalUnitEntry {
    param (
        [Parameter(Mandatory, ValueFromPipeline)]
        [PSCustomObject] $Entry
    )
    process {
        # no-op.
    }
}