# private helpers for the other NestedModules
Set-StrictMode -Version Latest
$ErrorActionPreference = [Management.Automation.ActionPreference]::Stop


Set-Variable UserAccountControl_ACCOUNT_DISABLED -Option ReadOnly -Value 0x02

# https://learn.microsoft.com/en-us/openspecs/windows_protocols/ms-adts/11972272-09ec-4a42-bf5e-3e99b321cf55
# The names do not match the GroupScope values, but that's what's documented.
# "Global" group
Set-Variable GroupType_ACCOUNT_GROUP -Option ReadOnly -Value 0x02
# "DomainLocal" group
Set-Variable GroupType_RESOURCE_GROUP -Option ReadOnly -Value 0x04
# "Universal" group
Set-Variable GroupType_UNIVERSAL_GROUP -Option ReadOnly -Value 0x08
# Security Enabled group
Set-Variable GroupType_SECURITY_ENABLED -Option ReadOnly -Value 0x80000000


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


Export-ModuleMember -Variable UserAccountControl_*, GroupType_* -Function *