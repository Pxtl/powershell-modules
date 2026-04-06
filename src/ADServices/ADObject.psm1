Import-Module "$PSScriptRoot\Shared\ADHelpers.psm1" -Verbose:$false
Import-Module "$PSScriptRoot\ADRootDSE.psm1" -Verbose:$false
Set-StrictMode -Version Latest
$ErrorActionPreference = [Management.Automation.ActionPreference]::Stop


function Get-ADObject {
    <#
    .SYNOPSIS
        Retrieves an LDAP entry.
    .DESCRIPTION
        Retrieves an LDAP entry by their identity, which can be a
        distinguished name, GUID, SID, or sAMAccountName.  
    .OUTPUTS
        [System.PSCustomObject]
        # $null if not found.
    #>
    [OutputType([PSCustomObject])]
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

        [Parameter()]
        [scriptblock] $ObjectPropertyConverter,

        # The domain controller to query.
        [Parameter()]
        [string] $Server,

        # Credentials for the domain controller.
        [Parameter()]
        [PSCredential] $Credential
    )
    begin {
        if (-not $SearchBase) {
            $adRoot = Get-ADRootDSE -Server $Server -Credential $Credential -Verbose:$VerbosePreference
            $SearchBase = $adRoot.Properties['defaultNamingContext']
        }
        if (-not $ObjectPropertyConverter) {
            $ObjectPropertyConverter = ${function:Convert-ADObjectPropertyTable}
        }
    }
    process {
        if ($Identity) {
            $LDAPFilter = Convert-ADIdentityToFilter -Identity $Identity
        }

        if ($Type) {
            $LDAPFilter = "(&(objectClass=$Type)($LDAPFilter))"
        } else {
            $LDAPFilter = "($LDAPFilter)"
        }
        Write-Verbose "Searching for '$LDAPFilter' under '$SearchBase'..."
        $searchResult = Invoke-SearchRequest $LDAPFilter $SearchBase -Server $Server -Credential $Credential |
            ConvertFrom-LDAPSearchResponse -ObjectPropertyConverter $ObjectPropertyConverter

        if ($Identity) {
            $resultCount = $searchResult | Measure-Object | Select-Object -ExpandProperty Count
            if ($resultCount -gt 1) {
                throw [InvalidOperationException]::new("Request for identity value '$Identity' returned multiple values of class '$Type', which isn't supposed to be possible.")
            }
        }

        # output
        $searchResult
    }
}


function New-ADObject {
    <#
    .SYNOPSIS
        Creates a new LDAP entry.
    .DESCRIPTION
        Creates a new LDAP entry with the specified name.
    .OUTPUTS
        [PSCustomObject] when PassThru is enabled.
    #>
    [OutputType([PSCustomObject])]
    [CmdletBinding(SupportsShouldProcess, DefaultParameterSetName='Path')]
    param (
        # The ObjectClass of the type to create.
        [Parameter(Mandatory, Position=0)]
        [string] $Type,

        # The type of the DistinguishedName component for this new object.
        # Should be CN or OU. Defaults to CN.
        [ValidateSet('CN', 'OU')]
        [Parameter(Position=1)]
        [string] $DistinguishedComponentType = 'CN',

        # The name of the new entry.
        [Parameter(Mandatory, Position=2, ValueFromPipeline)]
        [string] $Name,

        # LDAP displayName-based (not object property names - "mail" not
        # "EmailAddress") hashtable for values on the new object.
        [Parameter()]
        [hashtable] $OtherAttributes,

        # Path of the OU or container where the new object is created, in DN form.
        [Parameter()]
        [string] $Path,

        # Path of the OU or container where the new object is created, in DN
        # form *without* the DC components. Used if -Path is not provided.
        [Parameter()]
        [string] $DefaultRelativePath,

        [Parameter()]
        [scriptblock] $ObjectPropertyConverter,

        # The domain controller to query.
        [Parameter()]
        [string] $Server,

        # Credentials for the domain controller.
        [Parameter()]
        [PSCredential] $Credential,

        # Should set sAM Account Name? If not set will default to a GUID.
        [Switch] $DoSAMAccountName,

        # Returns an object representing the item with which you are working. By
        # default, this cmdlet does not generate any output.
        [Switch] $PassThru
    )
    begin {
        if (-not $Path) {
            # if Path is not provided, fetch the Root DSE so the DefaultRelativePath can be tacked-on. 
            $adRootDSE = Get-ADRootDSE -Server $Server -Credential $Credential
            $Path = $adRootDSE.Properties['defaultNamingContext']
            if ($DefaultRelativePath) {
                $Path = "$DefaultRelativePath,$Path"
            }
        }
        
        $OtherAttributes = if ($OtherAttributes) {
            $OtherAttributes.Clone()
        } else {
            @{}
        }

        if (-not (Test-ADObject -Identity $Path -Server $Server -Credential $Credential)) {
            Write-Error "Parent container node '$(if ($Path) { $Path } else { $DefaultRelativePath })' not found."
        }
        if (-not $ObjectPropertyConverter) {
            $ObjectPropertyConverter = ${function:Convert-ADObjectPropertyTable}
        }
    }
    process {
        $targetSummary = "$Type '$Name' in container '$Path'"
        if ($PSCmdlet.ShouldProcess($targetSummary)) {
            Write-Verbose "$($MyInvocation.MyCommand): $targetSummary"           

            if ($DoSAMAccountName) {
                $existing = Get-ADObject -LDAPFilter "sAMAccountName=$Name" -ObjectPropertyConverter $ObjectPropertyConverter -Server $Server -Credential $Credential
                if (($existing | Measure-Object).Count) {
                    # objectClass contains the full class inheritance hierarchy so we only want the final, most-specific entry.
                    $existingClass = $existing.objectClass | Select-Object -Last 1
                    Write-Error "There is already an existing entry '$($existing.distinguishedName)' of type '$($existingClass)'."
                }
                $OtherAttributes['sAMAccountName'] = $Name
            }

            $newDistinguishedName = "$DistinguishedComponentType=$Name,$Path"
            $request = [DirectoryServices.Protocols.AddRequest]::new($newDistinguishedName, $Type)
            foreach ($attrPair in $OtherAttributes.GetEnumerator()) {
                $request.Attributes.Add([DirectoryServices.Protocols.DirectoryAttribute]::new($attrPair.Key, $attrPair.Value)) | Out-Null
            }
            $ldapConnection = New-LDAPConnection $Server $Credential
            $ldapConnection.SendRequest($request) | Out-Null

            if ($PassThru) {
                # output
                Get-ADObject -Type $Type -Identity $newDistinguishedName -ObjectPropertyConverter $ObjectPropertyConverter -Server $Server -Credential $Credential
            }
        }
    }
}


