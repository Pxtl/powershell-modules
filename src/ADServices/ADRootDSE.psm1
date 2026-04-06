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
        ConvertFrom-LDAPSearchResponse $response ${function:Convert-ADObjectPropertyTable}
    }
}


