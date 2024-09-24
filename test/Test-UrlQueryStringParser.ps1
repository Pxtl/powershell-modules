<#
.SYNOPSIS
    Tests for UrlQueryStringParser
#>
[CmdletBinding()]
param()

if ((ConvertTo-UrlQueryString @{"foo"=$true} -ContinuationOfString '') -ne '?foo') {
    throw "Continuation of empty failed."
}

if ((ConvertTo-UrlQueryString @{"foo"=$true} -ContinuationOfString '?bar=baz') -ne '?bar=baz&foo') {
    throw "Continuation of non-empty failed."
}

if ((ConvertTo-UrlQueryString @{}) -ne "") {
    throw "Empty conversion to UrlQueryString failed."
}

if ((ConvertTo-UrlQueryString @{} -ContinuationOfString '?bar=baz') -ne "?bar=baz") {
    throw "Continuation with empty failed."
}

if ((ConvertTo-UrlQueryString  @{"foo"='bar baz quux'} -SkipEncodeSpaces) -ne "?foo=bar baz quux") {
    throw "Skip encoding spaces failed."
}

if ((ConvertTo-UrlQueryString  @{"foo"='bar baz quux'}) -ne "?foo=bar%20baz%20quux") {
    throw "Encoding spaces failed."
}

$exampleOrderedDict = [ordered] @{
    foo="bar"
    oogy=$true
    array='one','two','three','four'
    baz="quux"
    boogy=$true
    empty=''
    donotshow=$false
    last=$true
}

if ((ConvertTo-UrlQueryString $exampleOrderedDict) -ne "?foo=bar&oogy&array=one&array=two&array=three&array=four&baz=quux&boogy&empty=&last") {
    throw "Deluxe test failed."
}

if ((ConvertFrom-UrlQueryString "").Keys.Count -gt 0) {
    throw "Conversion from empty querystring failed."
}

if ((ConvertFrom-UrlQueryString "?").Keys.Count -gt 0) {
    throw "Conversion from pseudo-empty querystring failed."
}

if ((ConvertFrom-UrlQueryString "foo=bar")["foo"] -ne "bar") {
    throw "Conversion from simple single-entry foo=bar failed."
}

if ((ConvertFrom-UrlQueryString "?foo=bar")["foo"] -ne "bar") {
    throw "Conversion from simple single-entry foo=bar with '?' prefix failed."
}

if ((ConvertFrom-UrlQueryString "foo")["foo"] -ne $true) {
    throw 'Valueless entries as $true failed.'
}

if ((ConvertFrom-UrlQueryString "foo=")["foo"].Length -ne 0) {
    throw 'Convert from empty-string-value querystring failed.'
}

$exampleQueryString = "?foo=bar&oogy&array=one&baz=quux&array=two&boogy&array=three&empty=&array=four&last"
$result = ConvertFrom-UrlQueryString $exampleQueryString
if (($result.Keys -join ",") -ne "foo,oogy,array,baz,boogy,empty,last") {
    throw "Order of keys not preserved converting to ordered dictionary."
}
if (($result['array'] -join ",") -ne "one,two,three,four") {
    throw "Order of array members not preserved converting to ordered dictionary."
}
if (-not $result['ArRaY']) {
    throw "Case sensitivity!"
}