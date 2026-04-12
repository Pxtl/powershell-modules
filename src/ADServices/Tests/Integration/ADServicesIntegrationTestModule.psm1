Import-Module $PSScriptRoot\..\..\bin\Debug\net48\ADServices.dll

function Initialize-TestHarness {
    <#
    .SYNOPSIS
        Starts the docker instance if it's not running already and returns connection information.
    #>
    [OutputType([hashtable])]
    [CmdletBinding()]
    param (
        [Parameter()]
        [string] $Server = 'localhost:389',

        [Parameter()]
        [Management.Automation.PSCredential] $PSCredential
    )
    process {
        if (-not $PSCredential) {
            # default credentials for smblds
            $PSCredential = [Management.Automation.PSCredential]::new('Administrator', (ConvertTo-SecureString 'Passw0rd' -AsPlainText -Force))
        }
        if (-not (Test-ADRootDSE -Server $Server -Credential $PSCredential)) {
            # need to Out-Host so that the credentials are the only output in main pipeline.
            docker compose -f "$PSScriptRoot\adservices-testdocker\docker-compose.yml" up -d --wait | Out-Host
        }

        # output
        @{
            Credential = $PSCredential
            Server = $Server
        }
    }
}


function Clear-TestObjects {
    <#
    .SYNOPSIS
        Clear all non-built-in objects from the LDAP server.
    #>
    [CmdletBinding()]
    param()
    process {
        $builtInUserDistinguishedNames = Get-BuiltInUserDistinguishedNames

        # Cleanup ADUsers.
        Get-ADUser @ConnectionParam -LDAPFilter 'sAMAccountName=*' |
            Select-Object -ExpandProperty distinguishedName |
            Where-Object { 
                ($_ -NotIn $builtInUserDistinguishedNames) -and ($_ -notlike '*OU=Domain Controllers,DC=samdom,DC=example,DC=com')
            } |
            Sort-Object Length -Descending | # order by length so leaves are removed first where the object acts as a container.
            ForEach-Object {
                Remove-ADUser @ConnectionParam $_
            }

        $builtInGroupDistinguishedNames = Get-BuiltInUserDistinguishedNames

        # Cleanup ADGroups.
        Get-ADGroup @ConnectionParam -LDAPFilter 'sAMAccountName=*' |
            Select-Object -ExpandProperty distinguishedName |
            Where-Object {
                $_ -NotIn $builtInGroupDistinguishedNames
            } |
            Sort-Object Length -Descending | # order by length so leaves are removed first where the object acts as a container.
            ForEach-Object {
                Remove-ADGroup @ConnectionParam $_
            }
        
        $builtInOrganizationalUnitDistinguishedNames = Get-BuiltInOrganizationalUnitDistinguishedNames
        
        # Cleanup ADOrganizationalUnits.
        Get-ADOrganizationalUnit @ConnectionParam -LDAPFilter 'distinguishedName=*' |
            Select-Object -ExpandProperty distinguishedName |
            Where-Object { 
                $_ -NotIn $builtInOrganizationalUnitDistinguishedNames
            } | 
            Sort-Object Length -Descending | # order by length so leaves are removed first where the object acts as a container.
            ForEach-Object {
                Remove-ADOrganizationalUnit @ConnectionParam -Identity $_
            }
    }
}


