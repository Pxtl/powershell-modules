function ConvertTo-UrlQueryString {
    <#
    .SYNOPSIS
        Convert the given IDictionary/hashtable into an URL query-string starting with '?'
    .OUTPUTS
        An URL query-string starting with '?'
    #>
    [OutputType([string])]
    [CmdletBinding()]
    param (
        # A dictionary containing key/value pairs. Use OrderedDictionary to preserve order of creation. Values will
        # be converted to strings. $null or $false values will be left out of the query string. Values equal to
        # $true will be stored as valueless entries in the query-string.
        [Parameter(ValueFromPipeline)]
        [Collections.IDictionary] $Members,

        # A previous QueryString that this is continuing. If it's non-empty, then the beginning separator will be
        # '&' instead of '?'
        [Parameter()]
        [string] $ContinuationOfString,
        
        # Only encode characters that *must* be encoded instead of using standard encode..
        [Alias('SkipEncodeSpaces')]
        [switch] $DoMinimalEncode
    )
    process {
        [string] $result = "" + $ContinuationOfString
        $hasContent = $Members.Keys |
            Where-Object { Test-UrlQueryStringValueIsWriteable $Members[$_]} |
            Foreach-Object { $true } |
            Select-Object -First 1

        if ($hasContent) {
            $result += if (-not $ContinuationOfString) {"?"}
        }
        foreach($key in $Members.Keys) {
            $key = [uri]::EscapeDataString($key.ToString())
            $foundValue = $Members[$key]
            
            # Truthy values (or, as a special-case, empty string '') are included in the dict.
            #
            # Note: -eq is NOT commutitive here, $false -eq '' but '' -ne $false.  The only falsey object we want
            # is empty strings, and other forms of this code will include that.
            if (Test-UrlQueryStringValueIsWriteable $foundValue) {
                $valueArray = @($foundValue)
                if($value -is [array]) {
                    $valueArray = $foundValue
                }
                $field = if ($DoMinimalEncode) {
                    $key | Format-UrlComponent -AsField
                } else {
                    $key | Format-UrlComponent
                }

                foreach ($value in $valueArray) {
                    if($result.Length -gt 1) {
                        $result += "&"
                    }

                    if ($value -eq $true) {
                        $result += $field
                    } else {
                        $value = if ($DoMinimalEncode) {
                            $value | Format-UrlComponent -AsValue
                        } else {
                            $value | Format-UrlComponent
                        }
                        $result += "$field=$value"
                    }
                }
            }
        }
        # return
        $result
    }
}

function ConvertFrom-UrlQueryString {
    <#
    .SYNOPSIS
        Takes the given URL query string (optionally starts with "?") and converts it into a Powershell object
        (OrderedDictionary). Valueless query members (?field1&field2) will be included as $true. Empty query members
        (?field1=&field2) will be included as empty-string ''.
    #>
    [OutputType([Collections.Specialized.OrderedDictionary])]
    [CmdletBinding()]
    param (
        # URL query string (optionally starts with "?")
        [Parameter(ValueFromPipeline)]
        [string] $QueryString
    )
    process {
        $result = [ordered] @{}
        if ($QueryString) {
            if ($QueryString -like '`?*') {
                $QueryString = $QueryString.Substring(1, $QueryString.Length - 1)
            }
            $queryEntries = $QueryString -split "&"
            foreach($entry in $queryEntries) {
                if ($entry -like '*=*') {
                    $equalsCharIndex = $entry.IndexOf("=")
                    $field = $entry.Substring(0, $equalsCharIndex)
                    $field = [uri]::UnescapeDataString($field)
                    $value = $entry.Substring($equalsCharIndex + 1, $entry.Length - $equalsCharIndex - 1)
                    $value = [uri]::UnescapeDataString($value)
                    $existingValue = $result[$field]
                    if ($existingValue) {
                        # store as array (foreach flattens array)
                        $result[$field] = ($existingValue, $value | ForEach-Object {$_})
                    } else {
                        $result[$field] = $value
                    }
                } elseif ($entry) {
                    $entry = [uri]::UnescapeDataString($entry)
                    $result[$entry] = $true
                }
            }
        }

        # return
        $result
    }
}


