Set-StrictMode -Version Latest
$ErrorActionPreference = [Management.Automation.ActionPreference]::Stop
. $PSScriptRoot\Shared\Variables.ps1
Add-Type -AssemblyName 'System.DirectoryServices.Protocols'

function Get-ADUser {
    <#
    .SYNOPSIS
        Retrieves an Active Directory user.
    .DESCRIPTION
        Retrieves an Active Directory user by their identity, which can be a
        distinguished name, GUID, SID, or sAMAccountName.  
    .OUTPUTS
        [PSCustomObject], $null if not found.
    #>
    [OutputType([PSCustomObject])]
    [CmdletBinding(DefaultParameterSetName='Filter')]
    param (
        # The filter to search for users. Uses normal LDAP Search syntax, *not*
        # PS ActiveDirectory search.
        [Parameter(Mandatory, ValueFromPipeline, ParameterSetName='Filter')]
        [string] $LDAPFilter,

        # The identity of the user to retrieve. Can be sAMAcountName, SID, LDAP
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
        Get-ADObject 'User' @PSBoundParameters -ObjectPropertyConverter ${function:Convert-ADUserPropertyTable}
    }
}


function New-ADUser {
    <#
    .SYNOPSIS
        Creates a new Active Directory user.
    .DESCRIPTION
        Creates a new Active Directory user with the specified name.
    .OUTPUTS
        [PSCustomObject] if PassThru is enabled.
    #>
    [Diagnostics.CodeAnalysis.SuppressMessage(
        "PSShouldProcess","",Scope="Function",Justification='-WhatIf passed through to ADObject func'
    )]
    [OutputType([PSCustomObject])]
    [CmdletBinding(SupportsShouldProcess)]
    param (
        # The name of the new user.
        [Parameter(Mandatory)]
        [string] $Name,

        # The path to create the user in.  Optional, by default wil create it in
        # "CN=Users,DC=<your domain etc>"
        [Parameter()]
        [string] $Path,

        # Whether or not the user is enabled. Defaults to "True" if not set.
        [Parameter()]
        [Nullable[bool]] $Enabled,

        # A hashtable of LDAP attributes to set on the user.
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
    begin {
        # default to enabled. Everywhere else Enabled is nullable and null means
        # "no change" except here.
        if ($Null -eq $Enabled) {
            $Enabled = $true
        }
        $commonParams = @{
            WhatIf = $WhatIfPreference
            Verbose = $VerbosePreference
        }
    }
    process {
        $entry = New-ADObject 'User' 'CN' $Name `
            -Path $Path `
            -DefaultRelativePath 'CN=Users' `
            -ObjectPropertyConverter ${function:Convert-ADUserPropertyTable} `
            -Server $Server `
            -Credential $Credential `
            -DoSAMAccountName `
            -PassThru `
            @commonParams

        if (($null -ne $Enabled) -or $OtherAttributes) {
            $entry = Set-ADUser -Identity $entry.DistinguishedName -Enabled $Enabled -Replace $OtherAttributes -Server $Server -Credential $Credential -PassThru @commonParams
        }
        
        if ($PassThru) {
            # output
            $entry
        }
    }
}


function Set-ADUser {
    <#
    .SYNOPSIS
        Modifies an Active Directory user.
    .DESCRIPTION
        Modifies an Active Directory user with the specified properties.
    .OUTPUTS
        [PSCustomObject] if PassThru is enabled.
    #>
    [Diagnostics.CodeAnalysis.SuppressMessage(
        'PSShouldProcess','',Scope='Function',Justification='-WhatIf passed through to ADObject func'
    )]
    [OutputType([PSCustomObject])]
    [CmdletBinding(SupportsShouldProcess)]
    param (
        # The identity of the user to modify.
        [Parameter(Mandatory, ValueFromPipeline)]
        [string] $Identity,

        [Parameter()]
        [Nullable[bool]] $Enabled,

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
        $entry = Get-ADUser -Identity $Identity -Server $Server -Credential $Credential
        if (($null -ne $Enabled) -or $Add -or $Remove -or $Replace) {
            Set-ADUserEntry $entry -Enabled $Enabled @commonParams

            # clone $Replace so we can modify it here
            $replacementsTable = if ($Replace) {
                $Replace.Clone()
            } else {
                @{}
            }
            # using Add to force error if "replace" already has GroupType.
            $replacementsTable.Add('userAccountControl', $entry.Properties['userAccountControl'])

            Set-ADObject 'User' -Identity $Identity -Add $Add -Remove $Remove -Replace $replacementsTable -Server $Server -Credential $Credential @commonParams
            Set-ADObjectEntry $entry -Add $Add -Remove $Remove -Replace $replacementsTable @commonParams
            Update-ADUserEntry $entry @commonParams
        } else {
            Write-Warning "Can't update user '$Identity', nothing to do."
        }

        if ($PassThru) {
            # output
            $entry
        }
    }
}


function Remove-ADUser {
    <#
    .SYNOPSIS
        Removes an Active Directory user.
    .DESCRIPTION
        Removes an Active Directory user by their identity.
    .OUTPUTS
        None
    #>
    [Diagnostics.CodeAnalysis.SuppressMessage("PSShouldProcess","",Scope="Function")] # -WhatIf passed through to ADObject func
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
        Remove-ADObject 'User' @PSBoundParameters
    }
}


