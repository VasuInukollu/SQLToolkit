﻿# This task deploys a DACPAC file using the DACPAC runtime that is expected to be present on the execution server
[CmdletBinding()]
Param()

Trace-VstsEnteringInvocation $MyInvocation

Try
{
	Import-VstsLocStrings "$PSScriptRoot\Task.json"
    [string]$packagePath = Get-VstsInput -Name packagePath
	[string]$serverName = Get-VstsInput -Name serverName
	[string]$databaseName = Get-VstsInput -Name databaseName
	[string]$userName = Get-VstsInput -Name userName
	[string]$userPassword = Get-VstsInput -Name userPassword
	[string]$logProgress = Get-VstsInput -Name logProgress

	Write-Host "Running DACPAC " $packagePath " on Database " $databaseName
		
	$connString = "Server=$serverName;"
	if(-not [string]::IsNullOrEmpty($userName))
	{
		$ConnString += "UID=$userName;PWD=$userPassword;" 
	}
	else 
	{
		$ConnString += "Trusted_Connection=True;"	
	}

	# Pick the right DACPAC runtime version
	$dacDllPath = $null 
	for($ver=110; $ver -lt 200; $ver+=10) # DACPAC ships with SQL Server 2008 and above
	{
		$path = "C:\\Program Files (x86)\\Microsoft SQL Server\\$ver\\DAC\\bin"
		if(Get-Item -Path $path -ErrorAction SilentlyContinue)
		{
			$dacDllPath = $path
		}
	}
	
	if(!$dacDllPath)
	{
		Write-Error "DACPAC runtime not found, make sure the task executes on a machine with SQL Server tools installed"
		exit
	}

	Add-Type -Path "$dacDllPath\\Microsoft.SqlServer.Dac.dll"
	$service = New-Object Microsoft.SqlServer.Dac.DacServices $connString
	if(-not [string]::IsNullOrEmpty($logProgress))
	{
		Register-ObjectEvent -InputObject $service -EventName "Message" -Action { Write-Host $EventArgs.Message.Message } | out-null
	}
	$package = [Microsoft.SqlServer.Dac.DacPackage]::Load($packagePath)
	$service.Deploy($package, $databaseName, $true, $null, $null) 

	Write-Host "Finished"
}

catch
{
	Write-Error "Error running DACPAC: $_"
	$_ | format-list -force
}

