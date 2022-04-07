#Load Assembly and Library
Add-Type -AssemblyName PresentationFramework


if (Get-Module -ListAvailable -Name RSAT-AD-PowerShell) {
    #Write-Host "Module exists"
} 
else {
    Add-WindowsFeature RSAT-AD-PowerShell
}


#GPO location
$GPOlocation = 'C:\iNSTALL\FSmig\FSlogixMIG.csv'

#XAML Build
[xml]$Form = @"
<Window 
        xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
 
        Title="FS-Logix migration tool" Height="450" Width="800">
    <Grid>
        <TabControl>
            <TabItem Header="Migrate UPD to FSLogix">
                <Grid Background="#FFE5E5E5">
                    <Label Name="lblUPD" Content="Select UPD file location:" HorizontalAlignment="Left" Margin="10,10,0,0" VerticalAlignment="Top"/>
                    <TextBox Name="txtUPDpath" HorizontalAlignment="Left" Margin="10,41,0,0" Text="TextBox" TextWrapping="Wrap" VerticalAlignment="Top" Width="442"/>
                    <Button Name="btnUPDBrowse" Content="Browse" HorizontalAlignment="Left" Margin="469,39,0,0" VerticalAlignment="Top"/>
                    <Label Name="lblFSLOGIX1" Content="Select FS-Logix location:" HorizontalAlignment="Left" Margin="10,64,0,0" VerticalAlignment="Top"/>
                    <TextBox Name="txtFSLOGIX" HorizontalAlignment="Left" Margin="10,95,0,0" Text="TextBox" TextWrapping="Wrap" VerticalAlignment="Top" Width="442"/>
                    <Button Name="btnFSLOGIX" Content="Browse" HorizontalAlignment="Left" Margin="469,93,0,0" VerticalAlignment="Top"/>
                    <Button Name="btnStartMig" Content="START" HorizontalAlignment="Left" Margin="10,118,0,0" VerticalAlignment="Top" Height="37" Width="68"/>
                    <Label Content="Disable user profile disks. Select the broker server in the dropdown below:" HorizontalAlignment="Left" Margin="10,203,0,0" VerticalAlignment="Top"/>
                    <ComboBox Name="cmbHosts" HorizontalAlignment="Left" Margin="10,234,0,0" VerticalAlignment="Top" Width="221"/>
                    <Button Name="btnDisable" Content="DISABLE" HorizontalAlignment="Left" Margin="10,261,0,0" VerticalAlignment="Top"/>
                </Grid>
            </TabItem>
            <TabItem Header="Install FS-Logix">
                <Grid Background="#FFE5E5E5">
                    <Grid.ColumnDefinitions>
                        <ColumnDefinition Width="193*"/>
                        <ColumnDefinition Width="204*"/>
                    </Grid.ColumnDefinitions>
                    <Label Name="lblfslogix" Content="Select RDS server (repeat for every RDS server)" HorizontalAlignment="Left" Margin="10,10,0,0" VerticalAlignment="Top" Height="26" Width="304"/>
                    <Button Name="btnInstallFS" Content="Install FS-Logix" HorizontalAlignment="Left" Margin="10,137,0,0" VerticalAlignment="Top" Height="37" Width="100"/>
                    <ComboBox Name="HostOverview" HorizontalAlignment="Left" Margin="10,41,0,0" VerticalAlignment="Top" Width="221"/>
                </Grid>
            </TabItem>
            <TabItem Header="Import GPO">
                <Grid Background="#FFE5E5E5">
                    <Label Content="Select Domain Controller:" HorizontalAlignment="Left" Margin="10,10,0,0" VerticalAlignment="Top"/>
                    <ComboBox Name="cmbDC" HorizontalAlignment="Left" Margin="10,41,0,0" VerticalAlignment="Top" Width="221"/>
                    <Label Content="Select RDS OU:" HorizontalAlignment="Left" Margin="10,68,0,0" VerticalAlignment="Top"/>
                    <ComboBox Name="ou" HorizontalAlignment="Left" Margin="10,93,0,0" VerticalAlignment="Top" Width="221"/>
                    <Button Name="ImportGPO" Content="Link GPO" HorizontalAlignment="Left" Margin="10,130,0,0" VerticalAlignment="Top"/>
                </Grid>
            </TabItem>
        </TabControl>

    </Grid>

