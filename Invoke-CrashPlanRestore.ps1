<#

Copyright (c) 2018 Pandora Media, Inc., All rights reserved.

Redistribution and use in source and binary forms, with or without modification, are permitted provided that the following conditions are met:

	1. Redistributions of source code must retain the above copyright notice, this list of conditions and the following disclaimer.
	2. Redistributions in binary form must reproduce the above copyright notice, this list of conditions and the following disclaimer in the documentation and/or other materials provided with the distribution.
	3. Neither the name of the copyright holder nor the names of its contributors may be used to endorse or promote products derived from this software without specific prior written permission.

THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO,
THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS
BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE
GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT
LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.

#>

#Code42 CrashPlan Push Restore Powershell Script - Cole Johnson (https://www.linkedin.com/in/coleojohnson/) - Pandora Media Inc. - 10/12/2018

function Invoke-CrashPlanRestore {
<#

	.SYNOPSIS
	This is a Powershell script to push a previous CrasPlan backup to a new machine

	.DESCRIPTION
	This script takes a source and destination computer, creates the necessary push-restore values, and initiates a push restore of selected files to the destination computer.

	.EXAMPLE
	crashplan_push_restore -ComputerName bburnham-w01 -Destination bburnham-w02
	.EXAMPLE
	crashplan_push_restore -ComputerName bburnham-w04 -Destination bburnham-m01

	.NOTES
	Though this script is written in Powershell, it can restore both to and from macOS and Windows devices (CrashPlan agent must be installed). It could also be launched from macOS or Linux so long as Powershell Core is installed on the host.
	Depending upon the destination computer"s OS, the directory to restore to ("restorepath") will either be "C:\Windows\Temp" (Windows), or "/tmp" (macOS). (Linux restorepaths would need to be added)
	The script decides the most recent backup based off of the "lastconnected" value found in a computer"s returned API object.
	The script takes a moment to process all CrashPlan objects. The larger your organization, the longer this will take.
	The script will exit if it cannot make contact with your CrashPlan server.
	The script will exit if either the source or destination machine do not exist in CrashPlan.
    Forward slashes are substitued for the usual Windows-appropriate backwards slashes when building Windows restore directories. This is because the API calls will only accept forward slashes.
    The final backup path will create a directory called "crashplan-restore-(DATE/TIME)" to the restore-to path.
    Windows ex: "C:\Windows\Temp\crashplan-restore-10022018-000426" macOS ex: "C:\Windows\Temp\crashplan-restore-10022018-000426"
    "numBytes" and "numFiles" are both required parameters but have been left to a default value of "1". These values are only helpful if you need to develop some sort of progress bar


	#>

	[CmdletBinding()]
	param
	(

		# Computer to restore FROM (i.e. source-computer)
		[Parameter(Mandatory = $true)]
		[string]$ComputerName,

		# Computer to restore TO (i.e. destination-computer)
		[Parameter(Mandatory = $true)]
		[string]$Destination
	)
	process {

		#Input static variables here:
		#Example url: "https://crashplan.yourdomain.com:4285/api"
		$cpUrl = "https://(your-crashplan-url).com:4285/api"
		# Push-Restore credentials
		$cpUser = "(service-account-username)"
		$cpPassword = "(service-account-password)"
		$auth = $cpUser + ":" + $cpPassword
		$Encoded = [System.Text.Encoding]::UTF8.GetBytes($auth)
		$EncodedPassword = [System.Convert]::ToBase64String($Encoded)
		$headers = @{ "Authorization" = "Basic $($EncodedPassword)" }

		#DECLARE TLS 1.2 as required by CP API past Server version 5.3.1 (on 6.7 at time of writing)
		[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12



		#Get date so that logs may be individually dated
		$Script_Date = Get-Date -Format o
		$TranscriptPath = "C:\scripts\Logs\CrashPlan_PushRestore_Job_$ComputerName`_to_$Destination`_$Script_Date.log"
		#End static variables


		Start-Transcript -Path $TranscriptPath

		Write-Output -InputObject "####################################################################################"
		Write-Output -InputObject "Collecting CrashPlan objects for further processing.."
		Write-Output -InputObject ""


		#Clear errors between consecutive runs
		$error.Clear()
		$api_responses_array = @()

		$count = -1
		$i = 1
		for ($i = 1; $count -ne 0; $i++) {
			#Perform API lookup of all CrashPlan computer objects matching criteria. Page through until none left
			try {
				$api_response = (Invoke-RestMethod "$cpUrl/Computer?pgSize=2000&pgNum=$i&active=true&incBackupUsage=true" -Method Get -Header $headers)
			}

			catch {
				Write-Host $error -ForegroundColor Red; Stop-Transcript; return
			}

			Write-Output -InputObject "Processing CrashPlan objects.. "
			$count = $api_response.data.computers.Count
			#Add page of CrashPlan computer objects into array
			$api_responses_array += $api_response
		}



		Write-Output -InputObject "####################################################################################"
		Write-Output -InputObject ""
		Write-Output -InputObject "####################################################################################"
		Write-Output -InputObject "Source Computer API Object"
		Write-Output -InputObject ""
		#Source Computer API Object
		$Source_computer_API_object = $api_responses_array.data.computers | Where-Object name -EQ "$ComputerName"

		if ($null -eq $Source_computer_API_object) {
			$PSCmdlet.ThrowTerminatingError("$ComputerName not found in CrashPlan! Check to see if this computer exists in the CrashPlan console. Exiting script..")
		}


		Write-Output -InputObject "Source computer hostname: $ComputerName"

		Write-Output -InputObject "SOURCE COMPUTER GUID:"
		$last_connected_SOURCE_GUID = $Source_computer_API_object.GUID
		$last_connected_SOURCE_GUID = $last_connected_SOURCE_GUID.trim()
		Write-Output -InputObject $last_connected_SOURCE_GUID
		if ($Source_computer_API_object.Count -ge 2) {

			Write-Output -InputObject "More than one source computer with this hostname found! `nMachine has duplicate records."
			#Create array for sorting object guids and their relative "Last-Connected" dates
			$objectarray = @()
			Write-Output -InputObject "Showing all objects.."
			foreach ($object in $Source_computer_API_object) {
				#Preventative "If" statement to keep push-restore from attempting to pull latest backup from current machine, if exists. (Applies if function run during imaging)
				if ($object.Name -notmatch "$env:COMPUTERNAME") {
					Write-Output -InputObject "######################"
					Write-Output -InputObject ""
					Write-Output -InputObject $object.Name
					Write-Output -InputObject $object.GUID
					Write-Output -InputObject ""
					#Create custom PS object for each computer object to add to array
					$objectinfo = New-Object psobject
					$objectinfo | Add-Member -MemberType noteproperty -Name "Name" -Value $object.Name
					$objectinfo | Add-Member -MemberType noteproperty -Name "GUID" -Value $object.GUID
					$object_last_connected_date = $($object.lastconnected).ToString().Split("T")[0]
					$converted_object_last_connected_date = (Get-Date $object_last_connected_date).ToString("yyyy/MM/dd")
					$objectinfo | Add-Member -MemberType noteproperty -Name "date" -Value $converted_object_last_connected_date
					$objectarray += $objectinfo

				}
			}

			Write-Output -InputObject "Now comparing `"Last Connected`" dates to find destination host with most recent activity"
			Write-Output -InputObject ""

			$last_connected = $($objectarray | Sort Date | Select-Object -Last 1).GUID


			Write-Output -InputObject "Latest `"Last Connected`" Date:"
			Write-Output -InputObject $($objectarray | Sort Date | Select-Object -Last 1)
			Write-Output -InputObject ""


			#Cleanup spaces around object (in case there are any..)
			$last_connected_SOURCE_GUID = $last_connected.trim()

			Write-Output -InputObject "Latest Backup SOURCE GUID:"
			Write-Output -InputObject $last_connected_SOURCE_GUID
		}

		#Now that you have the latest backup GUID, perform another search using this machine.
		$last_connected_SOURCE_GUID_computer_data = (Invoke-RestMethod "$cpUrl/Computer?guid=$last_connected_SOURCE_GUID&incBackupUsage=true&incAll=true" -Method Get -Header $headers)

		#Set restore from path that corresponds to machine and machine os
		$userhomedirectory = $last_connected_SOURCE_GUID_computer_data.data.computers.settings.userHome

		Write-Output -InputObject "####################################################################################"
		Write-Output -InputObject ""


		Write-Output -InputObject "####################################################################################"
		Write-Output -InputObject "Source archive location information"
		Write-Output -InputObject ""

		$source_server_info = (Invoke-RestMethod "$cpUrl/Computer?guid=$last_connected_SOURCE_GUID&incBackupUsage=true" -Method Get -Header $headers)
		$server_guid = $source_server_info.data.computers.backupUsage.serverGuid


		Write-Output "Source computer's latest archive is stored in this server guid:"
		Write-Output -InputObject $server_guid
		Write-Output -InputObject "####################################################################################"
		Write-Output -InputObject ""

		Write-Output -InputObject "####################################################################################"
		Write-Output -InputObject "Destination Computer API Object"
		Write-Output -InputObject ""
		$Destination_computer_API_object = $api_responses_array.data.computers | Where-Object name -EQ "$Destination"

		if ($null -eq $Destination_computer_API_object) {
			$PScmdlet.ThrowTerminatingError("$Destination not found in CrashPlan! Check to see if this computer exists in the CrashPlan console. Exiting script..")
		}

		$last_connected_DESTINATION_GUID = $Destination_computer_API_object.GUID
		if ($Destination_computer_API_object.Count -ge 2) {
			#Create array for sorting object guids and their relative "Last-Connected" dates
			$objectarray_destination = @()
			Write-Output -InputObject "More than one computer found with this hostname found! `nMachine has duplicate records."
			Write-Output -InputObject "Showing all objects.."

			foreach ($object in $Destination_computer_API_object) {
				#Preventative "If" statement to keep push-restore from attempting to pull latest backup from current machine, if exists. (Applies if function run during imaging)
				Write-Output -InputObject "######################"
				Write-Output -InputObject ""
				Write-Output -InputObject $object.Name
				Write-Output -InputObject $object.GUID
				Write-Output -InputObject ""
				#Create custom PS object for each computer object to add to array
				$objectinfo = New-Object psobject
				$objectinfo | Add-Member -MemberType noteproperty -Name "Name" -Value $object.Name
				$objectinfo | Add-Member -MemberType noteproperty -Name "GUID" -Value $object.GUID
				$object_last_connected_date = $($object.lastconnected).ToString().Split("T")[0]
				$converted_object_last_connected_date = (Get-Date $object_last_connected_date).ToString("yyyy/MM/dd")
				$objectinfo | Add-Member -MemberType noteproperty -Name "date" -Value $converted_object_last_connected_date
				$objectarray_destination += $objectinfo
			}

			Write-Output -InputObject "Now comparing `"Last Connected`" dates to find destination host with most recent activity"
			$last_connected_DESTINATION_GUID = $($($objectarray_destination | Sort Date | Select-Object -Last 1).GUID).trim()

			Write-Output -InputObject "Latest `"Last Connected`" Destination Object Date:"
			Write-Output -InputObject $($objectarray_destination | Sort Date | Select-Object -Last 1)
			Write-Output -InputObject ""
			Write-Output -InputObject "Script has selected the destination object with the most recent activity."
			Write-Output -InputObject "Latest Backup DESTINATION GUID"
			Write-Output -InputObject $last_connected_DESTINATION_GUID


		}
		#Now that you have the latest backup GUID, perform another lookup of this machine.
		$last_connected_DESTINATION_computer_data = (Invoke-RestMethod "$cpUrl/Computer?guid=$last_connected_DESTINATION_GUID" -Method Get -Header $headers)


		Write-Output -InputObject "####################################################################################"
		Write-Output -InputObject ""


		Write-Output -InputObject "####################################################################################"
		Write-Output -InputObject "Decide restore path based on destination computer OS.."
		Write-Output -InputObject ""

		#Set directory to pull from depending upon OS of destination
		$userhomedirectory = $last_connected_SOURCE_GUID_computer_data.data.computers.settings.userHome

		Write-Output -InputObject "Operating System Type:"
		Write-Output -InputObject $last_connected_DESTINATION_computer_data.data.computers.osname

		#Set directory to push to depending upon OS of destination computer
		if ($last_connected_DESTINATION_computer_data.data.computers.osname -eq "mac") {
			$restorepath = "/tmp"
		}
		elseif ($last_connected_DESTINATION_computer_data.data.computers.osname -eq "win") {
			$restorepath = "C:/Windows/Temp"
		}

		Write-Output -InputObject "####################################################################################"
		Write-Output -InputObject ""
		Write-Output -InputObject "####################################################################################"
		Write-Output -InputObject "Getting Data Key Token..."
		Write-Output -InputObject ""


		$data_key_token_post_values = @{
			computerGuid = $last_connected_SOURCE_GUID
		}

		$source_computer_data_post = (Invoke-RestMethod "$cpUrl/DataKeyToken" -Method Post -Body (ConvertTo-Json $data_key_token_post_values) -ContentType application/json -Header $headers)

		$dataKeyToken = $($source_computer_data_post.data.dataKeyToken).trim()


		Write-Output -InputObject "Data Key Token"
		Write-Output -InputObject $dataKeyToken
		Write-Output -InputObject "####################################################################################"
		Write-Output -InputObject ""


		Write-Output -InputObject "####################################################################################"
		Write-Output -InputObject "Get Web Restore Session ID.."
		Write-Output -InputObject ""

		# Get Web Restore Session Id
		$web_restore_body_values = @{
			computerGuid = $last_connected_SOURCE_GUID
			dataKeyToken = $dataKeyToken
		}

		$web_restore_session_id = $((Invoke-RestMethod "$cpUrl/WebRestoreSession" -Method Post -Body (ConvertTo-Json $web_restore_body_values) -ContentType application/json -Header $headers).data.webRestoreSessionId)

		Write-Output -InputObject "####################################################################################"
		Write-Output -InputObject ""
		Write-Output -InputObject "####################################################################################"
		Write-Output -InputObject "Transfer information:"
		Write-Output -InputObject ""
		Write-Output -InputObject "Will pull backup from the following machine: $ComputerName"
		Write-Output -InputObject ""
		Write-Output -InputObject "Transferring data to computer: $Destination"
		Write-Output -InputObject ""
		Write-Output -InputObject "Pulling data from the following path: $userhomedirectory"
		Write-Output -InputObject ""
		Write-Output -InputObject "Restoring data to the following path: $restorepath"
		Write-Output -InputObject ""
		Write-Output -InputObject "#######################################################################################"
		Write-Output -InputObject "Push restore body values:"
		Write-Output -InputObject ""
		Write-Output -InputObject "Web restore session id"
		Write-Output -InputObject $web_restore_session_id
		Write-Output -InputObject ""
		Write-Output -InputObject "Source guid"
		Write-Output -InputObject $last_connected_SOURCE_GUID
		Write-Output -InputObject ""
		Write-Output -InputObject "Target node guid"
		Write-Output -InputObject $server_guid
		Write-Output -InputObject ""

		Write-Output -InputObject "Accepting guid"
		Write-Output -InputObject $last_connected_DESTINATION_GUID
		Write-Output -InputObject ""

		$Push_Restore_Request_Body = @{
			acceptingGuid = $last_connected_DESTINATION_GUID
			numBytes = 1
			numFiles = 1
			pathSet = @(
				@{
					type = "directory"
					path = $userhomedirectory
					selected = $true
				}
			)
			restoreFullPath = $false
			restorePath = $restorepath
			showDeleted = $true
			sourceGuid = $last_connected_SOURCE_GUID
			targetNodeGuid = $server_guid
			webRestoreSessionId = $web_restore_session_id
		}



		Write-Output -InputObject "#######################################################################################"
		Write-Output -InputObject ""


		Write-Output -InputObject "Initiating push restore.."
		#PushRestore Job data post
		Invoke-RestMethod "$cpUrl/PushRestoreJob" -Method Post -Body (ConvertTo-Json $Push_Restore_Request_Body) -ContentType application/json -Header $headers

		#END FUNCTION
		Stop-Transcript
	}
}
