#TODO: REMOVE THIS AFTER CONFIRMING UNUSED.
# private helpers for the other NestedModules
Set-StrictMode -Version Latest
$ErrorActionPreference = [Management.Automation.ActionPreference]::Stop
. $PSScriptRoot\Variables.ps1
Add-Type -AssemblyName 'System.DirectoryServices.Protocols'


function Invoke-SearchRequest {
    [OutputType([PSCustomObject])]
    [CmdletBinding()]
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
            $SearchBase, # DN
            $LDAPFilter, # filter
            'Subtree', # mode
            '*' # attributes
        )

        $ldapConnection.SendRequest($searchRequest)
    }
}


function ConvertFrom-LDAPSearchResponse {
    <#
    .SYNOPSIS
        Convert LDAP request response object into a PSCustomObject with all the members.
    #>
    [CmdletBinding()]
    param (
        [Parameter(ValueFromPipeline)]
        [DirectoryServices.Protocols.SearchResponse] $Response,

        [Parameter(Mandatory)]
        [scriptblock] $ObjectPropertyConverter
    )
    process {
        foreach ($entry in $Response.Entries) {
            $attributesTable = @{}

            # Build attributesTable out of response attributes. Some attributes
            # need special handling to parse their binary forms.
            foreach ($key in $entry.Attributes.Keys | Sort-Object) {
                $valueCollection = $entry.Attributes[$key]
                $attributesTable[$key] = if ($key -eq 'objectSid' -and $valueCollection[0] -is [byte[]]) {
                    [Security.Principal.SecurityIdentifier]::new($valueCollection[0], 0)
                } elseif ($key -eq 'objectGuid') {
                    [Guid]::new($valueCollection[0])
                } elseif ($valueCollection.Count -gt 1) {
                    # flatten & parse array of UTF-8 binary. Needed for objectClass, possibly others.
                    $valueCollection | Foreach-Object {
                        if ($_) { [Text.Encoding]::UTF8.GetString($_) }
                    }
                } else {
                    $valueCollection[0]
                }
            }

            # Use the provided converter to convert the attributes hashtable
            # into object properties, the make the object.
            $ObjectPropertyTable = Invoke-Command -ScriptBlock $ObjectPropertyConverter -ArgumentList $attributesTable

            $resultObject = [PSCustomObject] $ObjectPropertyTable
            Set-LDAPEntryAttributeTable $resultObject $attributesTable

            # output
            $resultObject
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


function Get-DistinguishedNameComponent {
    <#
    .SYNOPSIS
        Filter the components of a DistinguishedName.  Assumes that DN is
        ActiveDirectory-style, meaning CNs then OUs then DCs, no O or C or
        whatever.
    #>
    [OutputType([string])]
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


function Add-DirectoryAttributeModification {
    <#
    .SYNOPSIS
        Creates a DirectoryAttributeModification object with the Add operation.
    .OUTPUTS
        [DirectoryServices.Protocols.DirectoryAttributeModification] if PassThru is set.
    #>
    [OutputType([DirectoryServices.Protocols.DirectoryAttributeModification])]
    [CmdletBinding()]
    param (
        [Parameter(Position=0, Mandatory)]
        [AllowEmptyCollection()]
        [Collections.ArrayList] $AttributeModificationList,

        # The type of modification to perform.
        [Parameter(Position=1, Mandatory, ValueFromPipelineByPropertyName)]
        [DirectoryServices.Protocols.DirectoryAttributeOperation] $Operation,

        # The name of the attribute to modify.
        [Parameter(Position=2, Mandatory, ValueFromPipelineByPropertyName)]
        [string] $Name,

        # The value(s) to set on the attribute.
        [Parameter(Position=3, ValueFromPipelineByPropertyName)]
        [object[]] $Value,

        [Switch]
        $PassThru
    )
    process {
        $attributeModification = [DirectoryServices.Protocols.DirectoryAttributeModification]::new()
        $attributeModification.Name = $Name
        foreach ($val in $Value) {
            $attributeModification.Add($val) | Out-Null
        }
        $attributeModification.Operation = $Operation

        $AttributeModificationList.Add($attributeModification) | Out-Null
        if ($PassThru) {
            # output
            $modification
        }
    }
}


function Convert-ADDateTime {
    <#
    .SYNOPSIS
        Converts an LDAP date code (bigint 100-nanosecond intervals since
        1601-01-01) to local time.
    .OUTPUTS
        [Nullable[DateTime]] in local timezone. [DateTimeOffset] would be better
        but used [DateTime] for compatibility.
    #>
    [OutputType([Nullable[DateTime]])]
    [CmdletBinding()]
    param (
        # A time code expressed as "File Time"; The LDAP format represents
        # 100-nanosecond intervals since January 1, 1601.  It appears that
        # [Int64]::MaxValue is used to represent max date.
        [Parameter(ValueFromPipeline)]
        [Nullable[Int64]] $FileTimeValue
    )
    process {
        if ($FileTimeValue) {
            if ($FileTimeValue -eq [Int64]::MaxValue) {
                [DateTime]::MaxValue.ToLocalTime()
            } else {
                [DateTime]::FromFileTime($FileTimeValue).ToLocalTime()
            }
        }
    }
}