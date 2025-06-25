Import-Module "$PSScriptRoot\Shared\SharedMetaModule.psm1"
Set-StrictMode -Version Latest
$ErrorActionPreference = [Management.Automation.ActionPreference]::Stop


function Get-ADUser {
    <#
    .SYNOPSIS
        Retrieves an Active Directory user.
    .DESCRIPTION
        Retrieves an Active Directory user by their identity, which can be a
        distinguished name, GUID, SID, or sAMAccountName.  
    .OUTPUTS
        [System.DirectoryServices.DirectoryEntry]
        # $null if not found.
    #>
    [OutputType([DirectoryServices.DirectoryEntry])]
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
        $entries = Get-ADObject 'User' @PSBoundParameters
        foreach ($entry in $entries) {
            Update-ADUserEntry $entry
            
            # output
            $entry
        }
    }
}


function New-ADUser {
    <#
    .SYNOPSIS
        Creates a new Active Directory user.
    .DESCRIPTION
        Creates a new Active Directory user with the specified name.       
    .OUTPUTS
        [System.DirectoryServices.DirectoryEntry]
    #>
    [Diagnostics.CodeAnalysis.SuppressMessage("PSShouldProcess","",Scope="Function")] # -WhatIf passed through to ADObject func
    [OutputType([DirectoryServices.DirectoryEntry])]
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

        # A hashtable of properties to set on the user.
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
    }
    process {
        $entry = New-ADObject 'User' 'CN' $Name `
            -Path $Path `
            -DefaultRelativePath 'CN=Users' `
            -Server $Server `
            -Credential $Credential `
            -WhatIf:$WhatIfPreference `
            -Verbose:$VerbosePreference `
            -DoSAMAccountName

        if (($null -ne $Enabled) -or ($OtherAttributes)) {
            Set-ADUserEntry $entry -Enabled $Enabled -OtherAttributes $OtherAttributes
            $entry.CommitChanges()
        }
        
        if ($PassThru) {
            Update-ADUserEntry $entry

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
        [System.DirectoryServices.DirectoryEntry]
    #>
    [Diagnostics.CodeAnalysis.SuppressMessage("PSShouldProcess","",Scope="Function")] # -WhatIf passed through to ADObject func
    [OutputType([DirectoryServices.DirectoryEntry])]
    [CmdletBinding(SupportsShouldProcess)]
    param (
        # The identity of the user to modify.
        [Parameter(Mandatory, ValueFromPipeline)]
        [string] $Identity,

        [Parameter()]
        [Nullable[bool]] $Enabled,

        # A hashtable of properties to set on the user.
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
        $entry = Get-ADObject 'User' -Identity $Identity -Server $Server $Credential $Credential
        if (($null -ne $Enabled) -or ($OtherAttributes)) {
            Set-ADUserEntry $entry -Enabled $Enabled -OtherAttributes $OtherAttributes
            $entry.CommitChanges()
        } else {
            Write-Warning "Can't update user '$Identity', nothing to do."
        }

        if ($PassThru) {
            Update-ADGroupEntry $entry

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
        [Parameter(Mandatory, ValueFromPipeline)]
        [string] $Identity,

        [string] $Server,
        [PSCredential] $Credential
    )
    process {
        Test-ADObject 'User' @PSBoundParameters
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


Export-ModuleMember -Function *-ADUser, *-ADUserEntry


function Set-ADUserEntry {
    [Diagnostics.CodeAnalysis.SuppressMessage("PSShouldProcess","",Scope="Function")] # -WhatIf passed through to ADObject func
    [CmdletBinding(SupportsShouldProcess)]
    param (
        [Parameter(Mandatory, ValueFromPipeline)]
        [DirectoryServices.DirectoryEntry] $Entry,

        [Parameter()]
        [Nullable[bool]] $Enabled,

        [Parameter()]
        [Hashtable] $OtherAttributes
    )
    process {
        if ($null -ne $Enabled) {
            Set-DirectoryEntryFlag $Entry userAccountControl $UserAccountControl_ACCOUNT_DISABLED -Value $Enabled -WhatIf:$WhatIfPreference
        }
        if ($OtherAttributes) {
            Set-DirectoryEntryPropertyTable $Entry $OtherAttributes -WhatIf:$WhatIfPreference
        }
    }
}