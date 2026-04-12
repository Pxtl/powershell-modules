#need Pester v5.7.1 for New-PesterContainer
#Requires -Modules @{ModuleName='Pester'; ModuleVersion='5.7.1'} 
Import-Module 'Pester' -MinimumVersion '5.7.1'

# act
Invoke-Pester -Container (New-PesterContainer -ScriptBlock {
    & "$PSScriptRoot\ADOrganizationalUnit.tests.ps1"
    & "$PSScriptRoot\ADUser.tests.ps1"
    & "$PSScriptRoot\ADAccount.tests.ps1"
    & "$PSScriptRoot\ADGroup.tests.ps1"
    & "$PSScriptRoot\ADGroupMember.tests.ps1"
})