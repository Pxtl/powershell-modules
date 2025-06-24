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

Describe 'ADGroup Membership' -Tags Integration {
    BeforeAll {
        [Diagnostics.CodeAnalysis.SuppressMessage("UseDeclaredVarsMoreThanAssignments","", Scope="member")]
        $ConnectionParam = @{
            Server = $Server
            Credential = $global:Credential
        }
    }

    It 'Can Add-ADGroupMember and test using Get-ADGroup' {
        # prepare
        $groupCode = 2
        $testGroup = "parentGroup$groupCode"
        $newGroup = New-ADGroup @ConnectionParam -Name $testGroup -Verbose:$VerbosePreference -PassThru
        $newGroup.member.Count | Should -Be 0

        $testUser1Name = "childUser1ForGroup$groupCode"
        $testUser1 = New-ADUser @ConnectionParam -Name $testUser1Name -Verbose:$VerbosePreference -PassThru
        $testUser2Name = "childUser2ForGroup$groupCode"
        $newUser2 = New-ADUser @ConnectionParam -Name $testUser2Name -Verbose:$VerbosePreference -PassThru

        # act
        Add-ADGroupMember @ConnectionParam -Identity $newGroup.distinguishedName -Members $testUser1.distinguishedName, $newUser2.distinguishedName

        # examine

        ## test fetch from AD
        $loadedADGroup = Get-ADGroup @ConnectionParam -Identity $newGroup.distinguishedName
        $loadedADGroup.member | Should -Contain "CN=childUser1ForGroup$groupCode,CN=Users,DC=samdom,DC=example,DC=com"
        $loadedADGroup.member | Should -Contain "CN=childUser2ForGroup$groupCode,CN=Users,DC=samdom,DC=example,DC=com"
        $loadedADGroup.member.Count | Should -Be 2
    }

    It 'Can Add-ADGroupMember to existing ADGroup' {
        # prepare
        $groupCode = 2
        $testGroupName = "parentGroup$groupCode"
        $newGroup = New-ADGroup @ConnectionParam -Name $testGroupName -Verbose:$VerbosePreference -PassThru
        $newGroup.member.Count | Should -Be 0

        $testUser1Name = "childUser1ForGroup$groupCode"
        $testUser1 = New-ADUser @ConnectionParam -Name $testUser1Name -Verbose:$VerbosePreference -PassThru
        $testUser2Name = "childUser2ForGroup$groupCode"
        $newUser2 = New-ADUser @ConnectionParam -Name $testUser2Name -Verbose:$VerbosePreference -PassThru

        Add-ADGroupMember @ConnectionParam -Identity $testGroupName -Members $testUser1.distinguishedName, $newUser2.distinguishedName

        # act
        $testUser3Name = "childUser3ForGroup$groupCode"
        $testUser3 = New-ADUser @ConnectionParam -Name $testUser3Name -Verbose:$VerbosePreference -PassThru
        Add-ADGroupMember @ConnectionParam -Identity $testGroupName -Members $testUser3.distinguishedName

        # examine

        ## test fetch from AD
        $loadedADGroup = Get-ADGroup @ConnectionParam -Identity $newGroup.distinguishedName
        $loadedADGroup.member | Should -Contain "CN=childUser1ForGroup$groupCode,CN=Users,DC=samdom,DC=example,DC=com"
        $loadedADGroup.member | Should -Contain "CN=childUser2ForGroup$groupCode,CN=Users,DC=samdom,DC=example,DC=com"
        $loadedADGroup.member | Should -Contain "CN=childUser3ForGroup$groupCode,CN=Users,DC=samdom,DC=example,DC=com"
        $loadedADGroup.member.Count | Should -Be 3
    }

    It 'Can Remove-ADGroupMember' {
        # prepare
        $groupCode = 3
        $testGroupName = "parentGroup$groupCode"
        $newGroup = New-ADGroup @ConnectionParam -Name $testGroupName -Verbose:$VerbosePreference -PassThru
        $newGroup.member.Count | Should -Be 0

        $testUser1Name = "childUser1ForGroup$groupCode"
        $testUser1 = New-ADUser @ConnectionParam -Name $testUser1Name -Verbose:$VerbosePreference -PassThru
        $testUser2Name = "childUser2ForGroup$groupCode"
        $newUser2 = New-ADUser @ConnectionParam -Name $testUser2Name -Verbose:$VerbosePreference -PassThru

        Add-ADGroupMember @ConnectionParam -Identity $newGroup.distinguishedName -Members $testUser1.distinguishedName, $newUser2.distinguishedName

        # act
        Remove-ADGroupMember @ConnectionParam -Identity $newGroup.distinguishedName -Members $testUser1.distinguishedName

        # examine

        ## test fetch from AD
        $loadedADGroup = Get-ADGroup @ConnectionParam -Identity $newGroup.distinguishedName
        $loadedADGroup.member | Should -Not -Contain "CN=childUser1ForGroup$groupCode,CN=Users,DC=samdom,DC=example,DC=com"
        $loadedADGroup.member | Should -Contain "CN=childUser2ForGroup$groupCode,CN=Users,DC=samdom,DC=example,DC=com"
        $loadedADGroup.member.Count | Should -Be 1
    }

    AfterEach {
        Write-Verbose "Cleanup in $($MyInvocation.MyCommand.ScriptBlock.File | Split-Path -Leaf)."
        & "$PSScriptRoot\Shared\Clear-TestObjects.ps1"
    }
}