#run like below from command line
#powershell.exe -ExecutionPolicy ByPass -File C:\Script\fullbackup.ps1

# Place this file in C:\Script

#Update the following variable, $dest, $FTPHost , $FTPUser, $FTPPass


# Start logging
Start-Transcript -Path C:\Script\fullbackup.log

## Powershell Script to Shutdown and Export Hyper-V 2012 VMs, one at a time.  

## Destination Folder of the Exports, A subfolder for each VM will be created.
	
	$date = Get-Date -format "dd-MM-yyyy"
	
	$dest = "E:\Backup\" + $date

Write-Output "Starting a backup of the all the VMs" 

$Node = $env:computername

## Get a list of all VMs on Node
$VMs = Get-VM

## For each VM on Node, Shutdown, Export and Start 
foreach ($VM in $VMs) 
{
	$VMName = $VM.Name
	$VMName

    $summofvm = Get-VM -Name $VMName | Get-VMIntegrationService -Name Heartbeat
    $HBStatus = $summofvm.OperationalStatus
    $VMState = $VM.State
    $doexport = "no"
    
    Write-Host "Checking $VMName" 
	"Checking the current state of $VMName"

    if ($HBStatus -eq "OK")
    {
		write-host Heartbeat Status is $HBStatus
		$doexport = "yes"
		write-host "HeartBeat Service for $VMName is responding $HBStatus, beginning shutdown sequence"
		"<HeartBeat Service for $VMName is responding $HBStatus, beginning shutdown sequence at " + (get-date).ToShortTimeString()
    }

	$HBStatus = $summofvm.OperationalStatus
    $VMState = $VM.State
	write-host "$VMName is $VMState"
	Start-Sleep -s 10
	
	$backup_file_name = $dest + "\"  + $VMName 
	Write-Output $backup_file_name 
	
	
	$a = Get-Date
	Write-Output $a  
	
	#Remove-Item  $backup_file_name -Force -Recurse -Verbose
	
	write-host "Exporting $VMName"
	"Export of $VMName began at " + (get-date).ToShortTimeString() 

	## Begin export of the VM
	export-vm $VMName -path $dest 

	"Export of $VMName completed at " + (get-date).ToShortTimeString() 
	
		# FTP Server Variables
	$FTPHost = 'ftp://IPADDRESS/' + $date + $VMName + '/' 
	$FTPUser = 'ftp_user'
	$FTPPass = 'ftp-password'
	  
	#Directory where to find pictures to upload
	$UploadFolder = $backup_file_name 
	   
	$webclient = New-Object System.Net.WebClient
	$webclient.Credentials = New-Object System.Net.NetworkCredential($FTPUser,$FTPPass) 
	  
	$SrcEntries = Get-ChildItem $UploadFolder -Recurse
	$Srcfolders = $SrcEntries | Where-Object{$_.PSIsContainer}
	$SrcFiles = $SrcEntries | Where-Object{!$_.PSIsContainer}

	#Create the parent directory 
	$makeDirectory = [System.Net.WebRequest]::Create($FTPHost);
	$makeDirectory.Credentials = New-Object System.Net.NetworkCredential($FTPUser,$FTPPass);
	$makeDirectory.Method = [System.Net.WebRequestMethods+FTP]::MakeDirectory;
	$makeDirectory.GetResponse();

	# Create FTP Directory/SubDirectory If Needed - Start
	foreach($folder in $Srcfolders)
	{   
		$SrcFolderPath = $UploadFolder  -replace "\\","\\" -replace "\:","\:"  
		$DesFolder = $folder.Fullname -replace $SrcFolderPath,$FTPHost
		$DesFolder = $DesFolder -replace "\\", "/"
		#Write-Output $DesFolder
		
		try
			{
				$makeDirectory = [System.Net.WebRequest]::Create($DesFolder);
				$makeDirectory.Credentials = New-Object System.Net.NetworkCredential($FTPUser,$FTPPass);
				$makeDirectory.Method = [System.Net.WebRequestMethods+FTP]::MakeDirectory;
				$makeDirectory.GetResponse();
				#folder created successfully
			}
		catch [Net.WebException]
			{
				try {
					#if there was an error returned, check if folder already existed on server
					$checkDirectory = [System.Net.WebRequest]::Create($DesFolder);
					$checkDirectory.Credentials = New-Object System.Net.NetworkCredential($FTPUser,$FTPPass);
					$checkDirectory.Method = [System.Net.WebRequestMethods+FTP]::PrintWorkingDirectory;
					$response = $checkDirectory.GetResponse();
					#folder already exists!
				}
				catch [Net.WebException] {
					#if the folder didn't exist
				}
			}
	}
	# Create FTP Directory/SubDirectory If Needed - Stop
	  
	# Upload Files - Start
	foreach($entry in $SrcFiles)
	{
		$SrcFullname = $entry.fullname
		$SrcName = $entry.Name
		$SrcFilePath = $UploadFolder -replace "\\","\\" -replace "\:","\:"
		$DesFile = $SrcFullname -replace $SrcFilePath,$FTPHost
		$DesFile = $DesFile -replace "\\", "/"
		# Write-Output $DesFile
	  
		$uri = New-Object System.Uri($DesFile)
		$webclient.UploadFile($uri, $SrcFullname)
	}
	# Upload Files - Stop
	
}
