Describe 'ADGroup Membership' -Tags Integration {
    BeforeAll {
        Import-Module $PSScriptRoot\ADServicesIntegrationTestModule.psm1
        Import-Module $PSScriptRoot\..\..\ADServices.psd1
        [Diagnostics.CodeAnalysis.SuppressMessage("UseDeclaredVarsMoreThanAssignments","", Scope="member")]
        $ConnectionParam = Initialize-TestHarness
    }

    It 'Can Add-ADGroupMember and test using Get-ADGroup' {
        # prepare
        $groupCode = 2
        $testGroup = "parentGroup$groupCode"
        $newGroup = New-ADGroup @ConnectionParam -Name $testGroup -Verbose:$VerbosePreference -PassThru
        ($newGroup.Members | Measure-Object).Count | Should -Be 0

        $testUser1Name = "childUser1ForGroup$groupCode"
        $testUser1 = New-ADUser @ConnectionParam -Name $testUser1Name -Verbose:$VerbosePreference -PassThru
        $testUser2Name = "childUser2ForGroup$groupCode"
        $newUser2 = New-ADUser @ConnectionParam -Name $testUser2Name -Verbose:$VerbosePreference -PassThru

        # act
        Add-ADGroupMember @ConnectionParam -Identity $newGroup.distinguishedName -Members $testUser1.distinguishedName, $newUser2.distinguishedName

        # examine

        ## test fetch from AD
        $loadedADGroup = Get-ADGroup @ConnectionParam -Identity $newGroup.distinguishedName
        $loadedADGroup.Members | Should -Contain "CN=childUser1ForGroup$groupCode,CN=Users,DC=samdom,DC=example,DC=com"
        $loadedADGroup.Members | Should -Contain "CN=childUser2ForGroup$groupCode,CN=Users,DC=samdom,DC=example,DC=com"
        ($loadedADGroup.Members | Measure-Object).Count | Should -Be 2
    }

    It 'Can Add-ADGroupMember to existing ADGroup' {
        # prepare
        $groupCode = 2
        $testGroupName = "parentGroup$groupCode"
        $newGroup = New-ADGroup @ConnectionParam -Name $testGroupName -Verbose:$VerbosePreference -PassThru
        ($newGroup.Members | Measure-Object).Count | Should -Be 0

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
        $loadedADGroup.Members | Should -Contain "CN=childUser1ForGroup$groupCode,CN=Users,DC=samdom,DC=example,DC=com"
        $loadedADGroup.Members | Should -Contain "CN=childUser2ForGroup$groupCode,CN=Users,DC=samdom,DC=example,DC=com"
        $loadedADGroup.Members | Should -Contain "CN=childUser3ForGroup$groupCode,CN=Users,DC=samdom,DC=example,DC=com"
        ($loadedADGroup.Members | Measure-Object).Count | Should -Be 3
    }

    It 'Can Remove-ADGroupMember' {
        # prepare
        $groupCode = 3
        $testGroupName = "parentGroup$groupCode"
        $newGroup = New-ADGroup @ConnectionParam -Name $testGroupName -Verbose:$VerbosePreference -PassThru
        ($newGroup.Members | Measure-Object).Count | Should -Be 0

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
        $loadedADGroup.Members | Should -Not -Contain "CN=childUser1ForGroup$groupCode,CN=Users,DC=samdom,DC=example,DC=com"
        $loadedADGroup.Members | Should -Contain "CN=childUser2ForGroup$groupCode,CN=Users,DC=samdom,DC=example,DC=com"
        ($loadedADGroup.Members | Measure-Object).Count | Should -Be 1
    }

    It 'Can Get-ADGroupMember' {
        # prepare
        $groupCode = 4
        $testGroupName = "parentGroup$groupCode"
        $newGroup = New-ADGroup @ConnectionParam -Name $testGroupName -Verbose:$VerbosePreference -PassThru
        ($newGroup.Members | Measure-Object).Count | Should -Be 0

        $testUser1Name = "childUser1ForGroup$groupCode"
        $newUser1 = New-ADUser @ConnectionParam -Name $testUser1Name -Verbose:$VerbosePreference -PassThru
        $testUser2Name = "childUser2ForGroup$groupCode"
        $newUser2 = New-ADUser @ConnectionParam -Name $testUser2Name -Verbose:$VerbosePreference -PassThru
        $testChildGroupName = "childGroup$groupCode"
        $testChildGroup = New-ADGroup @ConnectionParam -Name $testChildGroupName -Verbose:$VerbosePreference -PassThru
        $testGrandchildUserName = "grandchildUser1ForGroup$groupCode"
        $grandchildUser = New-ADUser @ConnectionParam -Name $testGrandchildUserName -Verbose:$VerbosePreference -PassThru

        # act
        Add-ADGroupMember @ConnectionParam -Identity $newGroup.distinguishedName -Members $newUser1.distinguishedName, $newUser2.distinguishedName, $testChildGroup.distinguishedName -Verbose:$VerbosePreference
        Add-ADGroupMember @ConnectionParam -Identity $testChildGroup.distinguishedName -Members $grandchildUser.distinguishedName -Verbose:$VerbosePreference

        # examine

        ## test fetch from AD
        $members = Get-ADGroupMember @ConnectionParam -Identity $testGroupName -Verbose:$VerbosePreference
        $memberDNs = $members | ForEach-Object {
            $_.DistinguishedName
        }
        $memberDNs | Should -Contain "CN=childUser1ForGroup$groupCode,CN=Users,DC=samdom,DC=example,DC=com"
        $memberDNs | Should -Contain "CN=childUser2ForGroup$groupCode,CN=Users,DC=samdom,DC=example,DC=com"
        $memberDNs | Should -Contain "CN=childGroup$groupCode,CN=Users,DC=samdom,DC=example,DC=com"
        $memberDNs.Count | Should -Be 3

        ## test fetch from AD recursively
        $memberDNs = Get-ADGroupMember @ConnectionParam -Identity $testGroupName -Verbose:$VerbosePreference -Recursive | 
            ForEach-Object {
                $_.DistinguishedName
            }
        $memberDNs | Should -Contain "CN=childUser1ForGroup$groupCode,CN=Users,DC=samdom,DC=example,DC=com"
        $memberDNs | Should -Contain "CN=childUser2ForGroup$groupCode,CN=Users,DC=samdom,DC=example,DC=com"
        $memberDNs | Should -Contain "CN=childGroup$groupCode,CN=Users,DC=samdom,DC=example,DC=com"
        $memberDNs | Should -Contain "CN=grandchildUser1ForGroup$groupCode,CN=Users,DC=samdom,DC=example,DC=com"
        $memberDNs.Count | Should -Be 4
    }


    AfterEach {
        Write-Verbose "Cleanup in $($MyInvocation.MyCommand.ScriptBlock.File | Split-Path -Leaf)."
        Clear-TestObjects @ConnectionParam
    }
}