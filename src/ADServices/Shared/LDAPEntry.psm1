Set-StrictMode -Version Latest
$ErrorActionPreference = [Management.Automation.ActionPreference]::Stop


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
        $commonParams = @{
            WhatIf = $WhatIfPreference
            Verbose = $VerbosePreference
        }
    }
    process {
        [bool] $isFlagTrue = Get-LDAPEntryFlag $Entry $BitFieldProperty $BitMask
        
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
        [string] $BitFieldProperty,

        # The value to bit-test against the entry property.
        [Parameter(Mandatory)]
        [int] $BitMask
    )
    process {
        # output
        $property = $Entry | Select-Object -ExpandProperty $BitFieldProperty

        [bool] ($property -band $BitMask)
    }
}


function Set-LDAPEntryFlag {
    <#
    .SYNOPSIS
        Set or clears bitfield flag within the properties of a given
        directory entry PSCustomObject.  This operation happens offline and is not sent to the
        server until Set-ADObject is called with the explicit members to
        replace.
    #>
    [CmdletBinding(SupportsShouldProcess)]
    param (
        # The entry to set a note flag upon.
        [Parameter(Mandatory, ValueFromPipeline)]
        [PSCustomObject] $Entry,

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
            $entry.$BitFieldProperty = if ($Value) {
                # true
                $entry.$BitFieldProperty -bor $BitMask
            } else {
                # false
                $entry.$BitFieldProperty -band (-bnot $BitMask)
            }
        }
    }
}


function Set-LDAPEntryPropertyTable {
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
        [Hashtable] $OtherAttributes
    )
    begin {
        if ($PSCmdlet.ShouldProcess($Entry.distinguishedName)) {
            Write-Verbose "Setting properties of $Type '$($Entry.distinguishedName)"
            foreach ($key in $OtherAttributes.Keys) {
                $entry.$key = $OtherAttributes[$key]
            }
        }
    }
}