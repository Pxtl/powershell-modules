Describe 'ADGroup' -Tags Integration {
    BeforeAll {
        Import-Module $PSScriptRoot\ADServicesIntegrationTestModule.psm1
        Import-Module $PSScriptRoot\..\..\ADServices.PSModule\ADServices\ADServices.psd1 -Force
        [Diagnostics.CodeAnalysis.SuppressMessage("UseDeclaredVarsMoreThanAssignments","", Scope="member")]
        $ConnectionParam = Initialize-TestHarness
    }

    AfterAll {
        Get-Module ADServices | Remove-Module
    }

    It 'Can New-ADGroup and Get-ADGroup with the correct sAMAccountName' {
        $testGroupName = 'createGroup1'
        New-ADGroup @ConnectionParam -Name $testGroupName -Verbose:$VerbosePreference
        
        $result = Get-ADGroup @ConnectionParam -Identity $testGroupName -Verbose:$VerbosePreference
        $result.sAMAccountName | Should -Be $testGroupName
        $result.distinguishedName | Should -Be "CN=$testGroupName,CN=Users,DC=samdom,DC=example,DC=com"
    }

    It 'Returns an error when New-ADGroup with the same name twice' {
        $testGroupName = 'createGroup3'
        New-ADGroup @ConnectionParam -Name $testGroupName
        {New-ADGroup @ConnectionParam -Name $testGroupName} |
            Should -Throw
    }

    It 'Returns null when Get-ADGroup that does not exist' {
        $testGroupName = 'nonExistentGroup1'
        $result = Get-ADGroup @ConnectionParam -Identity $testGroupName
        $result | Should -BeNullOrEmpty
    }

    It 'Can Test-ADGroup and Remove-ADGroup by sAMAccountName' {
        $testGroupName = 'testGroup1'
        Test-ADGroup @ConnectionParam -Identity $testGroupName | Should -BeFalse
        New-ADGroup @ConnectionParam -Name $testGroupName
        Test-ADGroup @ConnectionParam -Identity $testGroupName | Should -BeTrue
        Remove-ADGroup @ConnectionParam -Identity $testGroupName
        Test-ADGroup @ConnectionParam -Identity $testGroupName | Should -BeFalse
    }

    AfterEach {
        Write-Verbose "Cleanup in $($MyInvocation.MyCommand.ScriptBlock.File | Split-Path -Leaf)."
        Clear-TestObjects @ConnectionParam
    }

    #TODO Test by other Identity types, Set dict, test -LDAPFilter, automate clean-up.
}