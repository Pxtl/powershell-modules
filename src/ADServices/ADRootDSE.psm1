Import-Module "$PSScriptRoot\Shared\ADHelpers.psm1" -Verbose:$false
Set-StrictMode -Version Latest
$ErrorActionPreference = [Management.Automation.ActionPreference]::Stop

function Get-ADRootDSE {
    <#
    .SYNOPSIS
        Gets the root of a directory server information tree.
    #>
    param (
        # The domain controller to query.
        [Parameter(ValueFromPipelineByPropertyName)]
        [string] $Server,

        # Credentials for the domain controller.
        [Parameter(ValueFromPipelineByPropertyName)]
        [PSCredential] $Credential
    )
    process {
        $searchRequest = [DirectoryServices.Protocols.SearchRequest]::new(
            $null, # DN
            '(objectClass=*)', # filter
            'Base', # mode
            '*' # attributes
        )
        $ldapConnection = New-LDAPConnection $Server $Credential

        $response = $ldapConnection.SendRequest($searchRequest)

        # output
        ConvertFrom-LDAPSearchResponse $response ${function:Convert-ADRootDSEPropertyTable}
    }
}


function Convert-ADRootDSEPropertyTable {
    <#
    .SYNOPSIS
        Takes a table of raw LDAP attributes and converts them into a table of
        object properties for the ADRootDSE.
    .NOTES
        Unlike every other AD object, this one is used basically raw.
    #>
    [CmdletBinding()]
    param (
        [Parameter(Mandatory, ValueFromPipeline)]
        [hashtable] $LdapAttributeTable,
        [hashtable] $ObjectPropertyTable
    )
    process {
        if(-not $ObjectPropertyTable) {
            $ObjectPropertyTable = @{}
        }

        foreach ($key in ($LdapAttributeTable.Keys | Sort-Object)) {
            $ObjectPropertyTable[$key] = $LdapAttributeTable[$key]
        }

        #output
        $ObjectPropertyTable
    }
}


function Get-DistinguishedName {
    <#
    .SYNOPSIS
        Because ADRootDSE is not guaranteed to have a distinguished name, we
        can't just do $entry.DistinguishedName on all objects.  So this function
        ensures that it won't error out.
    #>
    [CmdletBinding()]
    param (
        [Parameter(Mandatory, ValueFromPipeline)]
        [PSCustomObject] $Entry
    )
    process {
        $Entry.Attributes['distinguishedName']
    }
}