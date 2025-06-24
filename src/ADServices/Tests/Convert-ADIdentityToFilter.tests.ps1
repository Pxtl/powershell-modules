# Load the function (adjust path if needed)
Import-Module "$PSScriptRoot\..\Shared\ADHelpers.psm1" -Force

Describe 'Convert-ADIdentityToFilter' {

    It 'Returns filter for SAMAccountName' {
        $result = Convert-ADIdentityToFilter -Identity 'jdoe'
        $result | Should -Be '(samAccountName=jdoe)'
    }

    It 'Returns filter for objectGUID' {
        $guid = [guid]::NewGuid().ToString()
        $result = Convert-ADIdentityToFilter -Identity $guid
        $expected = "(objectGUID=$guid)"
        $result | Should -Be $expected
    }

    It 'Returns filter for SID' {
        $sid = 'S-1-5-21-3623811015-3361044348-30300820-1013'
        $result = Convert-ADIdentityToFilter -Identity $sid
        $expected = "(objectSID=$sid)"
        $result | Should -Be $expected
    }

    It 'Returns filter for Distinguished Name' {
        $dn = 'CN=John Doe,OU=Users,DC=example,DC=com'
        $result = Convert-ADIdentityToFilter -Identity $dn
        $expected = "(distinguishedName=$dn)"
        $result | Should -Be $expected
    }

    It 'Throws on invalid input' {
        { Convert-ADIdentityToFilter -Identity '' } | Should -Throw
    }
}