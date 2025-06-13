Import-Module $PSScriptRoot\.. -Force

Describe 'ConvertTo-UrlQueryString functionality' -Tags Unit {
    InModuleScope UrlQueryStringParser {
        It 'Converts a complex example dict correctly' {
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

            ConvertTo-UrlQueryString $exampleOrderedDict | 
                Should -Be "?foo=bar&oogy&array=one&array=two&array=three&array=four&baz=quux&boogy&empty=&last"
        }

        It 'Converts properly with empty ContinuationOfString' {
            ConvertTo-UrlQueryString @{foo=$true} -ContinuationOfString '' |
                Should -Be '?foo' 
        }

        It 'Converts properly with non-empty ContinuationOfString' {
            ConvertTo-UrlQueryString @{foo=$true} -ContinuationOfString '?bar=baz'|
                Should -Be '?bar=baz&foo'
        }
        
        It 'Converts an empty dict with non-empty -ContinuationOfString to just be -ContinuationOfString.' {
            ConvertTo-UrlQueryString @{} -ContinuationOfString '?bar=baz' |
                Should -Be "?bar=baz"
        }

        It 'Converts empty dict to empty UrlQueryString' {
            ConvertTo-UrlQueryString @{} |
                Should -Be ""
        }

        It 'Converts dict with $null values to empty UrlQueryString' {
            ConvertTo-UrlQueryString @{foo=$null;bar=$null} |
                Should -Be ""
        }

        It 'Skips encoding spaces when -DoMinimalEncode is set' {
            ConvertTo-UrlQueryString  @{foo='bar baz quux'} -DoMinimalEncode |
                Should -Be "?foo=bar baz quux"
        }

        It 'Encodes $ in keys' {
            ConvertTo-UrlQueryString  @{'$foo'='bar'} |
                Should -Be "?%24foo=bar"
        }

        It 'Skips encoding $ in keys when -DoMinimalEncode is set.' {
            ConvertTo-UrlQueryString  @{'$foo'='bar'} -DoMinimalEncode |
                Should -Be "?`$foo=bar"
        }

        It 'Encodes other various characters correctly when -DoMinimalEncode is set.' {
            ConvertTo-UrlQueryString ([ordered]@{
                allow = 'example equals= colon: at@ slash/ brackets[[] dollar$ comma, semicolon; question? parens()) star* exclaim! space space'
                disallow = "example hash# ampersand& percent% plus+ tab`t linebreak`r`n "
            }) -DoMinimalEncode |
                Should -Be (
                    '?allow=example equals= colon: at@ slash/ brackets[[] dollar$ comma, semicolon; question? parens()) star* exclaim! space space' + 
                    '&disallow=example hash%23 ampersand%26 percent%25 plus%2B tab%09 linebreak%0D%0A '
                )
        }

        It 'Encodes spaces correctly when -DoMinimalEncode is not set.' {
            ConvertTo-UrlQueryString  @{foo='bar baz quux'} |
                Should -Be "?foo=bar%20baz%20quux"
        }
    }
}