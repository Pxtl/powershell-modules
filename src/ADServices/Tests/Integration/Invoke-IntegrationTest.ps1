[CmdletBinding()]
param (
    [Parameter()]
    [string] $Server = 'localhost:389',

    [Parameter()]
    [PSCredential] $PSCredential
)

# prepare
##########
docker compose -f "$PSScriptRoot\adservices-testdocker\docker-compose.yml" up -d --wait

# refresh module version in memory then unload it to prevent accidental memory of old versions of module.
Import-Module $PSScriptRoot\..\..\ADObject.psm1 -Force -Verbose:$false | Remove-Module
Import-Module $PSScriptRoot\..\..\Shared\ADHelpers.psm1 -Force -Verbose:$false | Remove-Module
Import-Module $PSScriptRoot\..\..\Shared\ADDirectoryEntry.psm1 -Force -Verbose:$false| Remove-Module
Import-Module $PSScriptRoot\..\..\Shared\SharedMetaModule.psm1 -Force -Verbose:$false| Remove-Module

# act
######
Invoke-Pester -Container (New-PesterContainer -ScriptBlock {
    & '.\ADUser.tests.ps1' -Server $Server -PSCredential $PSCredential
    & '.\ADAccount.tests.ps1' -Server $Server -PSCredential $PSCredential
    & '.\ADGroup.tests.ps1' -Server $Server -PSCredential $PSCredential
    & '.\ADOrganizationalUnit.tests.ps1' -Server $Server -PSCredential $PSCredential
    & '.\ADGroupMember.tests.ps1' -Server $Server -PSCredential $PSCredential
})