function Set-ADObject {
    <#
    .SYNOPSIS
        Modifies an LDAP entry on the server.
    .DESCRIPTION
        Modifies an LDAP entry on the server with the specified attributes.
        Does not update the local client version.
    .OUTPUTS
        [System.PSCustomObject] when PassThru is enabled.
    #>
    [OutputType([PSCustomObject])]
    [CmdletBinding(SupportsShouldProcess)]
    param (
        # The ObjectClass to modify.
        [Parameter(Position=0)]
        [string] $Type,

        # The identity of the LDAP entry to modify.
        [Parameter(Mandatory, ValueFromPipeline, Position=1)]
        [string] $Identity,

        # ObjectPropertyConverter, mostly important when running in PassThru
        # mode since PassThru for this object redownloads the object.
        [Parameter()]
        [scriptblock] $ObjectPropertyConverter,

        # A hashtable of LDAP attributes to add on the LDAP entry.
        [Parameter()]
        [hashtable] $Add,

        # A hashtable of LDAP attributes to remove from the LDAP entry.
        [Parameter()]
        [hashtable] $Remove,

        # A hashtable of LDAP attributes to replace on the LDAP entry.
        [Parameter()]
        [hashtable] $Replace,

        # The domain controller to query.
        [Parameter()]
        [string] $Server,

        # Credentials for the domain controller.
        [Parameter()]
        [PSCredential] $Credential = $null,

        # Returns an object representing the item with which you are working. By
        # default, this cmdlet does not generate any output.
        [switch] $PassThru
    )
    process {
        $entry = Get-ADObject $Type -Identity $Identity -ObjectPropertyConverter $ObjectPropertyConverter  -Server $Server -Credential $Credential
        if (($entry | Measure-Object).Count -eq 1) {
            if ($PSCmdlet.ShouldProcess($Identity, "Modifying $Type '$($entry.DistinguishedName)'")) {
                Write-Verbose "Modifying $Type '$($entry.DistinguishedName)'."
                $attributeModifications = [Collections.ArrayList]::new()

                if ($Add) {
                    foreach ($attribute in $Add.GetEnumerator()) {
                        Add-DirectoryAttributeModification -AttributeModificationList $attributeModifications -Operation Add -Name $attribute.Key -Value $attribute.Value
                    }
                }

                if ($Remove) {
                    foreach ($attribute in $Remove.GetEnumerator()) {
                        Add-DirectoryAttributeModification -AttributeModificationList $attributeModifications -Operation Delete -Name $attribute.Key -Value $attribute.Value
                    }
                }

                if ($Replace) {
                    foreach ($attribute in $Replace.GetEnumerator()) {
                        Add-DirectoryAttributeModification -AttributeModificationList $attributeModifications -Operation Replace -Name $attribute.Key -Value $attribute.Value
                    }
                }

                $modifyRequest = [DirectoryServices.Protocols.ModifyRequest]::new(
                    $entry.DistinguishedName,
                    $attributeModifications
                )

                $ldapConnection = New-LDAPConnection $Server $Credential
                $ldapConnection.SendRequest($modifyRequest) | Out-Null

                if ($PassThru) {
                    # output
                    Get-ADObject $Type -Identity $Identity -ObjectPropertyConverter $ObjectPropertyConverter -Server $Server -Credential $Credential
                }
            }
        } elseif (-not $entry) {
            Write-Error "Could not find $Type '$Identity', cannot remove."
        } else {
            Write-Error "Multiple entries of type $Type found matching identity '$Identity', cannot remove."
        }
    }
}


