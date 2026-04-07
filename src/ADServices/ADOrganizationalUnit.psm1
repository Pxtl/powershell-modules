Set-StrictMode -Version Latest
$ErrorActionPreference = [Management.Automation.ActionPreference]::Stop
. $PSScriptRoot\Shared\Variables.ps1
Add-Type -AssemblyName 'System.DirectoryServices.Protocols'

function Get-ADOrganizationalUnit {
    <#
    .SYNOPSIS
        Retrieves an Active Directory OrganizationalUnit.
    .DESCRIPTION
        Retrieves an Active Directory OrganizationalUnit using
        System.DirectoryServices.Protocols.
    .OUTPUTS
        [PSCustomObject], $null if not found.
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
        Get-ADObject 'organizationalUnit' @PSBoundParameters -ObjectPropertyConverter ${function:Convert-ADOrganizationalUnitPropertyTable}
    }
}


function New-ADOrganizationalUnit {
    <#
    .SYNOPSIS
        Creates a new Active Directory OrganizationalUnit.
    .DESCRIPTION
        Creates a new Active Directory OrganizationalUnit using System.DirectoryServices.Protocols
    .OUTPUTS
        [PSCustomObject] if PassThru is enabled.
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
        $commonParams = @{
            WhatIf = $WhatIfPreference
            Verbose = $VerbosePreference
        }
    }
    process {
        $entry = New-ADObject 'organizationalUnit' 'OU' $Name `
            -Path $Path `
            -DefaultRelativePath $null `
            -ObjectPropertyConverter ${function:Convert-ADOrganizationalUnitPropertyTable} `
            -Server $Server `
            -Credential $Credential `
            -PassThru `
            @commonParams

        if ($OtherAttributes) {
            $entry = Set-ADOrganizationalUnit -Identity $entry.DistinguishedName -Replace $OtherAttributes -Server $Server -Credential $Credential @commonParams
        }

        if ($PassThru) {
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

        # A hashtable of LDAP properties to add on the entry.
        [Parameter()]
        [hashtable] $Add,

        # A hashtable of LDAP properties to remove from the entry.
        [Parameter()]
        [hashtable] $Remove,

        # A hashtable of LDAP properties to replace on the entry.
        [Parameter()]
        [hashtable] $Replace,

        # The domain controller to query.
        [Parameter()]
        [string] $Server,

        # Credentials for the domain controller.
        [Parameter()]
        [PSCredential] $Credential,

        [switch] $PassThru
    )
    begin {
        $commonParams = @{
            WhatIf = $WhatIfPreference
            Verbose = $VerbosePreference
        }
    }
    process {
        $entry = Get-ADOrganizationalUnit -Identity $Identity -Server $Server -Credential $Credential
        if ($Add -or $Remove -or $Replace) {
            Set-ADObject 'organizationalUnit' -Identity $Identity -Add $Add -Remove $Remove -Replace $Replace -Server $Server -Credential $Credential @commonParams
            Set-ADObjectEntry $entry -Replace $OtherAttributes @commonParams
            Update-ADOrganizationalUnitEntry $entry
        } else {
            Write-Warning "Can't update OrganizationalUnit '$Identity', nothing to do."
        }

        if ($PassThru) {
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
    [Diagnostics.CodeAnalysis.SuppressMessage(
        'PSShouldProcess','',Scope='Function',Justification='-WhatIf passed through to LDAPEntry func'
    )]
    [CmdletBinding(SupportsShouldProcess)]
    param (
        [Parameter(Mandatory, ValueFromPipeline)]
        [PSCustomObject] $Entry
    )
    begin {
        $commonParams = @{
            WhatIf = $WhatIfPreference
            Verbose = $VerbosePreference
        }
    }
    process {
        Update-ADObjectEntry $Entry -ObjectPropertyConverter ${function:Convert-ADOrganizationalUnitPropertyTable} @commonParams
    }
}


function Convert-ADOrganizationalUnitPropertyTable {
    <#
    .SYNOPSIS
        Takes a table of raw LDAP properties and converts them into a table of
        object properties for an ADOrganizationalUnit.
    .NOTES
        Adapted from https://learn.microsoft.com/en-us/archive/technet-wiki/12089.active-directory-get-adorganizationalunit-default-and-extended-properties
    #>
    [CmdletBinding()]
    param (
        [Parameter(Mandatory, ValueFromPipeline)]
        [hashtable] $LdapAttributeTable,

        [Parameter()]
        [hashtable] $ObjectPropertyTable
    )
    process {
        if (-not $ObjectPropertyTable) {
            $ObjectPropertyTable = @{}
        }

        Convert-ADObjectPropertyTable -LdapAttributeTable $LdapAttributeTable -ObjectPropertyTable $ObjectPropertyTable | Out-Null

        $ObjectPropertyTable['City'] = $LdapAttributeTable['l']
        $ObjectPropertyTable['Country'] = $LdapAttributeTable['c']
        $ObjectPropertyTable['LinkedGroupPolicyObjects'] = $LdapAttributeTable['gPLink']
        $ObjectPropertyTable['ManagedBy'] = $LdapAttributeTable['managedBy']
        # Name is already there from "Name" by default but is overridden by 'ou' in this case.
        $ObjectPropertyTable['Name'] = $LdapAttributeTable['ou']
        $ObjectPropertyTable['PostalCode'] = $LdapAttributeTable['postalCode']
        $ObjectPropertyTable['State'] = $LdapAttributeTable['st']
        $ObjectPropertyTable['StreetAddress'] = $LdapAttributeTable['streetAddress']

        # output
        $ObjectPropertyTable
    }
}