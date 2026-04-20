Describe 'ADUser' -Tags Integration {
    BeforeAll {
        Import-Module $PSScriptRoot/ADServicesIntegrationTestModule.psm1
        Import-Module $PSScriptRoot/../../ADServices.PSModule/ADServices/ADServices.psd1 -Force
        [Diagnostics.CodeAnalysis.SuppressMessage("UseDeclaredVarsMoreThanAssignments","", Scope="member")]
        $ConnectionParam = Initialize-TestHarness
    }

    AfterAll {
        Get-Module ADServices | Remove-Module
    }

    It 'Can New-ADUser and Get-ADUser with the correct sAMAccountName' {
        $testUserName = 'createUser1'
        New-ADUser @ConnectionParam -Name $testUserName -Verbose:$VerbosePreference
        
        $result = Get-ADUser @ConnectionParam -Identity $testUserName -Verbose:$VerbosePreference
        $result.sAMAccountName | Should -Be $testUserName
        $result.distinguishedName | Should -Be "CN=$testUserName,CN=Users,DC=samdom,DC=example,DC=com"
    }

    It 'Can New-ADUser in an alternate path' {
        $testUserName = 'createUser2'
        $parentPath = 'OU=Subdir,OU=Alternate\ Users,DC=samdom,DC=example,DC=com'
        $expectedDistinguishedName = "CN=$testUserName,OU=Subdir,OU=Alternate Users,DC=samdom,DC=example,DC=com"
        New-ADOrganizationalUnit @ConnectionParam -Name 'Alternate Users'
        New-ADOrganizationalUnit @ConnectionParam -Name 'Subdir' -Path 'OU=Alternate\ Users,DC=samdom,DC=example,DC=com'
        New-ADUser @ConnectionParam -Name $testUserName -Path $parentPath
        
        $result = Get-ADUser @ConnectionParam -Identity $expectedDistinguishedName
        $result.distinguishedName | Should -Be $expectedDistinguishedName
    }

    It 'Returns an error when New-ADUser with the same name twice' {
        $testUserName = 'createUser3'
        New-ADUser @ConnectionParam -Name $testUserName
        {New-ADUser @ConnectionParam -Name $testUserName} |
            Should -Throw
    }

    It 'Returns null when Get-ADUser that does not exist' {
        $testUserName = 'nonExistentUser1'
        $result = Get-ADUser @ConnectionParam -Identity $testUserName
        $result | Should -BeNullOrEmpty
    }

    It 'Can Test-ADUser and Remove-ADUser by sAMAccountName' {
        $testUserName = 'testUser1'
        Test-ADUser @ConnectionParam -Identity $testUserName | Should -BeFalse
        New-ADUser @ConnectionParam -Name $testUserName
        Test-ADUser @ConnectionParam -Identity $testUserName | Should -BeTrue
        Remove-ADUser @ConnectionParam -Identity $testUserName
        Test-ADUser @ConnectionParam -Identity $testUserName | Should -BeFalse
    }

    AfterEach {
        Write-Verbose "Cleanup in $($MyInvocation.MyCommand.ScriptBlock.File | Split-Path -Leaf)."
        Clear-TestObjects @ConnectionParam
    }

    #TODO Test by other Identity types, Set dict, test -LDAPFilter, automate clean-up.
}