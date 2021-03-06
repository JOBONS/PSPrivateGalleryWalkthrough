$script:SQLLocalDBPath = Join-Path $env:ProgramFiles 'Microsoft SQL Server\120\Tools\Binn\SqlLocalDB.exe'

function Get-TargetResource
{
	[CmdletBinding()]
	[OutputType([System.Collections.Hashtable])]
	param
	(
		[parameter(Mandatory = $true)]
		[System.String]
		$InstanceName
	)

    $Ensure = 'Absent'

    # Get all instance and then check if specific one exists
    # This is because if the instance doesn't exist, the cmd still write output
    Write-Verbose -Message 'Finding all instances ...'
    $allInstance = & $script:SQLLocalDBPath info

    if($allInstance -contains $InstanceName)
    {
        Write-Verbose -Message "SQLExpress instance $InstanceName is present"
        $currentInstance = & $script:SQLLocalDBPath info $InstanceName

        if($currentInstance)
        {
            $Ensure = 'Present'
            $currentState = ($currentInstance| ?{$_ -like 'State*'}).split(':')[-1].TrimStart('')
            $currentOwner = ($currentInstance| ?{$_ -like 'Owner*'}).split(':')[-1].TrimStart('')
            $currentVersion = ($currentInstance| ?{$_ -like 'Version*'}).split(':')[-1].TrimStart('')
        }
    }
    else
    {
            Write-Verbose -Message "SQLExpress instance $InstanceName is NOT present"
    }

    @{
		Ensure = $Ensure
		InstanceName = $InstanceName
		Status = $currentState
        Owner = $currentOwner
        Version = $currentVersion
	}
}

function Set-TargetResource
{
	[CmdletBinding()]
	param
	(
		[parameter(Mandatory = $true)]
		[System.String]
		$InstanceName,

		[ValidateSet("Running","Stopped")]
		[System.String]
		$Status = 'Running',

		[ValidateSet("Present","Absent")]
		[System.String]
		$Ensure = 'Present'

	)

    $currentState = Get-TargetResource -InstanceName $InstanceName

    # If the desired state is absent, remove the instance.
    # This will be called only is current status is present and expected is absent
    if($Ensure -eq 'Absent')
    {
        & $script:SQLLocalDBPath stop $InstanceName

        & $script:SQLLocalDBPath delete $InstanceName
        Write-Verbose -Message "Instance $InstanceName is now $Ensure"
    }

    # Code reaching here means, the instance should be present and we should check
    # for the state and owner as well
    else
    {
        # if the instance is not present, create it
        if($currentState.Ensure -ne 'Present')
        {
            & $script:SQLLocalDBPath create $InstanceName
            Write-Verbose -Message "Instance $InstanceName is now $Ensure"
        }

        # correct the status
        if($currentState.Status -ne $Status)
        {
            # if status is stopped, start it or vic-versa
            switch($Status)
            {
                'Stopped' {$action = 'stop'}
                'Running' {$action = 'start'}
            }
            & $script:SQLLocalDBPath $action $InstanceName
            Write-Verbose -Message "Instance $InstanceName status is now $Status"
        }
    }
}

function Test-TargetResource
{
	[CmdletBinding()]
	[OutputType([System.Boolean])]
	param
	(
		[parameter(Mandatory = $true)]
		[System.String]
		$InstanceName,

		[ValidateSet("Running","Stopped")]
		[System.String]
		$Status = 'Running',

		[ValidateSet("Present","Absent")]
		[System.String]
		$Ensure = 'Present'
	)

    $currentState = Get-TargetResource -InstanceName $InstanceName

    if($currentState.Ensure -ne $Ensure)
    {
        Write-Verbose -Message "Instance $InstanceName is $($currentState.Ensure), expected is $Ensure"
        return $false
    }

    if($currentState.Status -ne $Status)
    {
        Write-Verbose -Message "Instance $InstanceName status is $($currentState.Status), expected is $Status"
        return $false
    }

    return $true
}

Export-ModuleMember -Function *-TargetResource