Set-StrictMode -Version Latest
$ErrorActionPreference = [Management.Automation.ActionPreference]::Stop

# Note: Everything in this file should be considered semi-deprecated.  Previous
# versions of this AD lib were more focused on mutating entries than using them
# as immutable record objects.

function Update-LDAPEntryFlag {
    <#
    .SYNOPSIS
        Add a boolean note property to the entry based on a bitfield value.
    .DESCRIPTION
        Editing the direct members of the entries is risky, so instead we can
        set Note properties to expose useful boolean flags that are expressed
        internally to the properties as bit fields.  These Note properties will
        shadow the built-in properties that cannot be meaningfully updated and
        don't necessarily match their underlying value.
    #>
    [Diagnostics.CodeAnalysis.SuppressMessage(
        'PSShouldProcess','',Scope='Function',Justification='-WhatIf passed through to Add-Member func'
    )]
    [CmdletBinding(SupportsShouldProcess)]
    param (
        # The entry to set a note flag upon.
        [Parameter(Mandatory, ValueFromPipelineByPropertyName)]
        [PSCustomObject] $Entry,

        # The property name of the entry to read the note flag from.
        [Parameter(Mandatory, ValueFromPipelineByPropertyName)]
        [string] $BitFieldLDAPProperty,

        # The value to bit-test against the entry property.
        [Parameter(Mandatory, ValueFromPipelineByPropertyName)]
        [int] $BitMask,

        # The name to set the resulting Boolean note onto the entry.
        [Parameter(Mandatory, ValueFromPipelineByPropertyName)]
        [string] $NotePropertyName,

        # What value to set on the object it the bit value is true.
        [Parameter(Mandatory, ValueFromPipelineByPropertyName)]
        [object] $TrueValue,

        # What value to set on the object it the bit value is false.  If the bit
        # value is found, nothing will be set on the object, which allows
        # multiple bit-values to contribute to a single note property.
        [Parameter(ValueFromPipelineByPropertyName)]
        [object] $FalseValue = $null
    )
    process {
        [bool] $isFlagTrue = Get-LDAPEntryFlag $Entry $BitFieldLDAPProperty $BitMask
        
        $noteValue = if ($isFlagTrue) {
            $TrueValue
        } else {
            $FalseValue
        }
        # TODO: Switch to regular property setting now that properties are all real.

        # $noteValue will only be $null if the bitmask returned false *and*
        # there was no FalseValue provided.
        if ($null -ne $noteValue) {
            $entry | Add-Member -NotePropertyName $NotePropertyName -NotePropertyValue $noteValue -Force
        }
    }
}


function Get-LDAPEntryFlag {
    <#
    .SYNOPSIS
        Gets a bitfield flag within the properties of a given directory entry
        PSCustomObject.  This operation happens offline and is not sent to the
        server until Set-ADObject is called with the explicit members to
        replace.
    #>
    [OutputType([bool])]
    [CmdletBinding()]
    param (
        # The entry to set a note flag upon.
        [Parameter(Mandatory, ValueFromPipeline)]
        [PSCustomObject] $Entry,

        # The property name of the entry to read the note flag from.
        [Parameter(Mandatory)]
        [string] $BitFieldLDAPProperty,

        # The value to bit-test against the entry property.
        [Parameter(Mandatory)]
        [int] $BitMask
    )
    process {
        $attribute = $Entry.Attributes[$BitFieldLDAPProperty]
        
        # output
        [bool] ($attribute -band $BitMask)
    }
}


function Set-LDAPEntryFlag {
    <#
    .SYNOPSIS
        Set or clears bitfield flag within the LDAP attributes of a given
        directory entry PSCustomObject.  This operation happens offline and is
        not sent to the server until Set-ADObject is called with the explicit
        members to replace.
    #>
    [CmdletBinding(SupportsShouldProcess)]
    param (
        # The entry to set a note flag upon.
        [Parameter(Mandatory, ValueFromPipeline)]
        [PSCustomObject] $Entry,

        # The property name of the entry to read the note flag from.
        [Parameter(Mandatory)]
        [string] $BitFieldLDAPProperty,

        # The value to bit-test against the entry property.
        [Parameter(Mandatory)]
        [int] $BitMask,

        # Whether to set or clear the bitmask from the bitfield.
        [bool] $Value
    )
    process {
        $targetSummary = "'$($Entry.DistinguishedName)' property '$BitFieldLDAPProperty' flag '$("0x" + $BitMask.ToString('X'))' to '$value'"
        Write-Verbose "$($MyInvocation.MyCommand): $targetSummary..."
        if ($PSCmdlet.ShouldProcess($targetSummary)) {
            $Entry.Properties[$BitFieldLDAPProperty] = if ($Value) {
                # true
                $Entry.Properties[$BitFieldLDAPProperty] -bor $BitMask
            } else {
                # false
                $Entry.Properties[$BitFieldLDAPProperty] -band (-bnot $BitMask)
            }
        }
    }
}


function Set-LDAPEntryAttributeTable {
    <#
    .SYNOPSIS
        Set properties of a given directory entry PSCustomObject from the given Properties hashtable
    #>
    [CmdletBinding(SupportsShouldProcess)]
    param (
        # The entry to set a note flag upon.
        [Parameter(Mandatory, ValueFromPipeline)]
        [PSCustomObject] $Entry,

        [Parameter(Mandatory)]
        [Hashtable] $AttributeTable
    )
    begin {
        if ($PSCmdlet.ShouldProcess($Entry.distinguishedName)) {
            # Add raw LDAP attributes as hashtable member of object.
            if ($Entry | Get-Member Attributes) {
                $Entry.PSObject.Properties.Remove('Attributes')
            }
            $Entry | Add-Member -NotePropertyName Attributes -NotePropertyValue $AttributeTable

            # A bit of backwards compatibility to DirectoryEntry, which calls
            # the attribute collection "Properties".
            if ($Entry | Get-Member Properties) {
                $Entry.PSObject.Properties.Remove('Properties')
            }
            $Entry | Add-Member -NotePropertyName Properties -NotePropertyValue $AttributeTable
        }
    }
}