function Remove-ADObject {
    <#
    .SYNOPSIS
        Removes an LDAP entry.
    .DESCRIPTION
        Removes an LDAP entry by their identity.
    .OUTPUTS
        None
    #>
    [CmdletBinding(SupportsShouldProcess)]
    param (
        # The ObjectClass of the entry to modify.
        [Parameter(Position=0)]
        [string] $Type,

        # The identity of the LDAP entry to remove.
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
                $ldapConnection = New-LDAPConnection $Server $Credential

                $deleteRequest = [DirectoryServices.Protocols.DeleteRequest]::new(
                    $entry.distinguishedName
                )

                $ldapConnection.SendRequest($deleteRequest) | Out-Null

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
        Tests if an LDAP entry exists.
    .DESCRIPTION
        Tests if an LDAP entry exists by their identity.
    .OUTPUTS
        [bool]
    #>
    [OutputType([bool])]
    [CmdletBinding()]
    param (
        # The ObjectClass of the entry to test.
        [Parameter(Position=0)]
        [string] $Type,

        # The identity of the LDAP entry to test.
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


function Set-ADObjectEntry {
    <#
    .SYNOPSIS
        Merge in changes to an ADObjectEntry's LDAP Attribute table.  This allows a client
    #>
    [CmdletBinding(SupportsShouldProcess)]
    param (
        # The object whose attributes collection must be modified
        [Parameter(ValueFromPipeline)]
        [PSCustomObject] $Entry,
        
        # A hashtable of LDAP attributes to add on the LDAP entry.
        [Parameter()]
        [hashtable] $Add,

        # A hashtable of LDAP attributes to remove from the LDAP entry.
        [Parameter()]
        [hashtable] $Remove,

        # A hashtable of LDAP attributes to replace on the LDAP entry.
        [Parameter()]
        [hashtable] $Replace
    )
    process {
        if ($PSCmdlet.ShouldProcess([string] $Entry)) {
            if ($Add) {
                foreach ($attrPair in $Add.GetEnumerator()) {
                    # See https://ldap.com/the-ldap-modify-operation/ to
                    # understand the semantics. TODO: Technically values are
                    # supposed to be unique within the attribute but we don't
                    # check for that.  
                    $existingVal = $Entry.Attributes[$attrPair.Key]
                    $existingValCount = ($existingVal | Measure-Object).Count
                    if ($existingValCount -gt 1) {
                        $Entry.Attributes[$attrPair.Key] += $attrPair.Value
                    } elseif ($existingValCount -eq 1) {
                        $Entry.Attributes[$attrPair.Key] = ,$existingVal + $attrPair.Value
                    } else { # empty
                        $Entry.Attributes[$attrPair.Key] = $attrPair.Value
                    }
                }
            }

            if ($Remove) {
                foreach ($attrPair in $Remove.GetEnumerator()) {
                    # See https://ldap.com/the-ldap-modify-operation/ to
                    # understand the semantics of the LDAP "Delete" operation,
                    # which we call "Remove"
                    if ($attrPair.Value) {
                        # where the Delete modification has a Value, we treat
                        # the Attribute as an array an filter out that value.
                        $Entry.Attributes[$attrPair.Key] = $Entry.Attributes[$attrPair.Key] | Where-Object {
                            $_ -ne $attrPair.Value
                        }
                    } else {
                        # where the LDAP Delete modification is empty, we remove the
                        # whole Attribute.
                        $Entry.Attributes.Remove($attrPair.Key)
                    }
                }
            }

            if ($Replace) {
                foreach ($attrPair in $Replace.GetEnumerator()) {
                    $Entry.Attributes[$attrPair.Key] = $attrPair.Value
                }
            }
        }
    }
}


function Update-ADObjectEntry {
    <#
    .SYNOPSIS
        Update the ADObject's properties from its LDAP Attributes
    #>
    [Diagnostics.CodeAnalysis.SuppressMessage(
        'PSShouldProcess','',Scope='Function',Justification='-WhatIf passed through to helper funcs'
    )]
    [CmdletBinding(SupportsShouldProcess)]
    param (
        [Parameter(ValueFromPipeline)]
        [PSCustomObject] $Entry,

        [Parameter()]
        [scriptblock] $ObjectPropertyConverter
    )
    begin {
        if (-not $ObjectPropertyConverter) {
            $ObjectPropertyConverter = ${function:Convert-ADObjectPropertyTable}
        }
        $commonParams = @{
            WhatIf = $WhatIfPreference
            Verbose = $VerbosePreference
        }
    }
    process {
        # Convert the current LDAP Attributes hashtable into Object Properties hashtable
        $objectPropertyTable = Invoke-Command $ObjectPropertyConverter -ArgumentList @($Entry.Attributes)

        # apply the resulting Object Properties Table to the given object's properties
        Set-Object $entry -PropertyTable $objectPropertyTable @commonParams
    }
}