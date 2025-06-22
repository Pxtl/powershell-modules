Import-Module $PSScriptRoot\.. -Force

Describe 'ConvertFrom-UrlQueryString functionality' -Tags Unit {
    InModuleScope UrlQueryStringParser {
        BeforeAll {
            [Diagnostics.CodeAnalysis.SuppressMessageAttribute(
                <#Category#>'PSUseDeclaredVarsMoreThanAssignments',<#CheckId#>$null,
                Justification = 'Variable is used in It blocks, rule fails to detect'
            )]
            $complexExampleQueryString = "?foo=bar&oogy&array=one&baz=quux&array=two&boogy&array=three&empty=&array=four&last"
        }

        It 'Parses simple query string correctly' {
            $qs = '?a=1&b=two&c=3'
            $result = ConvertFrom-UrlQueryString -QueryString $qs

            $result.Count | Should -Be 3
            $result['a'] | Should -Be '1'
            $result['b'] | Should -Be 'two'
            $result['c'] | Should -Be '3'
        }

        It 'Handles URL encoded values and repeated keys' {
            $qs = 'name=John%20Doe&age=30&name=Jane'
            $result = ConvertFrom-UrlQueryString -QueryString $qs

            $result['name'].Count | Should -Be 2
            $result['name'] | Should -Contain 'John Doe'
            $result['name'] | Should -Contain 'Jane'
            $result['age'] | Should -Be '30'
        }

        It 'Returns zero-count hashtable for empty string' {
            (ConvertFrom-UrlQueryString "").Keys.Count | Should -Be 0
        }

        It 'Converts from pseudo-empty querystring (just "?") to empty dict' {
            (ConvertFrom-UrlQueryString "?").Keys.Count | Should -Be 0
        }

        It 'Converts from from simple single-entry querystring to single-entry dict' {
            (ConvertFrom-UrlQueryString "foo=bar")["foo"] | Should -Be "bar"
        }

        It 'Converts from from simple single-entry querystring with ? prefix to single-entry dict' {
            (ConvertFrom-UrlQueryString "?foo=bar")["foo"] | Should -Be "bar"
        }

        It 'Converts valueless entries with no = to $true' {
            (ConvertFrom-UrlQueryString "foo")["foo"] | Should -Be $true
        }

        It 'Converts valueless entries with = by dropping them' {
            (ConvertFrom-UrlQueryString "foo=")["foo"].Length | Should -Be 0
        }
        
        It 'Converts a complex example querystring while preserving the order of the keys' {
            $result = ConvertFrom-UrlQueryString $complexExampleQueryString
            $result.Keys -join "," | Should -Be "foo,oogy,array,baz,boogy,empty,last"
        }

        It 'Converts repeated keys into arrays while preserving value-order' {
            $result = ConvertFrom-UrlQueryString $complexExampleQueryString
            $result['array'] -join "," | Should -Be "one,two,three,four"
        }

        It 'Returns a case-insensitive dict' {
            $result = ConvertFrom-UrlQueryString $complexExampleQueryString
            { $result['ArRaY'] } | Should -Not -Throw
        }
    }
}