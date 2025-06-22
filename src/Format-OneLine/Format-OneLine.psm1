function Format-OneLine {
    <#
    .SYNOPSIS
        Format the given object as a single-line string. 

    .DESCRIPTION
        Format the given object as a single-line string. Will recurse into
        objects up to the given depth. Special exception for PSVariables, they
        will render even at depth 0, allowing. Only outputs on pipeline-end
        because it uses a pipeline-accumulator hack. This allows you to pipe
        multiple objects into Format-OneLine and have them all output as a
        single shared line.  See example for the usefulness of these foibles WRT
        Get-Variable.

    .EXAMPLE
        ```powershell
        $foo = 'bar'; $baz = 'quux'
        Get-Variable foo, baz | Format-OneLine
        # returns "foo: bar; baz: quux"
        ```
    #>
    [OutputType([string])]
    [CmdletBinding()]
    param (
        [Parameter(ValueFromPipeline, Position = 0)]
        [object] $InputObject,

        # Depth to search to.  Note that PSVariables are still iterated at depth 0, so that a pipeline of GetVariables
        [int] $Depth = 1,

        # Include the key/value pairs for null or otherwise empty objects.
        [switch] $ShowEmpty,

        # Wrap nested HashTables/PSObjects in `{}`
        [switch] $DoBraceNestedTables
    )
    begin {
        $accumulator = [Collections.ArrayList]::new()
    }
    process {
        $accumulator.Add($InputObject) | Out-Null
    }
    end {
        $obj = if ($accumulator.Count -gt 1) {
            $accumulator
        } else {
            # unwrap single-element ArrayList.
            $accumulator | Select-Object -First 1
        }
        Format-OneLineRecursive $obj $Depth $Depth -ShowEmpty:$ShowEmpty -DoBraceNestedTables:$DoBraceNestedTables
    }
}


Export-ModuleMember -Function *


# private function below
function Format-OneLineRecursive {
    <#
    .SYNOPSIS
        Recursive internal implementation of Format-OneLine with extra needed parameter(s).
    #>
    [OutputType([string])]
    [CmdletBinding()]
    param (
        [Parameter(ValueFromPipeline, Position = 0)]
        [object] $InputObject,

        # Initial search depth.  Used to compare against current depth for DoBraceNestedTables.
        [Parameter(Position = 1)]
        [int] $StartingDepth = 1,

        # Current depth. Note that PSVariables are still iterated at depth 0, so that a pipeline of GetVariables
        [Parameter(Position = 2)]
        [int] $CurrentDepth = $StartingDepth,

        # Include the key/value pairs for null or otherwise empty objects.
        [switch] $ShowEmpty,

        # Wrap nested HashTables/PSObjects in `{}`
        [switch] $DoBraceNestedTables
    )
    begin {
        $paramTable = @{StartingDepth=$StartingDepth; ShowEmpty=$ShowEmpty; DoBraceNestedTables=$DoBraceNestedTables}
    }
    process {
        $resultList = [Collections.ArrayList]::new()
        foreach ($item in $InputObject) {
            Write-Verbose "Object '$item', CurrentDepth '$CurrentDepth',"
            # if the input object is a dictionary, convert it to a PSCustomObject so we can use its properties.
            # this is useful for converting HashTables to objects.
            if ($item -is [System.Collections.IDictionary]) {
                $item = [PSCustomObject]$item
            }

            $result = if ($null -eq $item) {
                $null
            } elseif ($item -is [Management.Automation.PSVariable] -and $CurrentDepth -ge 0) {
                "$($item.Name): $(Format-OneLineRecursive $item.Value -CurrentDepth($CurrentDepth - 1) @paramTable)"
            } elseif ($CurrentDepth -le 0) {
                # anything recursive above this line must have a depth-check to prevent infinite recursion.
                $item.ToString()
            } elseif ($item -is [Collections.IEnumerable]) {
                # if it's an IEnumerable, use its items
                ($item |
                    ForEach-Object {
                        if ($ShowEmpty -or $_) {
                            Format-OneLineRecursive $_ -CurrentDepth ($CurrentDepth - 1) @paramTable
                        }
                    }
                ) -join '; '
            } elseif ($item -is [Management.Automation.PSObject]) {
                # if it's a PSObject, use its properties
                $psObjectRendered = ($item.PSObject.Properties |
                    ForEach-Object {
                        if ($ShowEmpty -or $_.Value) {
                            "$($_.Name): $(Format-OneLineRecursive $_.Value -CurrentDepth ($CurrentDepth - 1) @paramTable)"
                        }
                    }
                ) -join '; '
                if ($DoBraceNestedTables -and $CurrentDepth -ne $StartingDepth) {
                    $psObjectRendered = "{$psObjectRendered}"
                }
                # output
                $psObjectRendered
            } else {
                # if it's not a PSObject or IDictionary, just use ToString()
                $item.ToString()
            }
            # replace excess whitespace/newlines with a single space.
            $resultList.Add(($result -replace '\s+', ' ')) | Out-Null
        }
        # Then output.
        $resultList -join '; '
    }
}