function Get-BuiltInUserDistinguishedNames {
    <#
    .SYNOPSIS
    List of built-in User distinguished names in smblds/smblds docker container
    #>
    [CmdletBinding()]
    param()
    process {
        @(
            'CN=Enterprise Admins,CN=Users,DC=samdom,DC=example,DC=com'
            'CN=Print Operators,CN=Builtin,DC=samdom,DC=example,DC=com'
            'CN=Users,CN=Builtin,DC=samdom,DC=example,DC=com'
            'CN=Guests,CN=Builtin,DC=samdom,DC=example,DC=com'
            'CN=IIS_IUSRS,CN=Builtin,DC=samdom,DC=example,DC=com'
            'CN=Event Log Readers,CN=Builtin,DC=samdom,DC=example,DC=com'
            'CN=Domain Controllers,CN=Users,DC=samdom,DC=example,DC=com'
            'CN=RAS and IAS Servers,CN=Users,DC=samdom,DC=example,DC=com'
            'CN=Network Configuration Operators,CN=Builtin,DC=samdom,DC=example,DC=com'
            'CN=Terminal Server License Servers,CN=Builtin,DC=samdom,DC=example,DC=com'
            'CN=Domain Computers,CN=Users,DC=samdom,DC=example,DC=com'
            'CN=Enterprise Read-only Domain Controllers,CN=Users,DC=samdom,DC=example,DC=com'
            'CN=Pre-Windows 2000 Compatible Access,CN=Builtin,DC=samdom,DC=example,DC=com'
            'CN=Distributed COM Users,CN=Builtin,DC=samdom,DC=example,DC=com'
            'CN=Performance Monitor Users,CN=Builtin,DC=samdom,DC=example,DC=com'
            'CN=Replicator,CN=Builtin,DC=samdom,DC=example,DC=com'
            'CN=Denied RODC Password Replication Group,CN=Users,DC=samdom,DC=example,DC=com'
            'CN=Windows Authorization Access Group,CN=Builtin,DC=samdom,DC=example,DC=com'
            'CN=Administrators,CN=Builtin,DC=samdom,DC=example,DC=com'
            'CN=DnsAdmins,CN=Users,DC=samdom,DC=example,DC=com'
            'CN=Backup Operators,CN=Builtin,DC=samdom,DC=example,DC=com'
            'CN=Domain Admins,CN=Users,DC=samdom,DC=example,DC=com'
            'CN=Read-only Domain Controllers,CN=Users,DC=samdom,DC=example,DC=com'
            'CN=Cryptographic Operators,CN=Builtin,DC=samdom,DC=example,DC=com'
            'CN=Server Operators,CN=Builtin,DC=samdom,DC=example,DC=com'
            'CN=Domain Guests,CN=Users,DC=samdom,DC=example,DC=com'
            'CN=Performance Log Users,CN=Builtin,DC=samdom,DC=example,DC=com'
            'CN=Group Policy Creator Owners,CN=Users,DC=samdom,DC=example,DC=com'
            'CN=Certificate Service DCOM Access,CN=Builtin,DC=samdom,DC=example,DC=com'
            'CN=Cert Publishers,CN=Users,DC=samdom,DC=example,DC=com'
            'CN=Allowed RODC Password Replication Group,CN=Users,DC=samdom,DC=example,DC=com'
            'CN=Schema Admins,CN=Users,DC=samdom,DC=example,DC=com'
            'CN=Protected Users,CN=Users,DC=samdom,DC=example,DC=com'
            'CN=Incoming Forest Trust Builders,CN=Builtin,DC=samdom,DC=example,DC=com'
            'CN=Remote Desktop Users,CN=Builtin,DC=samdom,DC=example,DC=com'
            'CN=Account Operators,CN=Builtin,DC=samdom,DC=example,DC=com'
            'CN=DnsUpdateProxy,CN=Users,DC=samdom,DC=example,DC=com'
            'CN=Domain Users,CN=Users,DC=samdom,DC=example,DC=com'
        )
    }
}


function Get-BuiltInGroupDistinguishedNames {
    <#
    .SYNOPSIS
    List of built-in Group distinguished names in smblds/smblds docker container
    #>
    [CmdletBinding()]
    param()
    process {
        @(
            'CN=Administrator,CN=Users,DC=samdom,DC=example,DC=com'
            'CN=Guest,CN=Users,DC=samdom,DC=example,DC=com'
            'CN=krbtgt,CN=Users,DC=samdom,DC=example,DC=com'
        )
    }
}


function Get-BuiltInOrganizationalUnitDistinguishedNames {
    <#
    .SYNOPSIS
    List of built-in OrganizationalUnit distinguished names in smblds/smblds docker container
    #>
    [CmdletBinding()]
    param()
    process {
        @(
            'OU=Domain Controllers,DC=samdom,DC=example,DC=com'
        )
    }
}