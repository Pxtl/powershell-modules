[CmdletBinding()]
param (
    [Parameter()]
    [string] $Server,
    
    [Parameter(Mandatory)]
    [PSCredential] $PSCredential
)

# HACK this is the only way I can figure out how to get the cred parameters into Pester BeforeAll context.
$global:Credential = $PSCredential

Import-Module $PSScriptRoot\..\.. -Force -Verbose:$false

Describe 'ADUser' -Tags Integration {
    BeforeAll {
        [Diagnostics.CodeAnalysis.SuppressMessage("UseDeclaredVarsMoreThanAssignments","", Scope="member")]
        $ConnectionParam = @{
            Server = $Server
            Credential = $global:Credential
        }
        [Diagnostics.CodeAnalysis.SuppressMessage("UseDeclaredVarsMoreThanAssignments","", Scope="member")]
        $BuiltInUserDistinguishedNames = & "$PSScriptRoot\Shared\Get-BuiltInUserDistinguishedNames.ps1"
        [Diagnostics.CodeAnalysis.SuppressMessage("UseDeclaredVarsMoreThanAssignments","", Scope="member")]
        $BuiltInOrganizationalUnitDistinguishedNames = @(
            'OU=Domain Controllers,DC=samdom,DC=example,DC=com'
        )
    }

    It 'Can New-ADUser and Get-ADUser with the correct sAMAccountName' {
        $testUserName = 'createUser1'
        New-ADUser @ConnectionParam -Name $testUserName -Verbose:$VerbosePreference
        
        $result = Get-ADUser @ConnectionParam -Identity $testUserName -Verbose:$VerbosePreference
        $result.Properties['sAMAccountName'] | Should -Be $testUserName
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
        & "$PSScriptRoot\Shared\Clear-TestObjects.ps1"
    }

    #TODO Test by other Identity types, Set dict, test -LDAPFilter, automate clean-up.
}