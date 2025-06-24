<#
.SYNOPSIS
    Clear all non-built-in objects from the LDAP server.
#>
[CmdletBinding()]
param()
begin {
    Import-Module $PSScriptRoot\..\..\.. -Verbose:$false
}
process {
    $BuiltInUserDistinguishedNames = & "$PSScriptRoot\Get-BuiltInUserDistinguishedNames.ps1"

    # Cleanup ADUsers.
    Get-ADUser @ConnectionParam -Filter 'sAMAccountName=*' |
        Select-Object -ExpandProperty distinguishedName |
        Where-Object { 
            ($_ -NotIn $BuiltInUserDistinguishedNames) -and ($_ -notlike '*OU=Domain Controllers,DC=samdom,DC=example,DC=com')
        } |
        Sort-Object Length -Descending | # order by length so leaves are removed first where the object acts as a container.
        ForEach-Object {
            Remove-ADUser @ConnectionParam $_
        }

    $BuiltInGroupDistinguishedNames = & "$PSScriptRoot\Get-BuiltInGroupDistinguishedNames.ps1"

    # Cleanup ADGroups.
    Get-ADGroup @ConnectionParam -Filter 'sAMAccountName=*' |
        Select-Object -ExpandProperty distinguishedName |
        Where-Object {
            $_ -NotIn $BuiltInGroupDistinguishedNames
        } |
        Sort-Object Length -Descending | # order by length so leaves are removed first where the object acts as a container.
        ForEach-Object {
            Remove-ADGroup @ConnectionParam $_
        }
    
    $BuiltInOrganizationalUnitDistinguishedNames = @(
        'OU=Domain Controllers,DC=samdom,DC=example,DC=com'
    )
    
    # Cleanup ADOrganizationalUnits.
    Get-ADOrganizationalUnit @ConnectionParam -Filter 'distinguishedName=*' |
        Select-Object -ExpandProperty distinguishedName |
        Where-Object { 
            $_ -NotIn $BuiltInOrganizationalUnitDistinguishedNames
        } | 
        Sort-Object Length -Descending | # order by length so leaves are removed first where the object acts as a container.
        ForEach-Object {
            Remove-ADOrganizationalUnit @ConnectionParam -Identity $_
        }
}