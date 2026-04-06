Set-StrictMode -Version Latest
$ErrorActionPreference = [Management.Automation.ActionPreference]::Stop
. $PSScriptRoot\Shared\Variables.ps1


function Get-ADGroup {
    <#
    .SYNOPSIS
        Retrieves an Active Directory group.
    .DESCRIPTION
        Retrieves an Active Directory group using System.DirectoryServices.
    .OUTPUTS
        [PSCustomObject], none if not found.
    #>
    [OutputType([PSCustomObject])]
    [CmdletBinding(DefaultParameterSetName='Filter')]
    param (
        # The filter to search for groups. Uses normal LDAP Search syntax, *not*
        # PS ActiveDirectory search.
        [Parameter(Mandatory, ValueFromPipeline, ParameterSetName='Filter')]
        [string] $LDAPFilter,

        # The identity of the group to retrieve. Can be sAMAcountName, SID, LDAP
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
        $entries = Get-ADObject 'Group' -ObjectPropertyConverter ${function:Convert-ADGroupPropertyTable} @PSBoundParameters
        foreach ($entry in $entries) {
            Update-ADGroupEntry $entry
            
            # output
            $entry
        }
    }
}


function New-ADGroup {
    <#
    .SYNOPSIS
        Creates a new Active Directory group.
    .DESCRIPTION
        Creates a new Active Directory group using System.DirectoryServices.
    .OUTPUTS
        [PSCustomObject] if PassThru is enabled.
    #>
    [Diagnostics.CodeAnalysis.SuppressMessage(
        'PSShouldProcess','',Scope='Function',Justification='-WhatIf passed through to ADObject func'
    )]
    [OutputType([PSCustomObject])]
    [CmdletBinding(SupportsShouldProcess)]
    param (
        # The name of the new group.
        [Parameter(Mandatory, ValueFromPipeline)]
        [string] $Name,

        # DistinguishedName path of the parent container.  If not provided will
        # parent directly to the default Domain.
        [Parameter()]
        [string] $Path,

        [ValidateSet('', 'Distribution', 'Security')]
        [Parameter()]
        [string] $GroupCategory,

        [ValidateSet('', 'Global', 'DomainLocal', 'Universal')]
        [Parameter()]
        [string] $GroupScope,

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
        $entry = New-ADObject 'Group' 'CN' $Name `
            -Path $Path `
            -DefaultRelativePath 'CN=Users' `
            -ObjectPropertyConverter ${function:Convert-ADGroupPropertyTable} `
            -OtherAttributes $OtherAttributes `
            -Server $Server `
            -Credential $Credential `
            @commonParams `
            -PassThru `
            -DoSAMAccountName

        if ($GroupCategory -or $GroupScope) {
            Set-ADGroup $entry.DistinguishedName -GroupCategory $GroupCategory -GroupScope $GroupScope -Server $Server -Credential $Credential @commonParams
        }

        if ($GroupCategory -or $GroupScope) {
            Set-ADGroupEntry $entry -GroupCategory $GroupCategory -GroupScope $GroupScope @commonParams
            Update-ADGroupEntry $entry
        }

        if ($PassThru) {
            # output
            $entry
        }
    }
}


function Set-ADGroup {
    <#
    .SYNOPSIS
        Modifies an Active Directory group.
    .DESCRIPTION
        Modifies an Active Directory group using System.DirectoryServices.
    .OUTPUTS
        [PSCustomObject] if PassThru is enabled.
    #>
    [Diagnostics.CodeAnalysis.SuppressMessage(
        'PSShouldProcess','',Scope='Function',Justification='-WhatIf passed through to ADObject func'
    )]
    [OutputType([PSCustomObject])]
    [CmdletBinding(SupportsShouldProcess)]
    param (
        # The identity of the group to alter. Can be sAMAcountName, SID, LDAP
        # path, or distinguished name.
        [Parameter(Mandatory, ValueFromPipeline)]
        [string] $Identity,

        [ValidateSet('', 'Distribution', 'Security')]
        [Parameter()]
        [string] $GroupCategory,

        [ValidateSet('', 'Global', 'DomainLocal', 'Universal')]
        [Parameter()]
        [string] $GroupScope,

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
        $entry = Get-ADGroup -Identity $Identity -Server $Server -Credential $Credential
        if ($GroupCategory -or $GroupScope -or $Add -or $Remove -or $Replace) {

            # clone $Replace so we can modify it here
            $replacementsTable = if ($OtherAttributes) {
                $Replace.Clone()
            } else {
                @{}
            }

            # using Add to force error if "replace" already has GroupType.
            $replacementsTable.Add('GroupType', $entry.Properties['GroupType'])

            Set-ADObject 'Group' -Identity $Identity -Add $Add -Remove $Remove -Replace $replacementsTable -Server $Server -Credential $Credential @commonParams
            Set-ADObjectEntry $Entry -Add $Add -Remove $Remove -Replace $replacementsTable @commonParams
            Update-ADGroupEntry $entry
        } else {
            Write-Warning "Can't update group '$Identity', nothing to do."
        }

        if ($PassThru) {
            # output
            $entry
        }
    }
}


function Remove-ADGroup {
    <#
    .SYNOPSIS
        Removes an Active Directory group.
    .DESCRIPTION
        Removes an Active Directory group using System.DirectoryServices.
    .OUTPUTS
        None
    #>
    [Diagnostics.CodeAnalysis.SuppressMessage(
        'PSShouldProcess','',Scope='Function',Justification='-WhatIf passed through to ADObject func'
    )]
    [CmdletBinding(SupportsShouldProcess)]
    param (
        # The identity of the group to alter. Can be sAMAcountName, SID, LDAP
        # path, or distinguished name.
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
        Remove-ADObject 'Group' @PSBoundParameters
    }
}


function Test-ADGroup {
    <#
    .SYNOPSIS
        Tests the existence of an Active Directory group.
    .DESCRIPTION
        Tests the existence of an Active Directory group using System.DirectoryServices.
    .OUTPUTS
        [bool]
    #>
    [OutputType([bool])]
    [CmdletBinding()]
    param (
        # The identity of the group to test. Can be sAMAcountName, SID, LDAP
        # path, or distinguished name.
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
        Test-ADObject 'Group' @PSBoundParameters
    }
}


#private
function Update-ADGroupEntry {
    param (
        [Parameter(Mandatory, ValueFromPipeline)]
        [PSCustomObject] $Entry
    )
    process {
        Update-LDAPEntryFlag $Entry GroupType $GroupType_ACCOUNT_GROUP -NotePropertyName GroupScope -TrueValue Global
        Update-LDAPEntryFlag $Entry GroupType $GroupType_RESOURCE_GROUP -NotePropertyName GroupScope -TrueValue DomainLocal
        Update-LDAPEntryFlag $Entry GroupType $GroupType_UNIVERSAL_GROUP -NotePropertyName GroupScope -TrueValue Universal

        Update-LDAPEntryFlag $Entry GroupType $GroupType_SECURITY_ENABLED -NotePropertyName GroupCategory -TrueValue Security -FalseValue Distribution

        Update-ADObjectEntry $Entry -ObjectPropertyConverter ${function:Convert-ADGroupPropertyTable}

    }
}


#private
function Set-ADGroupEntry {
    [Diagnostics.CodeAnalysis.SuppressMessage(
        'PSShouldProcess','',Scope='Function',Justification='-WhatIf passed through to LDAPEntry func'
    )]
    [CmdletBinding(SupportsShouldProcess)]
    param (
        [Parameter(Mandatory, ValueFromPipeline)]
        [PSCustomObject] $Entry,

        [ValidateSet('', 'Distribution', 'Security')]
        [Parameter()]
        [string] $GroupCategory,

        [ValidateSet('', 'Global', 'DomainLocal', 'Universal')]
        [Parameter()]
        [string] $GroupScope,

        # A hashtable of LDAP attributes to set on the user.
        [Parameter()]
        [hashtable] $OtherAttributes
    )
    begin {
        $commonParams = @{
            WhatIf = $WhatIfPreference
            Verbose = $VerbosePreference
        }
    }
    process {
        [nullable[bool]] $securityEnabled = if ($GroupCategory -eq 'Security') {
            $true
        } elseif ($GroupCategory -eq 'Distribution') {
            $false
        } else {
            $null
        }
        if ($null -ne $securityEnabled) {
            Set-LDAPEntryFlag $Entry GroupType $GroupType_SECURITY_ENABLED -Value $securityEnabled @commonParams
        }

        if ($GroupScope -eq 'Global') {
            Set-LDAPEntryFlag $Entry GroupType $GroupType_ACCOUNT_GROUP -Value $true @commonParams
            Set-LDAPEntryFlag $Entry GroupType $GroupType_RESOURCE_GROUP -Value $false @commonParams
            Set-LDAPEntryFlag $Entry GroupType $GroupType_UNIVERSAL_GROUP -Value $false @commonParams
        } elseif ($GroupScope -eq 'DomainLocal') {
            Set-LDAPEntryFlag $Entry GroupType $GroupType_ACCOUNT_GROUP -Value $false @commonParams
            Set-LDAPEntryFlag $Entry GroupType $GroupType_RESOURCE_GROUP -Value $true @commonParams
            Set-LDAPEntryFlag $Entry GroupType $GroupType_UNIVERSAL_GROUP -Value $false @commonParams
        } elseif ($GroupScope -eq 'Universal') {
            Set-LDAPEntryFlag $Entry GroupType $GroupType_ACCOUNT_GROUP -Value $false @commonParams
            Set-LDAPEntryFlag $Entry GroupType $GroupType_RESOURCE_GROUP -Value $false @commonParams
            Set-LDAPEntryFlag $Entry GroupType $GroupType_UNIVERSAL_GROUP -Value $true @commonParams
        }

        if ($OtherAttributes) {
            Update-ADGroupEntry $Entry -Replace $OtherAttributes @commonParams
        }
    }
}


function Convert-ADGroupPropertyTable {
    <#
    .SYNOPSIS
        Takes a table of raw LDAP properties and converts them into a table of
        object properties for an ADGroup.
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

        Convert-ADObjectPropertyTable -LdapAttributeTable $LdapAttributeTable -ObjectPropertyTable $ObjectPropertyTable | Out-Null

        $ObjectPropertyTable['GroupCategory'] = if($LdapAttributeTable['groupType'] -band $GroupType_SECURITY_ENABLED) {
            'Security'
        } else {
            'Distribution'
        }

        $ObjectPropertyTable['GroupScope'] = if ($LdapAttributeTable['groupType'] -band $GroupType_ACCOUNT_GROUP) {
            'Global'
        } elseif ($LdapAttributeTable['groupType'] -band $GroupType_RESOURCE_GROUP) {
            'DomainLocal'
        } elseif ($LdapAttributeTable['groupType'] -band $GroupType_UNIVERSAL_GROUP) {
            'Universal'
        } # (bit mask 1, 2, 4, or 8)']
        $ObjectPropertyTable['HomePage'] = $LdapAttributeTable['wWWHomePage']
        $ObjectPropertyTable['ManagedBy'] = $LdapAttributeTable['managedBy']
        $ObjectPropertyTable['MemberOf'] = $LdapAttributeTable['memberOf']
        $ObjectPropertyTable['Members'] = $LdapAttributeTable['member']
        $ObjectPropertyTable['SamAccountName'] = $LdapAttributeTable['sAMAccountName']
        $ObjectPropertyTable['SID'] = $LdapAttributeTable['objectSID'].ToString()
        $ObjectPropertyTable['SIDHistory'] = $LdapAttributeTable['sidHistory']
        
        #output
        $ObjectPropertyTable
    }
}