</Window>
"@

$XMLReader = (New-Object System.Xml.XmlNodeReader $Form)
$XMLForm = [Windows.Markup.XamlReader]::Load($XMLReader)

#Load buttons
$getUPD = $XMLForm.FindName('btnUPDBrowse')
$getFSL = $XMLForm.FindName('btnFSLOGIX')
$StartMig = $XMLForm.FindName('btnStartMig')
$install = $XMLForm.FindName('btnInstallFS')
$disable = $XMLForm.FindName('btnDisable')
$LinkGPO = $XMLForm.FindName('ImportGPO')

#Load textbox
$UPDpath = $XMLForm.FindName('txtUPDpath')
$FSLpath = $XMLForm.FindName('txtFSLOGIX')
$hosts = $XMLForm.FindName('cmbHosts')
$txtblock = $XMLForm.FindName('HostOverview')
$OUoverview = $XMLForm.FindName('ou')
$DC = $XMLForm.FindName('cmbDC')

#Clear textbox
$UPDpath.Text = ""
$FSLpath.Text = ""

[array]$listservers = Get-ADComputer -Filter 'operatingsystem -like "*server*" -and enabled -eq "true"' ` -Properties * | Select-Object -Property DNSHostName
foreach ($a in $listservers) {
$hosts.Items.Add($a.DNSHostName)
$txtblock.Items.Add($a.DNSHostName)
$DC.Items.Add($a.DNSHostName)
}

$OUs = $a = Get-ADObject -Filter { ObjectClass -eq 'organizationalunit' }
foreach ($ou in $OUs) {
$OUoverview.Items.Add($ou.DistinguishedName)
}

#Button functions:
$getUPD.add_click({
    param([String]$Description="Select Folder") 
        $objUPDForm = New-Object System.Windows.Forms.FolderBrowserDialog
        #$objForm.Rootfolder = $RootFolder
        $objUPDForm.Description = $Description
        $ShowUPD = $objUPDForm.ShowDialog()
            if ($ShowUPD -eq "OK")
                {
                    $selectedUPDFolder = $objUPDForm.SelectedPath
                    $UPDpath.Text = $selectedUPDFolder
                }
$outputUPD = $UPDpath.Text
})


$getFSL.add_click({
    param([String]$Description="Select Folder")
        $objFSLForm = New-Object System.Windows.Forms.FolderBrowserDialog
        #$objForm.Rootfolder = $RootFolder
        $objFSLForm.Description = $Description
        $ShowFSL = $objFSLForm.ShowDialog()
            if ($ShowFSL -eq "OK")
                {
                    $selectedFSLFolder = $objFSLForm.SelectedPath
                    $FSLpath.Text = $selectedFSLFolder
                }
})

$StartMig.add_click({
$outputUPD = $UPDpath.Text
$outputFSL = $FSLpath.Text

$updroot = $outputUPD
$fslogixroot = $outputFSL

$delay = 3

$errorlogfolder = $outputFSL
$errorlogfilename = "vhdxmountfailed.txt"
$errorlogresults = $errorlogfolder+'\'+$errorlogfilename

# Outputs the current HHmmss value when called. Used to prefix log and console entries
Function ThisHHmmss() {
(Get-Date).ToString("HH:mm:ss")
}

# Stop if the AD module cannot be loaded
If (!(Get-module ActiveDirectory)) {
Import-Module ActiveDirectory -ErrorAction Stop
Write-Host (ThisHHmmss) "AD PowerShell Module not found or could not be loaded" -ForegroundColor Red
}


# If the VHDX fails to mount then this function is called and there is additional code to deal with what action to take next
Function MountError ($ErrorRecord=$Error[0])
{
   $ErrorRecord | Format-List * -Force
   $ErrorRecord.InvocationInfo |Format-List *
   $Exception = $ErrorRecord.Exception
   for ($i = 0; $Exception; $i++, ($Exception = $Exception.InnerException))
   {   "$i" * 80
       $Exception |Format-List * -Force
   }
}

# Create the log folder and file for any VHDX files which fail to mount
If(!(Test-Path $errorlogfolder))
    {
    New-Item -ItemType Directory -Force -Path $fslogixroot
    Write-Host (ThisHHmmss) "Created $fslogixroot" -ForegroundColor Yellow
}
# Create file if missing
If(!(Test-Path $errorlogresults))
    {
    New-Item -Path $errorlogfolder -ItemType File -Name $errorlogfilename
    Write-Host (ThisHHmmss) "Created $errorlogresults" -ForegroundColor Yellow
}

# Create the FSLogix root path if it does not exist
If(!(Test-Path $fslogixroot))
    {
    New-Item -ItemType Directory -Force -Path $fslogixroot
}

# Index the UPD VHDX files
$files = Get-ChildItem -Path $updroot -File -Filter UVHD-S*.vhdx | Sort Name

# Convert VHDX filename AD account information and add to the array $results
ForEach ($file in $files) {
    # Obtain the SID in the filename by removing the UVHD- prefix
    $sid = ($file.Basename).Substring(5)
    If 
    (
        # Only proceed with this file if there is an AD user with this SID
        (Get-ADUser -Filter { SID -eq $sid }) -ne $null
    ) {
        # Obtain Name and SAM values from the user SID
        $userinfo = Get-ADUser -Filter { SID -eq $sid } | Select Name, SamAccountName, UserPrincipalName, SID
        $name = ($userinfo.Name).ToString()
        $sam = ($userinfo.SamAccountName).ToString()
        Write-Host (ThisHHmmss) "Processing account: $name ($sam)" -ForegroundColor Green

        # Source UPD VHDX
        $sourcevhdx = $file.FullName
        # Unique user SID_SAM user folder name to store FSLogix VHDX
        #$sam_sid = "$sid"+"_"+"$sam"
        $sam_sid = "$sam"+"_"+"$sid"
        # Full folder path to store VHDX
        $fslogixuserpath = "$fslogixroot" + "\" + "$sam_sid"

        # Mount the source VHDX and obtain the drive mapping
        Write-Host (ThisHHmmss) "Mounting VHDX: $sourcevhdx" -ForegroundColor Green
        # Stop the script is mounting fails
        Mount-DiskImage -ImagePath $sourcevhdx  -ErrorAction SilentlyContinue -ErrorVariable MountError | Out-Null;
        
        # If the VHDX failed to mount then add the filename to the error log
        If ($MountError){
        Write-Host "Failed to mount" $sourcevhdx -ForegroundColor Yellow
        Add-Content -Path $errorlogresults -Value $sourcevhdx
        }

        # Small delay to ensure VHDX has been mounted
        Write-Host (ThisHHmmss) "$delay Second delay after mounting $sourcevhdx" -ForegroundColor Green
        Start-Sleep -Seconds $delay
        # Get drive letter
        $mountletter = (Get-DiskImage -ImagePath $sourcevhdx | Get-Disk | Get-Partition).DriveLetter
        $mountpath = ($mountletter + ':\')

        # Note that the mount letter is null becauase the VHDX failed to mount
        If ($mountletter -eq $null){
            Write-Host "Path is blank" -ForegroundColor Yellow
        }

        #region mountsuccess
        If ($mountletter -ne $null){
        
            ## Create a folder called Profile in the root of the mounted VHDX
            # Define path in the profile disk
            $ProfileDir = 'Profile'
            $vhdxprofiledir = Join-Path -Path $mountpath -ChildPath $ProfileDir
            # Create path in the profile disk
            If (!(Test-Path $vhdxprofiledir)) {
                Write-Output "Create Folder: $vhdxprofiledir"
                New-Item $vhdxprofiledir -ItemType Directory | Out-Null
            } 

            ## Move the user content into the new Profile folder
            # Defining the files and folders that should not be moved
            $Excludes = @("Profile", "Uvhd-Binding", "`$RECYCLE.BIN", "System Volume Information")

            # Copy profile disk content to the new profile folder
            $Content = Get-ChildItem $mountpath -Force
            ForEach ($C in $Content) {
                If ($Excludes -notcontains $C.Name) {
                    Write-Output ('Move: ' + $C.FullName)
                    Try { Move-Item $C.FullName -Destination $vhdxprofiledir -Force -ErrorAction Stop } 
                    Catch { Write-Warning "Error: $_" }
                }

            }
       
            # Defining the registry file
            $regtext = "Windows Registry Editor Version 5.00
                [HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows NT\CurrentVersion\ProfileList\$SID]
                `"ProfileImagePath`"=`"C:\\Users\\$SAM`"
                `"Flags`"=dword:00000000
                `"State`"=dword:00000000
                `"ProfileLoadTimeLow`"=dword:00000000
                `"ProfileLoadTimeHigh`"=dword:00000000
                `"RefCount`"=dword:00000000
                `"RunLogonScriptSync`"=dword:00000001
                "

            # Create the folder and registry file
            Write-Output "Create Reg: $vhdxprofiledir\AppData\Local\FSLogix\ProfileData.reg"
            If (!(Test-Path "$vhdxprofiledir\AppData\Local\FSLogix")) {
                New-Item -Path "$vhdxprofiledir\AppData\Local\FSLogix" -ItemType directory | Out-Null
            }
            If (!(Test-Path "$vhdxprofiledir\AppData\Local\FSLogix\ProfileData.reg")) {
                $regtext | Out-File "$vhdxprofiledir\AppData\Local\FSLogix\ProfileData.reg" -Encoding ascii
            }

            # Dismount source VHDX
            Dismount-DiskImage -ImagePath $sourcevhdx
            # Small delay after dismounting the VHDX file to ensure it and the drive letter are free
            Write-Host (ThisHHmmss) "$delay Second delay after dismounting $sourcevhdx" -ForegroundColor Green
            Start-Sleep -Seconds $delay

            ### Moving and renaming the VHDX happens here ###

            # Create the new SAM_SID user folder in the FSLogix root path
            Write-Host (ThisHHmmss) "Creating new folder $fslogixuserpath" -ForegroundColor Green
            New-Item -Path $fslogixroot -Name $sam_sid -ItemType Directory | Out-Null

            # Move the source UPD VHDX to the fsLogix path
            Write-Host (ThisHHmmss) "Moving original VHDX to new FSLogix location" -ForegroundColor Green
            Move-Item -Path $sourcevhdx -Destination $fslogixuserpath

            # Rename the VHDX file from the UPD format to the fsLogix format
            $updvhdx = "$fslogixuserpath" + "\" + "$file"
            $fslogixvhdx = "Profile_" + "$sam" + ".vhdx"
            Rename-Item $updvhdx -NewName $fslogixvhdx

            # This is the full filepath of the new VHDX file
            $newUVHD = "$fslogixuserpath" + "\" + "$fslogixvhdx"

            # Update NTFS permission to give the user RW access
            & icacls $fslogixuserpath /setowner "$env:userdomain\$sam" /T /C | Out-Null
            & icacls $fslogixuserpath /grant $env:userdomain\$sam`:`(OI`)`(CI`)F /T | Out-Null
            & icacls $newUVHD /grant $env:userdomain\$sam`:`(OI`)`(CI`)F /T /inheritance:E | Out-Null

            Write-Host (ThisHHmmss) "Finished processing account $Name" -ForegroundColor Green

        }

        # Clear user variables to be safe
        Clear-Variable file, sid, userinfo, name, sam, sourcevhdx, sam_sid, fslogixuserpath, mountletter, mountpath, vhdxprofiledir, Content, regtext, updvhdx, fslogixvhdx, newUVHD
        Write-Host "#######################################################"
    }

} 


})

