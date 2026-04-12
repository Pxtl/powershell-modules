Describe 'ADUser' -Tags Integration {
    BeforeAll {
        Import-Module $PSScriptRoot\ADServicesIntegrationTestModule.psm1
        Import-Module $PSScriptRoot\..\..\bin\Debug\net48\ADServices.dll
        [Diagnostics.CodeAnalysis.SuppressMessage("UseDeclaredVarsMoreThanAssignments","", Scope="member")]
        $ConnectionParam = Initialize-TestHarness
    }

    AfterAll {
        Remove-Module ADServicesIntegrationTestModule
        Remove-Module ADServices
    }

    It 'Can Enable-ADUser and Disable-ADUser by sAMAccountName' {
        $testUserName = 'disableUser1'
        New-ADUser @ConnectionParam -Name $testUserName -Verbose:$VerbosePreference
        Disable-ADAccount @ConnectionParam -Identity $testUserName -Verbose:$VerbosePreference
        $result = Get-ADUser @ConnectionParam -Identity $testUserName -Verbose:$VerbosePreference
        $result.Enabled | Should -BeFalse
        
        Enable-ADAccount @ConnectionParam -Identity $testUserName -Verbose:$VerbosePreference
        $result = Get-ADUser @ConnectionParam -Identity $testUserName -Verbose:$VerbosePreference
        $result.Enabled | Should -BeTrue
    }

    AfterEach {
        Write-Verbose "Cleanup in $($MyInvocation.MyCommand.ScriptBlock.File | Split-Path -Leaf)."
        Clear-TestObjects
    }
}