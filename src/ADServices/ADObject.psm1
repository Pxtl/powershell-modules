Import-Module "$PSScriptRoot\Shared\ADHelpers.psm1" -Verbose:$false
Set-StrictMode -Version Latest
$ErrorActionPreference = [Management.Automation.ActionPreference]::Stop


function Get-ADObject {
    <#
    .SYNOPSIS
        Retrieves an LDAP DirectoryEntry.
    .DESCRIPTION
        Retrieves an LDAP DirectoryEntry by their identity, which can be a
        distinguished name, GUID, SID, or sAMAccountName.  
    .OUTPUTS
        [System.DirectoryServices.DirectoryEntry]
        # $null if not found.
    #>
    [OutputType([DirectoryServices.DirectoryEntry])]
    [CmdletBinding(DefaultParameterSetName='Filter')]
    param (
        # The ObjectClass to search for.
        [Parameter(Position=0)]
        [string] $Type,

        # The filter to search for entries. Uses normal LDAP Search syntax, *not*
        # PS ActiveDirectory search.
        [Parameter(Mandatory, ValueFromPipeline, ParameterSetName='Filter')]
        [string] $LDAPFilter,

        # The identity of the entry to retrieve. Can be sAMAcountName, SID, LDAP
        # path, or distinguished name.
        [Parameter(Mandatory, ValueFromPipeline, ParameterSetName='Identity')]
        [string] $Identity,

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
    begin {
        $searcher = Get-LdapSearcher -SearchBase $SearchBase -Server $Server -Credential $Credential -Verbose:$VerbosePreference
    }
    process {
        if ($Identity) {
            $LDAPFilter = Convert-ADIdentityToFilter -Identity $Identity
        }

        if ($Type) {
            $searcher.Filter = "(&(objectClass=$Type)($LDAPFilter))"
        } else {
            $searcher.Filter = "($LDAPFilter)"
        }
        Write-Verbose "Searching for '$($searcher.Filter)'"
        $searchResult = $searcher.FindAll()
        if ($Identity) {
            $resultCount = $searchResult | Measure-Object | Select-Object -ExpandProperty Count
            if ($resultCount -gt 1) {
                throw [InvalidOperationException]::new("Identity value '$Identity' returned multiple values of class '$Type', which isn't supposed to be possible.")
            }
        }
        foreach ($resultItem in $searchResult) {
            # output
            $resultItem.GetDirectoryEntry()
        }
    }
}


function New-ADObject {
    <#
    .SYNOPSIS
        Creates a new LDAP DirectoryEntry.
    .DESCRIPTION
        Creates a new LDAP DirectoryEntry with the specified name.
    .OUTPUTS
        [System.DirectoryServices.DirectoryEntry] when Passthru is enabled.
    #>
    [OutputType([DirectoryServices.DirectoryEntry])]
    [CmdletBinding(SupportsShouldProcess, DefaultParameterSetName='Path')]
    param (
        # The ObjectClass of the type to create.
        [Parameter(Mandatory, Position=0)]
        [string] $Type,

        # The type of the DistinguishedName component for this new object.
        # Should be CN or OU. Defaults to CN.
        [ValidateSet('CN', 'OU')]
        [Parameter(Position=1)]
        [string] $DistinguishedComponenentType = 'CN',

        # The name of the new entry.
        [Parameter(Mandatory, Position=2, ValueFromPipeline)]
        [string] $Name,

        # Path of the OU or container where the new object is created, in DN form.
        [Parameter()]
        [string] $Path,

        # Path of the OU or container where the new object is created, in DN
        # form *without* the DC components. Used if -Path is not provided.
        [Parameter()]
        [string] $DefaultRelativePath,

        # The domain controller to query.
        [string] $Server,

        # Credentials for the domain controller.
        [PSCredential] $Credential,

        # Should set sAM Account Name? If not set will default to a GUID.
        [Switch] $DoSAMAccountName
    )
    begin {
        $searcher = Get-LdapSearcher -Server $Server -Credential $Credential -SearchBase $Path -DefaultRelativeBase $DefaultRelativePath -Verbose:$VerbosePreference
        $baseEntry = $searcher.SearchRoot
    }
    process {
        if (-not $baseEntry.distinguishedName) {
            Write-Error "Parent container node '$(if ($Path) { $Path } else { $DefaultRelativePath })' not found."
        }

        $targetSummary = "$Type '$Name' in container '$($baseEntry.distinguishedName)'"
        if ($PSCmdlet.ShouldProcess($targetSummary)) {
            Write-Verbose "$($MyInvocation.MyCommand): $targetSummary"
            $newEntry = $baseEntry.Children.Add("$DistinguishedComponenentType=$Name", $Type)
            if ($DoSAMAccountName) {
                $existing = Get-ADObject -LDAPFilter "sAMAccountName=$Name" -Server $Server -Credential $Credential
                if (($existing | Measure-Object).Count) {
                    # objectClass contains the full class inheritance hierarchy so we only want the final, most-specific entry.
                    $existingClass = $existing.objectClass | Select-Object -Last 1
                    Write-Error "There is already an existing entry '$($existing.distinguishedName)' of type '$($existingClass)'."
                } else {
                    $newEntry.Properties['sAMAccountName'].Value = $Name
                }
            }
            $newEntry.CommitChanges();
            
            #output
            $newEntry
        }
    }
}


function Set-ADObject {
    <#
    .SYNOPSIS
        Modifies an LDAP DirectoryEntry.
    .DESCRIPTION
        Modifies an LDAP DirectoryEntry with the specified properties.
    .OUTPUTS
        [System.DirectoryServices.DirectoryEntry] when Passthru is enabled.
    #>
    [OutputType([DirectoryServices.DirectoryEntry])]
    [CmdletBinding(SupportsShouldProcess)]
    param (
        # The ObjectClass to modify.
        [Parameter(Position=0)]
        [string] $Type,

        # The identity of the LDAP DirectoryEntry to modify.
        [Parameter(Mandatory, ValueFromPipeline, Position=1)]
        [string] $Identity,

        # A hashtable of properties to set on the LDAP DirectoryEntry.
        [Parameter()]
        [hashtable] $OtherAttributes,

        # The domain controller to query.
        [Parameter()]
        [string] $Server,

        # Credentials for the domain controller.
        [Parameter()]
        [PSCredential] $Credential = $null
    )
    process {
        if ($PSCmdlet.ShouldProcess($Identity, "Modifying $Type")) {
            $entry = Get-ADObject $Type -Identity $Identity -Server $Server -Credential $Credential
            if ($OtherAttributes) {
                Set-DirectoryEntryPropertyTable $entry $OtherAttributes
                $entry.CommitChanges()
            }
            
            # output
            $entry
        }
    }
}


function Remove-ADObject {
    <#
    .SYNOPSIS
        Removes an LDAP DirectoryEntry.
    .DESCRIPTION
        Removes an LDAP DirectoryEntry by their identity.
    .OUTPUTS
        None
    #>
    [CmdletBinding(SupportsShouldProcess)]
    param (
        # The ObjectClass of the entry to modify.
        [Parameter(Position=0)]
        [string] $Type,

        # The identity of the LDAP DirectoryEntry to remove.
        [Parameter(Mandatory, ValueFromPipeline, Position=1)]
        [string] $Identity,

        # The domain controller to query.
        [Parameter()]
        [string] $Server,

        # Credentials for the domain controller.
        [Parameter()]
        [PSCredential] $Credential
    )
    process {
        if ($PSCmdlet.ShouldProcess($Identity, "Removing $Type")) {
            $entry = Get-ADObject $Type -Identity $Identity -Server $Server -Credential $Credential
            if (($entry | Measure-Object).Count -eq 1) {
                Write-Verbose "Removing $Type '$($entry.distinguishedName)'."
                $entry.DeleteTree()

            } elseif (-not $entry) {
                Write-Error "Could not find $Type '$Identity', cannot remove."
            } else {
                Write-Error "Multiple entries of type $Type found matching identity '$Identity', cannot remove."
            }
        }
    }
}


function Test-ADObject {
    <#
    .SYNOPSIS
        Tests if an LDAP DirectoryEntry exists.
    .DESCRIPTION
        Tests if an LDAP DirectoryEntry exists by their identity.
    .OUTPUTS
        [bool]
    #>
    [OutputType([bool])]
    [CmdletBinding()]
    param (
        # The ObjectClass of the entry to test.
        [Parameter(Position=0)]
        [string] $Type,

        # The identity of the LDAP DirectoryEntry to test.
        [Parameter(Mandatory, ValueFromPipeline, Position=1)]
        [string] $Identity,

        # The domain controller to query.
        [Parameter()]
        [string] $Server,

        # Credentials for the domain controller.
        [Parameter()]
        [PSCredential] $Credential = $null
    )
    process {
        $entry = Get-ADObject $Type -Identity $Identity -Server $Server -Credential $Credential
        
        # output
        $null -ne $entry
    }
}


Export-ModuleMember -Function *-ADObject