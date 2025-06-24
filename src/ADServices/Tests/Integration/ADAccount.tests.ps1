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
        if (-not $global:Credential) {
            throw [InvalidOperationException]::new("Global Credential is null.  Something impossible has happened.")
        }

        [Diagnostics.CodeAnalysis.SuppressMessage("UseDeclaredVarsMoreThanAssignments","", Scope="member")]
        $ConnectionParam = @{
            Server = $Server
            Credential = $global:Credential
        }
        [Diagnostics.CodeAnalysis.SuppressMessage("UseDeclaredVarsMoreThanAssignments","", Scope="member")]
        $BuiltInUserDistinguishedNames = & "$PSScriptRoot\Shared\Get-BuiltInUserDistinguishedNames.ps1"
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
        & "$PSScriptRoot\Shared\Clear-TestObjects.ps1"
    }
}