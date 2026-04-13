Describe 'ADOrganizationalUnit' -Tags Integration {
    BeforeAll {
        Import-Module $PSScriptRoot\ADServicesIntegrationTestModule.psm1
        Import-Module $PSScriptRoot\..\..\ADServices.psd1
        [Diagnostics.CodeAnalysis.SuppressMessage("UseDeclaredVarsMoreThanAssignments","", Scope="member")]
        $global:ConnectionParam = Initialize-TestHarness
    }

    It 'Can New-ADOrganizationalUnit in an alternate path' {
        $testOrganizationalUnitName = 'createOrganizationalUnit2'
        $parentPath = 'OU=Subdir,OU=Alternate\ OrganizationalUnits,DC=samdom,DC=example,DC=com'
        $distinguishedName = "OU=$testOrganizationalUnitName,$parentPath"
        $expectedDistinguishedName = $distinguishedName -replace '\\', ''
        New-ADOrganizationalUnit @ConnectionParam -Name 'Alternate OrganizationalUnits'
        New-ADOrganizationalUnit @ConnectionParam -Name 'Subdir' -Path 'OU=Alternate\ OrganizationalUnits,DC=samdom,DC=example,DC=com'
        New-ADOrganizationalUnit @ConnectionParam -Name $testOrganizationalUnitName -Path $parentPath
        
        $result = Get-ADOrganizationalUnit @ConnectionParam -Identity $distinguishedName
        $result.distinguishedName | Should -Be $expectedDistinguishedName
    }

    It 'Returns an error when New-ADOrganizationalUnit with the same name twice' {
        $testOrganizationalUnitName = 'createOrganizationalUnit3'
        New-ADOrganizationalUnit @ConnectionParam -Name $testOrganizationalUnitName
        {New-ADOrganizationalUnit @ConnectionParam -Name $testOrganizationalUnitName} |
            Should -Throw
    }

    It 'Returns null when Get-ADOrganizationalUnit that does not exist' {
        $testOrganizationalUnitName = 'nonExistentOrganizationalUnit1'
        $result = Get-ADOrganizationalUnit @ConnectionParam -Identity $testOrganizationalUnitName
        $result | Should -BeNullOrEmpty
    }

    It 'Can Test-ADOrganizationalUnit and Remove-ADOrganizationalUnit by distinguishedName' {
        $testOrganizationalUnitName = 'testOrganizationalUnit1'
        $testOrganizationalUnitDistinguishedName = 'OU=testOrganizationalUnit1,DC=samdom,DC=example,DC=com'
        Test-ADOrganizationalUnit @ConnectionParam -Identity $testOrganizationalUnitDistinguishedName | Should -BeFalse
        New-ADOrganizationalUnit @ConnectionParam -Name $testOrganizationalUnitName
        Test-ADOrganizationalUnit @ConnectionParam -Identity $testOrganizationalUnitDistinguishedName | Should -BeTrue
        Remove-ADOrganizationalUnit @ConnectionParam -Identity $testOrganizationalUnitDistinguishedName
        Test-ADOrganizationalUnit @ConnectionParam -Identity $testOrganizationalUnitDistinguishedName | Should -BeFalse
    }

    AfterEach {
        Write-Verbose "Cleanup in $($MyInvocation.MyCommand.ScriptBlock.File | Split-Path -Leaf)."
        Clear-TestObjects @ConnectionParam
    }
}