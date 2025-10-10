# private helpers for the other NestedModules
Set-StrictMode -Version Latest
$ErrorActionPreference = [Management.Automation.ActionPreference]::Stop
. $PSScriptRoot\Variables.ps1
Add-Type -AssemblyName 'System.DirectoryServices.Protocols'


function Invoke-SearchRequest {
    [OutputType([PSCustumObject])]
    [CnmdletBinding()]
    param (
        # The filter to search for entries. Uses normal LDAP Search syntax, *not*
        # PS ActiveDirectory search.
        [string] $LDAPFilter,
        
        # The base path to search within on the given server
        [Parameter()]
        [string] $SearchBase,

        # The domain controller to query.
        [Parameter()]
        [string] $Server,

        # Credentials for the domain controller.
        [Parameter()]
        [PSCredential] $Credential
    )
    process {
        $ldapConnection = New-LDAPConnection $Server $Credential

        $searchRequest = [DirectoryServices.Protocols.SearchRequest]::new(
            $null, # DN
            '(objectClass=*)', # filter
            'Base', # mode
            '*' # attributes
        )

        $ldapConnection.SendRequest($searchRequest) |
            ConvertFrom-LDAPSearchResponse
        }
}


function ConvertFrom-LDAPSearchResponse {
    <#
    .SYNOPSIS
        Convert LDAP request response object into a PSCustomObject with all the members.
    #>
    param (
        [DirectoryServices.Protocols.SearchResponse] $response
    )
    process {
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
            # output
            [PSCustomObject] $table
        }
    }
}


function New-LDAPConnection {
    <#
    .SYNOPSIS
        Construct a new DirectoryServices.Protocols.LdapConnection using given parameters.
    .OUTPUTS
        A DirectoryServices.Protocols.LdapConnection
    #>
    [OutputType([DirectoryServices.Protocols.LdapConnection])]
    [CmdletBinding()]
    param (
        # The domain controller to query.
        [Parameter(ValueFromPipelineByPropertyName)]
        [string] $Server,

        # Credentials for the domain controller.
        [Parameter(ValueFromPipelineByPropertyName)]
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
        
        #output
        $ldapConnection
    }
}


function Get-LdapSearcher {
    [OutputType([DirectoryServices.DirectorySearcher])]
    [CmdletBinding()]
    param (
        # Path of the OU or container to search within, in DN form.
        [Parameter(ValueFromPipelineByPropertyName)]
        [string] $SearchBase,

        # Path of the OU or container to search within, in DN form but without
        # the DC components. Only used when SearchBase is not provided.
        [Parameter(ValueFromPipelineByPropertyName)]
        [string] $DefaultRelativeBase,

        [Parameter(ValueFromPipelineByPropertyName)]
        [string] $Server,

        [Parameter(ValueFromPipelineByPropertyName)]
        [PSCredential] $Credential
    )
    process {
        $ldapPath = if ($Server) { "LDAP://$Server" } else { "LDAP://" }
        $domainEntry = if ($Credential) {
            [DirectoryServices.DirectoryEntry]::new($ldapPath, $Credential.UserName, $Credential.GetNetworkCredential().Password)
        } else {
            [DirectoryServices.DirectoryEntry]::new($ldapPath)
        }

        if (-not $SearchBase) {
            $domainDN = $domainEntry.distinguishedName
            $SearchBase = if ($DefaultRelativeBase) {
                "$DefaultRelativeBase,$domainDN"
            } else {
                $null
            }
        }
        if ($SearchBase) {
            $ldapPath += "/$SearchBase"
        }
        Write-Verbose "Creating DirectorySearcher for LDAP path $ldapPath"
        $searchBaseEntry = if ($Credential) {
            [DirectoryServices.DirectoryEntry]::new($ldapPath, $Credential.UserName, $Credential.GetNetworkCredential().Password)
        } else {
            # output
            [DirectoryServices.DirectoryEntry]::new($ldapPath)
        }
        [DirectoryServices.DirectorySearcher]::new($searchBaseEntry)
    }
}


function Get-DistinguishedNameComponent {
    <#
    .SYNOPSIS
        Filter the components of a DistinguishedName.  Assumes that DN is
        ActiveDirectory-style, meaning CNs then OUs then DCs, no O or C or
        whatever.
    #>
    [OutputType([string])]
    [CmdletBinding()]
    [CmdletBinding()]
    param (
        [Parameter([string])]
        $DistinguishedName,

        [switch] $CommonName,

        [switch] $OrganizationalUnit,

        [switch] $DomainComponent
    )
    process
    {
        # (?<!XXX) is negative lookbehind to handle escaped commas \,
        $components = $DistinguishedName -split '(?<!\\),' 
        $result = @()
        if ($CommonName) {
            $result += $components | Where-Object -Match "^CN=.*$"
        }
        if ($OrganizationalUnit) {
            $result += $components | Where-Object -Match "^OU=.*$"
        }
        if ($DomainName) {
            $result += $components | Where-Object -Match "^DC=.*$"
        }

        # output
        $result -join ','
    }
}


function Convert-ADIdentityToFilter {
    [OutputType([string])]
    [CmdletBinding()]
    param (
        [ValidateNotNullOrEmpty()]
        [Parameter(ValueFromPipeline, Mandatory)]
        [string] $Identity
    )
    process {
        if ($Identity -match "^\*$") {
            throw [ArgumentException]::new("'*' cannot be used for -Identity parameters", 'Identity')
        }
        if ($Identity -match "^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$") {
            "(objectGUID=$Identity)"
        } elseif ($Identity -match "^S-\d-\d+-(\d+-){1,14}\d+$") {
            "(objectSid=$Identity)"
        } elseif ($Identity -match "^(?:(?<cn>CN=(?<name>[^,]*)),)?(?:(?<path>(?:(?:CN|OU)=[^,]+,?)+),)?(?<domain>(?:DC=[^,]+,?)+)$") {
            # regex from https://regexr.com/3l4au
            "(distinguishedName=$Identity)"
        } else {
            "(sAMAccountName=$Identity)"
        }
    }
}


function Update-ADUserEntry {
    param (
        [Parameter(Mandatory, ValueFromPipeline)]
        [DirectoryServices.DirectoryEntry] $Entry
    )
    process {
        Update-DirectoryEntryFlag $Entry userAccountControl $UserAccountControl_ACCOUNT_DISABLED -NotePropertyName Enabled -TrueValue $false -FalseValue $true
    }
}