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
        
        # Leave the space-characters as space characters, which some browsers support.
        [switch] $SkipEncodeSpaces
    )
    process {
        [string] $result = "" + $ContinuationOfString
        if ($Members.Keys -and $Members.Keys.Count) {
            $result += if (-not $ContinuationOfString) {"?"}
        }
        foreach($key in $Members.Keys) {
            $key = [uri]::EscapeDataString($key.ToString())
            $foundValue = $Members[$key]
            
            # Truthy values (or, as a special-case, empty string '') are included in the dict.
            #
            # Note: -eq is NOT commutitive here, $false -eq '' but '' -ne $false.  The only falsey object we want
            # is empty strings, and other forms of this code will include that.
            if ('' -eq $foundValue  -or $foundValue) {
                $valueArray = @($foundValue)
                if($value -is [array]) {
                    $valueArray = $foundValue
                }
                foreach ($value in $valueArray) {
                    $value = [uri]::EscapeDataString($value.ToString())
                    if ($SkipEncodeSpaces) {
                        # only want to urlencode chars that aren't spaces in value.
                        $value = $value -replace '%20', ' '
                    }
                    if($result.Length -gt 1) {
                        $result += "&"
                    }
                    if ($value -eq $true) {
                        $result += $key
                    } else {
                        $result += "$key=$value"
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
        (OrderedDictionary). Valueless query members (?key1&key2) will be included as $true. Empty query members
        (?key1=&key2) will be included as empty-string ''.
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
                    $key = $entry.Substring(0, $equalsCharIndex)
                    $key = [uri]::UnescapeDataString($key)
                    $value = $entry.Substring($equalsCharIndex + 1, $entry.Length - $equalsCharIndex - 1)
                    $value = [uri]::UnescapeDataString($value)
                    $existingValue = $result[$key]
                    if ($existingValue) {
                        # store as array (foreach flattens array)
                        $result[$key] = ($existingValue, $value | ForEach-Object {$_})
                    } else {
                        $result[$key] = $value
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

Export-ModuleMember -Function * -Alias *