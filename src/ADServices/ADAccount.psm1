Set-StrictMode -Version Latest
$ErrorActionPreference = [Management.Automation.ActionPreference]::Stop
. $PSScriptRoot\Shared\Variables.ps1

function Enable-ADAccount {
    [Diagnostics.CodeAnalysis.SuppressMessage(
        'PSShouldProcess','',Scope='Function',Justification='-WhatIf passed through to ADUser func'
    )]
    [CmdletBinding(SupportsShouldProcess)]
    param (
        [Parameter(Mandatory, ValueFromPipeline)]
        [string] $Identity,
        [string] $Server,
        [PSCredential] $Credential,
        [switch] $PassThru
    )
    begin {
        $commonParams = @{
            WhatIf = $WhatIfPreference
            Verbose = $VerbosePreference
        }
    }
    process {
        Set-ADUser -Identity $Identity -Enabled $true -Server $Server -Credential $Credential -PassThru:$PassThru @commonParams
        # $entry = Get-ADUser -Server $Server -Credential $Credential -Identity $Identity
        # if ($entry) {
        #     if ($PSCmdlet.ShouldProcess($Identity, "Enable-ADAccount")) {
        #         Write-Verbose "Enabling user account '$Identity'."
        #         Set-LDAPEntryFlag $entry userAccountControl $UserAccountControl_ACCOUNT_DISABLED $false -Verbose:$VerbosePreference
        #         Set-ADObject $Identity -Replace @{userAccountControl = $entry.userAccountControl} -Server $Server -Credential $Credential -WhatIf:$WhatIfPreference -Verbose:$VerbosePreference
        #     }
        #     if ($PassThru) {
        #         Get-ADUser $Identity -Server $Server -Credential $Credential
        #     }
        # } else {
        #     Write-Error "Account not found: $Identity"
        # }
    }
}


function Disable-ADAccount {
    [Diagnostics.CodeAnalysis.SuppressMessage(
        'PSShouldProcess','',Scope='Function',Justification='-WhatIf passed through to ADUser func'
    )]
    [CmdletBinding(SupportsShouldProcess)]
    param (
        [Parameter(Mandatory, ValueFromPipeline)]
        [string] $Identity,
        [string] $Server,
        [PSCredential] $Credential,
        [switch] $PassThru
    )
    begin {
        $commonParams = @{
            WhatIf = $WhatIfPreference
            Verbose = $VerbosePreference
        }
    }
    process {
        Set-ADUser -Identity $Identity -Enabled $false -Server $Server -Credential $Credential -PassThru:$PassThru @commonParams
        # $entry = Get-ADUser -Server $Server -Credential $Credential -Identity $Identity
        # if ($entry) {
        #     if ($PSCmdlet.ShouldProcess($Identity, "Disable-ADAccount")) {
        #         Write-Verbose "Disabling user account '$Identity'."
        #         Set-LDAPEntryFlag $entry userAccountControl $UserAccountControl_ACCOUNT_DISABLED $true -Verbose:$VerbosePreference
        #         Set-ADObject $Identity -Replace @{userAccountControl = $entry.userAccountControl} -Server $Server -Credential $Credential -WhatIf:$WhatIfPreference -Verbose:$VerbosePreference
        #         $entry.CommitChanges()
        #     }
        #     if ($PassThru) {
        #         Update-ADUserEntry $entry

        #         # output
        #         $entry
        #     }
        # } else {
        #     Write-Error "Account not found: $Identity"
        # }
    }
}