function Test-ADUser {
    <#
    .SYNOPSIS
        Tests if an Active Directory user exists.
    .DESCRIPTION
        Tests if an Active Directory user exists by their identity.
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
        [PSCredential] $Credential
    )
    process {
        Test-ADObject 'User' @PSBoundParameters
    }
}


#region private
function Update-ADUserEntry {
    <#
    .SYNOPSIS
        Recalculate the local properties of a directory entry PSCustomObject representing an AD user.
    #>
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
        Update-LDAPEntryFlag $Entry userAccountControl $UserAccountControl_ACCOUNT_DISABLED -NotePropertyName Enabled -TrueValue $false -FalseValue $true @commonParams
        Update-ADObjectEntry $Entry -ObjectPropertyConverter ${function:Convert-ADUserPropertyTable} @commonParams
    }
}


function Set-ADUserEntry {
    <#
    .SYNOPSIS
        Set the members of an AD User directory entry PSCustomObject
    #>
    [Diagnostics.CodeAnalysis.SuppressMessage("PSShouldProcess","",Scope="Function")] # -WhatIf passed through to ADObject func
    [CmdletBinding(SupportsShouldProcess)]
    param (
        [Parameter(Mandatory, ValueFromPipeline)]
        [PSCustomObject] $Entry,

        [Parameter()]
        [Nullable[bool]] $Enabled
    )
    begin {
        $commonParams = @{
            WhatIf = $WhatIfPreference
            Verbose = $VerbosePreference
        }
    }
    process {
        if ($null -ne $Enabled) {
            Set-LDAPEntryFlag $Entry userAccountControl $UserAccountControl_ACCOUNT_DISABLED -Value (-not $Enabled) @commonParams
        }
        Update-ADObjectEntry $Entry -ObjectPropertyConverter ${function:Convert-ADUserPropertyTable}
    }
}