$disable.add_click({
$Broker = $hosts.SelectedItem
Enter-PSSession -ComputerName $Broker
$SessionCollection = Get-RDSessionCollection -ConnectionBroker $Broker
Set-RDSessionCollectionConfiguration -CollectionName $SessionCollection.CollectionName -DisableUserProfileDisk -ConnectionBroker $Broker
})

$install.add_click({
Exit-PSSession
$RDS = $txtblock.SelectedItem
Enter-PSSession -ComputerName $RDS
Start-Sleep 3
Invoke-Command -scriptblock { choco install fslogix -y}
Start-Sleep 3
Restart-Computer -ComputerName $RDS
})

$LinkGPO.add_click({
$GPO = $OUoverview.SelectedItem
$DomainDC = $DC.SelectedItem
Exit-PSSession
Enter-PSSession -ComputerName $DomainDC
$ADRootDSE = $(($env:USERDNSDOMAIN.Replace('.',',DC=')).Insert(0,'DC='))
$TemplateSourcePath = "C:\iNSTALL\GPO\Templates"
Copy-Item -Path "$TemplateSourcePath\admx\*" -Destination 'C:\Windows\PolicyDefinitions' -ErrorAction Continue -Force
Copy-Item -Path "$TemplateSourcePath\admx\en-US\*" -Destination 'C:\Windows\PolicyDefinitions\en-US' -ErrorAction Continue -Force
Copy-Item -Path "$TemplateSourcePath\admx\fr-FR\*" -Destination 'C:\Windows\PolicyDefinitions\fr-FR' -ErrorAction Continue -Force
    If ( (Get-CimInstance -NameSpace root/CIMV2 -ClassName win32_ComputerSystem).DomainRole -in ( 4 , 5 ) ) { [STRING]$DcName = 'localhost' }
        Else { [STRING]$DcName = [System.DirectoryServices.ActiveDirectory.Domain]::GetCurrentDomain().PdcRoleOwner.Name }
New-Item -Path "\\$DcName\SYSVOL\$DomainName\Policies\PolicyDefinitions" -ItemType Directory -ErrorAction Continue -Force
Copy-Item -Path 'C:\Windows\PolicyDefinitions\*' -Destination "\\$DcName\SYSVOL\$DomainName\Policies\PolicyDefinitions" -ErrorAction Continue -Force
Copy-Item -Path 'C:\Windows\PolicyDefinitions\en-US\*' -Destination "\\$DcName\SYSVOL\$DomainName\Policies\PolicyDefinitions\en-US" -ErrorAction Continue  -Force

$vhdLocation = $FSLpath.Text			

                $StandardServerFSLogixPolicy = (
				'HKLM\Software\FSLogix\Profiles,Enabled,Dword,1',
				'HKLM\Software\FSLogix\Profiles,ProfileType,Dword,0',
				'HKLM\Software\FSLogix\Profiles,SizeInMBs,Dword,51200',
				"HKLM\Software\FSLogix\Profiles,VHDLocations,String,$vhdLocation",
				'HKLM\Software\FSLogix\Profiles,VolumeType,String,VHDX',
				'HKLM\Software\FSLogix\Profiles,FlipFlopProfileDirectoryName,Dword,1'
				)


				$GpoName = 'StandardServerFSLogixPolicy_TEST3'
				New-GPO -Server $DomainDC -Name $GpoName -ErrorAction Ignore
				New-GPLink -Server $DomainDC -Name "$GpoName" -Target "$GPO" -ErrorAction Continue
                Push-Location 'C:\Install\GPO'
                New-Item -ItemType Directory -Force -Path '{049AD0DA-164D-4B1A-BFC8-6A6757A03FAA}\DomainSysvol\GPO\User' , '{049AD0DA-164D-4B1A-BFC8-6A6757A03FAA}\DomainSysvol\GPO\Machine\Scripts\Shutdown' , '{049AD0DA-164D-4B1A-BFC8-6A6757A03FAA}\DomainSysvol\GPO\Machine\Scripts\Startup' , '{049AD0DA-164D-4B1A-BFC8-6A6757A03FAA}\DomainSysvol\GPO\Machine\microsoft\windows nt\SecEdit'
                $GptTmpl = @"
[Unicode]
Unicode=yes
[Version]
signature="$('$')CHICAGO$('$')"
Revision=1
[Group Membership]
FSLogix Profile Include List__Memberof =
FSLogix Profile Include List__Members = FSLogix-Users
"@
                $GptTmpl | Out-File -FilePath '{049AD0DA-164D-4B1A-BFC8-6A6757A03FAA}\DomainSysvol\GPO\Machine\microsoft\windows nt\SecEdit\GptTmpl.inf'-Encoding ascii -Force
                $BackupXML = @'
<?xml version="1.0" encoding="utf-8"?><!-- Copyright (c) Microsoft Corporation.  All rights reserved. -->
<GroupPolicyBackupScheme bkp:version="2.0" bkp:type="GroupPolicyBackupTemplate" xmlns:bkp="http://www.microsoft.com/GroupPolicy/GPOOperations" xmlns="http://www.microsoft.com/GroupPolicy/GPOOperations">
<GroupPolicyObject>
<SecurityGroups><Group><Sid/><SamAccountName><![CDATA[FSLogix Profile Include List]]></SamAccountName><Type><![CDATA[Unknown]]></Type><NetBIOSDomainName/><DnsDomainName/><UPN/></Group><Group><Sid/><SamAccountName><![CDATA[FSLogix-Users]]></SamAccountName><Type><![CDATA[Unknown]]></Type><NetBIOSDomainName/><DnsDomainName/><UPN/></Group><Group bkp:Source="FromDACL"><Sid><![CDATA[S-1-5-21-1458650225-1119023680-1635465439-519]]></Sid><SamAccountName><![CDATA[Enterprise Admins]]></SamAccountName><Type><![CDATA[UniversalGroup]]></Type><NetBIOSDomainName><![CDATA[ClearMedia]]></NetBIOSDomainName><DnsDomainName><![CDATA[ClearMedia.cloud]]></DnsDomainName><UPN><![CDATA[Enterprise Admins@ClearMedia.cloud]]></UPN></Group><Group bkp:Source="FromDACL"><Sid><![CDATA[S-1-5-21-1458650225-1119023680-1635465439-512]]></Sid><SamAccountName><![CDATA[Domain Admins]]></SamAccountName><Type><![CDATA[GlobalGroup]]></Type><NetBIOSDomainName><![CDATA[ClearMedia]]></NetBIOSDomainName><DnsDomainName><![CDATA[ClearMedia.cloud]]></DnsDomainName><UPN><![CDATA[Domain Admins@ClearMedia.cloud]]></UPN></Group></SecurityGroups><FilePaths/><GroupPolicyCoreSettings><ID><![CDATA[{7FF64648-7C3F-4A80-A967-B9BBA2A17DD8}]]></ID><Domain><![CDATA[ClearMedia.cloud]]></Domain><SecurityDescriptor>01 00 04 9c 00 00 00 00 00 00 00 00 00 00 00 00 14 00 00 00 04 00 ec 00 08 00 00 00 05 02 28 00 00 01 00 00 01 00 00 00 8f fd ac ed b3 ff d1 11 b4 1d 00 a0 c9 68 f9 39 01 01 00 00 00 00 00 05 0b 00 00 00 00 00 24 00 ff 00 0f 00 01 05 00 00 00 00 00 05 15 00 00 00 71 3c f1 56 40 f2 b2 42 df 38 7b 61 00 02 00 00 00 02 24 00 ff 00 0f 00 01 05 00 00 00 00 00 05 15 00 00 00 71 3c f1 56 40 f2 b2 42 df 38 7b 61 00 02 00 00 00 02 24 00 ff 00 0f 00 01 05 00 00 00 00 00 05 15 00 00 00 71 3c f1 56 40 f2 b2 42 df 38 7b 61 07 02 00 00 00 02 14 00 94 00 02 00 01 01 00 00 00 00 00 05 09 00 00 00 00 02 14 00 94 00 02 00 01 01 00 00 00 00 00 05 0b 00 00 00 00 02 14 00 ff 00 0f 00 01 01 00 00 00 00 00 05 12 00 00 00 00 0a 14 00 ff 00 0f 00 01 01 00 00 00 00 00 03 00 00 00 00</SecurityDescriptor><DisplayName><![CDATA[FSLogixRestrictedGroups]]></DisplayName><Options><![CDATA[1]]></Options><UserVersionNumber><![CDATA[0]]></UserVersionNumber><MachineVersionNumber><![CDATA[65537]]></MachineVersionNumber><MachineExtensionGuids><![CDATA[[{827D319E-6EAC-11D2-A4EA-00C04F79F83A}{803E14A0-B4FB-11D0-A0D0-00A0C90F574B}]]]></MachineExtensionGuids><UserExtensionGuids/><WMIFilter/></GroupPolicyCoreSettings> 
<GroupPolicyExtension bkp:ID="{35378EAC-683F-11D2-A89A-00C04FBBCFA2}" bkp:DescName="Registry"><FSObjectFile bkp:Path="%GPO_FSPATH%\Adm\*.*" bkp:SourceExpandedPath="\\DC.ClearMedia.cloud\sysvol\ClearMedia.cloud\Policies\{7FF64648-7C3F-4A80-A967-B9BBA2A17DD8}\Adm\*.*"/></GroupPolicyExtension>
<GroupPolicyExtension bkp:ID="{827D319E-6EAC-11D2-A4EA-00C04F79F83A}" bkp:DescName="Security"><FSObjectFile bkp:Path="%GPO_MACH_FSPATH%\microsoft\windows nt\SecEdit\GptTmpl.inf" bkp:SourceExpandedPath="\\DC.ClearMedia.cloud\sysvol\ClearMedia.cloud\Policies\{7FF64648-7C3F-4A80-A967-B9BBA2A17DD8}\Machine\microsoft\windows nt\SecEdit\GptTmpl.inf" bkp:ReEvaluateFunction="SecurityValidateSettings" bkp:Location="DomainSysvol\GPO\Machine\microsoft\windows nt\SecEdit\GptTmpl.inf"/></GroupPolicyExtension>
<GroupPolicyExtension bkp:ID="{F15C46CD-82A0-4C2D-A210-5D0D3182A418}" bkp:DescName="Unknown Extension"><FSObjectDir bkp:Path="%GPO_MACH_FSPATH%\Microsoft" bkp:SourceExpandedPath="\\DC.ClearMedia.cloud\sysvol\ClearMedia.cloud\Policies\{7FF64648-7C3F-4A80-A967-B9BBA2A17DD8}\Machine\Microsoft" bkp:Location="DomainSysvol\GPO\Machine\Microsoft"/><FSObjectDir bkp:Path="%GPO_MACH_FSPATH%\Microsoft\Windows NT" bkp:SourceExpandedPath="\\DC.ClearMedia.cloud\sysvol\ClearMedia.cloud\Policies\{7FF64648-7C3F-4A80-A967-B9BBA2A17DD8}\Machine\Microsoft\Windows NT" bkp:Location="DomainSysvol\GPO\Machine\Microsoft\Windows NT"/><FSObjectDir bkp:Path="%GPO_MACH_FSPATH%\Microsoft\Windows NT\SecEdit" bkp:SourceExpandedPath="\\DC.ClearMedia.cloud\sysvol\ClearMedia.cloud\Policies\{7FF64648-7C3F-4A80-A967-B9BBA2A17DD8}\Machine\Microsoft\Windows NT\SecEdit" bkp:Location="DomainSysvol\GPO\Machine\Microsoft\Windows NT\SecEdit"/><FSObjectDir bkp:Path="%GPO_MACH_FSPATH%\Scripts" bkp:SourceExpandedPath="\\DC.ClearMedia.cloud\sysvol\ClearMedia.cloud\Policies\{7FF64648-7C3F-4A80-A967-B9BBA2A17DD8}\Machine\Scripts" bkp:Location="DomainSysvol\GPO\Machine\Scripts"/><FSObjectDir bkp:Path="%GPO_MACH_FSPATH%\Scripts\Shutdown" bkp:SourceExpandedPath="\\DC.ClearMedia.cloud\sysvol\ClearMedia.cloud\Policies\{7FF64648-7C3F-4A80-A967-B9BBA2A17DD8}\Machine\Scripts\Shutdown" bkp:Location="DomainSysvol\GPO\Machine\Scripts\Shutdown"/><FSObjectDir bkp:Path="%GPO_MACH_FSPATH%\Scripts\Startup" bkp:SourceExpandedPath="\\DC.ClearMedia.cloud\sysvol\ClearMedia.cloud\Policies\{7FF64648-7C3F-4A80-A967-B9BBA2A17DD8}\Machine\Scripts\Startup" bkp:Location="DomainSysvol\GPO\Machine\Scripts\Startup"/></GroupPolicyExtension>
</GroupPolicyObject>
</GroupPolicyBackupScheme>
'@
                $BackupXML | Out-File -FilePath '{049AD0DA-164D-4B1A-BFC8-6A6757A03FAA}\Backup.xml' -Encoding ascii -Force
                $bkupInfoXML = @'
<BackupInst xmlns="http://www.microsoft.com/GroupPolicy/GPOOperations/Manifest"><GPOGuid><![CDATA[{7FF64648-7C3F-4A80-A967-B9BBA2A17DD8}]]></GPOGuid><GPODomain><![CDATA[ClearMedia.cloud]]></GPODomain><GPODomainGuid><![CDATA[{b591e442-9b2a-4b3f-8572-3e3ceba3477c}]]></GPODomainGuid><GPODomainController><![CDATA[DC.ClearMedia.cloud]]></GPODomainController><BackupTime><![CDATA[2022-03-10T12:21:53]]></BackupTime><ID><![CDATA[{049AD0DA-164D-4B1A-BFC8-6A6757A03FAA}]]></ID><Comment><![CDATA[]]></Comment><GPODisplayName><![CDATA[FSLogixRestrictedGroups]]></GPODisplayName></BackupInst>
'@
                $bkupInfoXML | Out-File -FilePath '{049AD0DA-164D-4B1A-BFC8-6A6757A03FAA}\bkupInfo.xml' -Encoding ascii -Force
                Import-GPO -BackupGpoName FSLogixRestrictedGroups -Path C:\Install\GPO -TargetName $GpoName -CreateIfNeeded

				
                    $StandardServerFSLogixPolicy | ForEach-Object {
					$Table = $_.Split(',')
					If ( $Table[2] -eq 'Dword' ) { [INT]$Value = $Table[3] } Else { [STRING]$Value = $Table[3] }
					Set-GPRegistryValue -Server $DomainDC -Name "$GpoName" -Key $Table[0] -ValueName $Table[1] -Type $Table[2] -Value $Value  -ErrorAction Continue
					}
})


#Show XMLform
$XMLForm.ShowDialog() | Out-Null
