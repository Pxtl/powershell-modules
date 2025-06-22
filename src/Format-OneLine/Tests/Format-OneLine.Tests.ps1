Import-Module $PSScriptRoot\.. -Force
# Full disclosure: This test-suite was produced with the assistance of ChatGPT4
# on 2025-06-22, using the prompt "I have a powershell function I want pester
# tests for.  Can you help me with those?  Here's the headers of the function."
# and the text of the help-comments and param block of Format-OneLine.


Describe 'Format-OneLine' {

    Context 'Basic variable formatting' {
        It 'Formats single variable as "name: value"' {
            $var = 'value'
            $result = Get-Variable var | Format-OneLine
            $result | Should -Be 'var: value'
        }

        It 'Formats multiple variables as "name: value; name2: value2"' {
            $foo = 'bar'; $baz = 'quux'
            $result = Get-Variable foo, baz | Format-OneLine
            $result | Should -Be 'foo: bar; baz: quux'
        }
    }

    Context 'Depth parameter behavior' {
        It 'Shows nested objects up to the specified depth' {
            $obj = [PSCustomObject]@{
                Key = [PSCustomObject]@{ SubKey = 'value' }
            }
            $result = $obj | Format-OneLine -Depth 2
            $result | Should -Match 'SubKey: value'
        }

        It 'Does not show nested keys if depth is too shallow' {
            $obj = [PSCustomObject]@{
                Key = [PSCustomObject]@{ SubKey = 'value' }
            }
            $result = $obj | Format-OneLine -Depth 1
            $result | Should -Not -Match 'SubKey'
        }
    }

    Context 'ShowEmpty switch' {
        It 'Includes empty objects if ShowEmpty is set' {
            $obj = [PSCustomObject]@{ Empty = $null }
            $result = $obj | Format-OneLine -ShowEmpty
            $result | Should -Match 'Empty'
        }

        It 'Omits empty objects if ShowEmpty is not set' {
            $obj = [PSCustomObject]@{ Empty = $null }
            $result = $obj | Format-OneLine
            $result | Should -Not -Match 'Empty'
        }
    }

    Context 'DoBraceNestedTables switch' {
        It 'Wraps nested objects in braces when enabled' {
            $obj = [PSCustomObject]@{
                Info = @{ Nested = 'val' }
            }
            $result = $obj | Format-OneLine -DoBraceNestedTables -Depth 2
            $result | Should -Match 'Info: {Nested: val}'
        }

        It 'Does not wrap nested objects in braces when disabled' {
            $obj = [PSCustomObject]@{
                Info = @{ Nested = 'val' }
            }
            $result = $obj | Format-OneLine -Depth 2
            $result | Should -Not -Match '{Nested: val}'
        }
    }

    Context 'Pipeline behavior' {
        It 'Combines multiple inputs into one line' {
            $a = [PSCustomObject]@{ A = 1 }
            $b = [PSCustomObject]@{ B = 2 }
            $result = @($a, $b) | Format-OneLine
            $result | Should -Be 'A: 1; B: 2'
        }
    }
}