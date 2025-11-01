Set-StrictMode -Version Latest
$ErrorActionPreference = [Management.Automation.ActionPreference]::Stop
. $PSScriptRoot\Shared\Variables.ps1

function Enable-ADAccount {
    [CmdletBinding(SupportsShouldProcess)]
    param (
        [Parameter(Mandatory, ValueFromPipeline)]
        [string] $Identity,
        [string] $Server,
        [PSCredential] $Credential,
        [switch] $PassThru
    )
    process {
        $entry = Get-ADUser -Server $Server -Credential $Credential -Identity $Identity
        if ($entry) {
            if ($PSCmdlet.ShouldProcess($Identity, "Enable-ADAccount")) {
                Write-Verbose "Enabling user account '$Identity'."
                Set-LDAPEntryFlag $entry userAccountControl $UserAccountControl_ACCOUNT_DISABLED $false -Verbose:$VerbosePreference
                $entry.CommitChanges()
            }
            if ($PassThru) {
                Update-ADUserEntry $entry

                # output
                $entry
            }
        } else {
            Write-Error "Account not found: $Identity"
        }
    }
}


function Disable-ADAccount {
    [CmdletBinding(SupportsShouldProcess)]
    param (
        [Parameter(Mandatory, ValueFromPipeline)]
        [string] $Identity,
        [string] $Server,
        [PSCredential] $Credential,
        [switch] $PassThru
    )
    process {
        $entry = Get-ADUser -Server $Server -Credential $Credential -Identity $Identity
        if ($entry) {
            if ($PSCmdlet.ShouldProcess($Identity, "Disable-ADAccount")) {
                Write-Verbose "Disabling user account '$Identity'."
                Set-LDAPEntryFlag $entry userAccountControl $UserAccountControl_ACCOUNT_DISABLED $true -Verbose:$VerbosePreference
                $entry.CommitChanges()
            }
            if ($PassThru) {
                Update-ADUserEntry $entry

                # output
                $entry
            }
        } else {
            Write-Error "Account not found: $Identity"
        }
    }
}
