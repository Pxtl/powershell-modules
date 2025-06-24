Set-StrictMode -Version Latest
$ErrorActionPreference = [Management.Automation.ActionPreference]::Stop


function Update-DirectoryEntryFlag {
    <#
    .SYNOPSIS
        Add a boolean note property to the entry based on a bitfield value.
    .DESCRIPTION
        Editing the direct members of the entries tends to just cause
        errors, so instead we can set Note properties to expose useful
        boolean flags that are expressed internally to the properties as bit
        fields.  These Note properties will shadow the built-in properties
        that cannot be meaningfully updated and don't necessarily match
        their underlying value.
    #>
    [CmdletBinding()]
    param (
        # The entry to set a note flag upon.
        [Parameter(Mandatory, ValueFromPipelineByPropertyName)]
        [DirectoryServices.DirectoryEntry] $Entry,

        # The property name of the entry to read the note flag from.
        [Parameter(Mandatory, ValueFromPipelineByPropertyName)]
        [string] $BitFieldProperty,

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
    begin {
        [bool] $isFlagTrue = Get-DirectoryEntryFlag $Entry $BitFieldProperty $BitMask
        
        $noteValue = if ($isFlagTrue) {
            $TrueValue
        } else {
            $FalseValue
        }
        # $noteValue will only be $null if the bitmask returned false *and*
        # there was no FalseValue provided.
        if ($null -ne $noteValue) {
            $entry | Add-Member -NotePropertyName $NotePropertyName -NotePropertyValue $noteValue -Force
        }
    }
}


function Get-DirectoryEntryFlag {
    <#
    .SYNOPSIS
        Gets a bitfield flag within the properties of a given DirectoryEntry
    #>
    [OutputType([bool])]
    [CmdletBinding()]
    param (
        # The entry to set a note flag upon.
        [Parameter(Mandatory, ValueFromPipeline)]
        [DirectoryServices.DirectoryEntry] $Entry,

        # The property name of the entry to read the note flag from.
        [Parameter(Mandatory)]
        [string] $BitFieldProperty,

        # The value to bit-test against the entry property.
        [Parameter(Mandatory)]
        [int] $BitMask
    )
    process {
        # output
        [bool] ($Entry.Properties[$BitFieldProperty].Value -band $BitMask)
    }
}


function Set-DirectoryEntryFlag {
    <#
    .SYNOPSIS
        Set or clears bitfield flag within the properties of a given DirectoryEntry
    #>
    [CmdletBinding(SupportsShouldProcess)]
    param (
        # The entry to set a note flag upon.
        [Parameter(Mandatory, ValueFromPipeline)]
        [DirectoryServices.DirectoryEntry] $Entry,

        # The property name of the entry to read the note flag from.
        [Parameter(Mandatory)]
        [string] $BitFieldProperty,

        # The value to bit-test against the entry property.
        [Parameter(Mandatory)]
        [int] $BitMask,

        # Whether to set or clear the bitmask from the bitfield.
        [bool] $Value
    )
    process {
        $targetSummary = "'$($entry.DistinguishedName)' property '$BitFieldProperty' flag '$("0x" + $BitMask.ToString('X'))' to '$value'"
        Write-Verbose "$($MyInvocation.MyCommand): $targetSummary..."
        if ($PSCmdlet.ShouldProcess($targetSummary)) {
            $entry.Properties[$BitFieldProperty].Value = if ($Value) {
                # true
                $entry.Properties[$BitFieldProperty].Value -bor $BitMask
            } else {
                # false
                $entry.Properties[$BitFieldProperty].Value -band (-bnot $BitMask)
            }
        }
    }
}


function Set-DirectoryEntryPropertyTable {
    <#
    .SYNOPSIS
        Set properties of a given DirectoryEntry from the given Properties hashtable
    #>
    [CmdletBinding(SupportsShouldProcess)]
    param (
        # The entry to set a note flag upon.
        [Parameter(Mandatory, ValueFromPipeline)]
        [DirectoryServices.DirectoryEntry] $Entry,

        [Parameter(Mandatory)]
        [Hashtable] $OtherAttributes
    )
    begin {
        if ($PSCmdlet.ShouldProcess($Entry.distinguishedName)) {
            Write-Verbose "Setting properties of $Type '$($Entry.distinguishedName)"
            foreach ($key in $OtherAttributes.Keys) {
                $entry.Properties[$key].Value = $OtherAttributes[$key]
            }
        }
    }
}


Export-ModuleMember -Function *-DirectoryEntryFlag, *-DirectoryEntryPropertyTable