function Convert-ADUserPropertyTable {
    <#
    .SYNOPSIS
        Takes a table of raw LDAP properties and converts them into a table of
        object properties for an ADObject.
    .NOTES
        Adapted from https://learn.microsoft.com/en-us/archive/technet-wiki/12037.active-directory-get-aduser-default-band-extended-properties
    #>
    [CmdletBinding()]
    param (
        [Parameter(Mandatory, ValueFromPipeline)]
        [hashtable] $LdapAttributeTable,

        [Parameter()]
        [hashtable] $ObjectPropertyTable
    )
    process {
        if(-not $ObjectPropertyTable) {
            $ObjectPropertyTable = @{}
        }

        Convert-ADObjectPropertyTable -LdapAttributeTable $LdapAttributeTable -ObjectPropertyTable $ObjectPropertyTable | Out-Null

        # regex used to initially create this
        # (\w+)\t([a-zA-Z0-9 ()]+)\t(\w+)\t(.*)
        # $ObjectPropertyTable['$1'] = $LdapAttributeTable['$4']
        $ObjectPropertyTable['AccountExpirationDate'] = Convert-ADDateTime $LdapAttributeTable['accountExpires']
        $ObjectPropertyTable['AccountLockoutTime'] = Convert-ADDateTime $LdapAttributeTable['lockoutTime']
        $ObjectPropertyTable['AccountNotDelegated'] = [bool] ($LdapAttributeTable['userAccountControl'] -band $UserAccountControl_NOT_DELEGATED)
        $ObjectPropertyTable['AllowReversiblePasswordEncryption'] = [bool] ($LdapAttributeTable['userAccountControl'] -band $UserAccountControl_ENCRYPTED_TEXT_PWD_ALLOWED)
        $ObjectPropertyTable['BadLogonCount'] = $LdapAttributeTable['badPwdCount']
        $ObjectPropertyTable['CannotChangePassword'] = $LdapAttributeTable['nTSecurityDescriptor']
        $ObjectPropertyTable['Certificates'] = $LdapAttributeTable['userCertificate']
        $ObjectPropertyTable['ChangePasswordAtLogon'] = $LdapAttributeTable['pwdLastSet'] -eq 0
        $ObjectPropertyTable['City'] = $LdapAttributeTable['l']
        $ObjectPropertyTable['Company'] = $LdapAttributeTable['company']
        $ObjectPropertyTable['Country'] = $LdapAttributeTable['c'] # (2 character abbreviation)
        $ObjectPropertyTable['Department'] = $LdapAttributeTable['department']
        $ObjectPropertyTable['Division'] = $LdapAttributeTable['division']
        $ObjectPropertyTable['DoesNotRequirePreAuth'] = [bool] ($LdapAttributeTable['userAccountControl'] -band $UserAccountControl_DONT_REQ_PREAUTH)
        $ObjectPropertyTable['EmailAddress'] = $LdapAttributeTable['mail']
        $ObjectPropertyTable['EmployeeID'] = $LdapAttributeTable['employeeID']
        $ObjectPropertyTable['EmployeeNumber'] = $LdapAttributeTable['employeeNumber']
        $ObjectPropertyTable['Enabled'] = -not ($LdapAttributeTable['userAccountControl'] -band $UserAccountControl_ACCOUNT_DISABLED)
        $ObjectPropertyTable['Fax'] = $LdapAttributeTable['facsimileTelephoneNumber']
        $ObjectPropertyTable['GivenName'] = $LdapAttributeTable['givenName']
        $ObjectPropertyTable['HomeDirectory'] = $LdapAttributeTable['homeDirectory']
        $ObjectPropertyTable['HomedirRequired'] = [bool] ($LdapAttributeTable['userAccountControl'] -band $UserAccountControl_HOMEDIR_REQUIRED)
        $ObjectPropertyTable['HomeDrive'] = $LdapAttributeTable['homeDrive']
        $ObjectPropertyTable['HomePage'] = $LdapAttributeTable['wWWHomePage']
        $ObjectPropertyTable['HomePhone'] = $LdapAttributeTable['homePhone']
        $ObjectPropertyTable['Initials'] = $LdapAttributeTable['initials']
        $ObjectPropertyTable['LastBadPasswordAttempt'] = Convert-ADDateTime $LdapAttributeTable['badPasswordTime']
        $ObjectPropertyTable['LastLogonDate'] = Convert-ADDateTime $LdapAttributeTable['lastLogonTimeStamp']
        $ObjectPropertyTable['LockedOut'] = [bool] ($LdapAttributeTable['msDS-User-Account-Control-Computed'] -band $UserAccountControl_LOCKOUT)
        $ObjectPropertyTable['LogonWorkstations'] = $LdapAttributeTable['userWorkstations']
        $ObjectPropertyTable['Manager'] = $LdapAttributeTable['manager']
        $ObjectPropertyTable['MemberOf'] = $LdapAttributeTable['memberOf']
        $ObjectPropertyTable['MNSLogonAccount'] = [bool] ($LdapAttributeTable['userAccountControl'] -band $UserAccountControl_MNS_LOGON_ACCOUNT)
        $ObjectPropertyTable['MobilePhone'] = $LdapAttributeTable['mobile']
        $ObjectPropertyTable['Office'] = $LdapAttributeTable['physicalDeliveryOfficeName']
        $ObjectPropertyTable['OfficePhone'] = $LdapAttributeTable['telephoneNumber']
        $ObjectPropertyTable['Organization'] = $LdapAttributeTable['o']
        $ObjectPropertyTable['OtherName'] = $LdapAttributeTable['middleName']
        $ObjectPropertyTable['PasswordExpired'] = [bool] ($LdapAttributeTable['msDS-User-Account-Control-Computed'] -band $UserAccountControl_PASSWORD_EXPIRED) # see note 1
        $ObjectPropertyTable['PasswordLastSet'] = Convert-ADDateTime $LdapAttributeTable['pwdLastSet']
        $ObjectPropertyTable['PasswordNeverExpires'] = [bool] ($LdapAttributeTable['userAccountControl'] -band $UserAccountControl_DONT_EXPIRE_PASSWORD)
        $ObjectPropertyTable['PasswordNotRequired'] = [bool] ($LdapAttributeTable['userAccountControl'] -band $UserAccountControl_PASSWD_NOTREQD)
        $ObjectPropertyTable['POBox'] = $LdapAttributeTable['postOfficeBox']
        $ObjectPropertyTable['PostalCode'] = $LdapAttributeTable['postalCode']
        $ObjectPropertyTable['PrimaryGroup'] = $LdapAttributeTable['Group with primaryGroupToken']
        $ObjectPropertyTable['ProfilePath'] = $LdapAttributeTable['profilePath']
        $ObjectPropertyTable['SamAccountName'] = $LdapAttributeTable['sAMAccountName']
        $ObjectPropertyTable['ScriptPath'] = $LdapAttributeTable['scriptPath']
        $ObjectPropertyTable['ServicePrincipalNames'] = $LdapAttributeTable['servicePrincipalName']
        $ObjectPropertyTable['SID'] = [string] $LdapAttributeTable['objectSID']
        $ObjectPropertyTable['SIDHistory'] = $LdapAttributeTable['sIDHistory']
        $ObjectPropertyTable['SmartcardLogonRequired'] = [bool] ($LdapAttributeTable['userAccountControl'] -band $UserAccountControl_SMARTCARD_REQUIRED)
        $ObjectPropertyTable['State'] = $LdapAttributeTable['st']
        $ObjectPropertyTable['StreetAddress'] = $LdapAttributeTable['streetAddress']
        $ObjectPropertyTable['Surname'] = $LdapAttributeTable['sn']
        $ObjectPropertyTable['Title'] = $LdapAttributeTable['title']
        $ObjectPropertyTable['TrustedForDelegation'] = [bool] ($LdapAttributeTable['userAccountControl'] -band $UserAccountControl_TRUSTED_FOR_DELEGATION)
        $ObjectPropertyTable['TrustedToAuthForDelegation'] = [bool] ($LdapAttributeTable['userAccountControl'] -band $UserAccountControl_TRUSTED_TO_AUTH_FOR_DELEGATION)
        $ObjectPropertyTable['UseDESKeyOnly'] = [bool] ($LdapAttributeTable['userAccountControl'] -band $UserAccountControl_USE_DES_KEY_ONLY)
        $ObjectPropertyTable['UserPrincipalName'] = $LdapAttributeTable['userPrincipalName']

        #output
        $ObjectPropertyTable
    }
}
#endregion