function Format-UrlComponent {
    <#
    .SYNOPSIS
        Format the given string as a URL component. If used in "standard" mode it will apply the default encoding,
        but in all other cases it will attempt the minimum encoding, including undoing the encoding of characters
        that browsers are flexible about for readability.
    #>
    [CmdletBinding(DefaultParameterSetName = "AsStandard")]
    param (
        [Parameter(ValueFromPipeline)]
        [string] $InputObject,

        [Parameter(ParameterSetName = "AsCommon")]
        [switch] $AsCommon,

        [Parameter(ParameterSetName = "AsPath")]
        [switch] $AsPath,

        [Parameter(ParameterSetName = "AsField")]
        [switch] $AsField,

        [Parameter(ParameterSetName = "AsValue")]
        [switch] $AsValue
    )
    process {
        $InputObject = [uri]::EscapeDataString($InputObject.ToString())
        $replacements = $null
        $regex = $null
        
        if ($AsCommon) {
            $replacements = $urlCommonDecodes
            $regex = $urlCommonDecodesRegex
        } elseif ($AsPath) {
            $replacements = $urlPathComponentDecodes
            $regex = $urlPathComponentDecodesRegex
        } elseif ($AsField) {
            $replacements = $urlQueryStringFieldComponentDecodes
            $regex = $urlQueryStringFieldComponentDecodesRegex
        } elseif ($AsValue) {
            $replacements = $urlQueryStringValueComponentDecodes
            $regex = $urlQueryStringValueComponentDecodesRegex
        }

        if ($regex) {
            $InputObject = Format-StringWithHashtable $InputObject -Replacements $replacements -Regex $regex
        }

        # return
        $InputObject
    }
}

Export-ModuleMember -Function * -Alias *

#region private objects

function Test-UrlQueryStringValueIsWriteable {
    <#
    .SYNOPSIS
        Test if the given value is writeable as a query-string value.
    #>
    [CmdletBinding()]
    param(
        # The value to test. Can't use [string] here because that converts $null into ''
        [Parameter(ValueFromPipeline)]
        [object] $InputObject
    )
    process {
        #return 
        '' -eq $InputObject -or $InputObject
    }
}


function ConvertTo-RegularExpression {
    <#
    .SYNOPSIS
        Convert a hashtable's keys to a regular expression suitable for Format-StringWithHashtable
    #>
    [OutputType([Text.RegularExpressions.Regex])]
    [CmdletBinding()]
    param(
        [Parameter(ValueFromPipeline)]
        [hashtable] $Replacements
    )
    process {
        $regexString = [string]::Join("|", 
            ($Replacements.Keys | ForEach-Object {[Text.RegularExpressions.Regex]::Escape($_)})
        )

        # return
        [Text.RegularExpressions.Regex]::new($regexString, 
            [Text.RegularExpressions.RegexOptions]::Compiled -bor [Text.RegularExpressions.RegexOptions]::IgnoreCase
        )
    }
}


# the following decodes are usable by all parts of the URL that we care about (everything but the scheme and authority)
$urlCommonDecodes = @{
    '%2F' = '/'
    '%20' = ' '
    '%40' = '@'
    '%5B' = '['
    '%5D' = ']'
    '%24' = '$'
    '%2C' = ','
    '%3B' = ';'
}
$urlCommonDecodesRegex = ConvertTo-RegularExpression $urlCommonDecodes

$urlPathComponentDecodes = $urlCommonDecodes + @{
    '%3D' = '='
}
$urlPathComponentDecodesRegex = ConvertTo-RegularExpression $urlPathComponentDecodes

$urlQueryStringFieldComponentDecodes = $urlCommonDecodes + @{
    '%3A' = ':'
    '%3F' = '?'
}
$urlQueryStringFieldComponentDecodesRegex = ConvertTo-RegularExpression $urlQueryStringFieldComponentDecodes

# characters that do not appear to be invalid in a QueryString
# [example](https://www.google.com/search?query=example+colon:at@+slash/+brackets[[]+dollar$+comma,+semicolon;+question?+space space)
$urlQueryStringValueComponentDecodes = $urlQueryStringFieldComponentDecodes + @{
    '%3D' = '='
}
$urlQueryStringValueComponentDecodesRegex = ConvertTo-RegularExpression $urlQueryStringValueComponentDecodes


function Format-StringWithHashtable {
    <#
    .SYNOPSIS
        Takes the given string and a hashtable and replaces all instances of the table keys within that string with
        the corresponding table values.  Uses regular expressions, so for optimization purposes the pre-compiled
        regular expression can be provided as -Regex.  That regex should be generated by
        `ConvertTo-RegularExpression $myReplacementsTable`.
    #>
    [OutputType([string])]
    [CmdletBinding()]
    param(
        [Parameter(ValueFromPipeline)]
        [string] $InputObject,

        [Parameter(Mandatory)]
        [hashtable] $Replacements,
        
        # must be generated from -Replacements using ConvertTo-RegularExpression.  If not provided it will be
        # created at run-time but this may be less-efficient.
        [Parameter()]
        [Text.RegularExpressions.Regex]
        $Regex = $null
    )
    begin {
        if (-not $Regex) {
            $Regex = ConvertTo-RegularExpression $Replacements
        }
    }
    process {
        $matchEvaluator = {
            param([Text.RegularExpressions.Match] $match)
            $Replacements[$match.Value]
        }

        # return
        $Regex.Replace($InputObject, $matchEvaluator)
    }
}

#endregion