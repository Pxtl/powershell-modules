
Set-StrictMode -Version Latest
$ErrorActionPreference = [Management.Automation.ActionPreference]::Stop
Add-Type -AssemblyName 'System.DirectoryServices.Protocols'

function Get-ADRootDSE {
    <#
    .SYNOPSIS
        Gets the root of a directory server information tree.
    #>
    param (
        # The domain controller to query.
        [Parameter()]
        [string] $Server,

        # Credentials for the domain controller.
        [Parameter()]
        [PSCredential] $Credential
    )
    process {
        $directoryIdentifier = [DirectoryServices.Protocols.LdapDirectoryIdentifier]::new($Server)
        $networkCredential = if ($Credential) {
            $Credential.GetNetworkCredential()
        }
        $ldapConnection = [DirectoryServices.Protocols.LdapConnection]::new(
            $directoryIdentifier, $networkCredential
        )
        $ldapConnection.Bind()

        $searchRequest = [DirectoryServices.Protocols.SearchRequest]::new(
            $null, # DN
            '(objectClass=*)', # filter
            'Base', # mode
            '*' # attributes
        )

        $response = $ldapConnection.SendRequest($searchRequest)
        foreach ($entry in $response.Entries) {
            $table = @{}
            foreach ($key in $entry.Attributes.Keys | Sort-Object) {
                $valueCollection = $entry.Attributes[$key]
                if ($valueCollection.Count -gt 1) {
                    $table[$key] = $valueCollection | ForEach-Object { $_ }
                } else {
                    $table[$key] = $valueCollection[0]
                }
            }
            [PSCustomObject] $table
        }
    }
}