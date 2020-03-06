Function Write-Log($logmessage)
    {
    $logpath = "C:\Temp\csps_unattended.log"
    $timestamp = Get-Date -Format "MM-dd-yyyy hh:mm:ss"
    Write-Host $timestamp + " : " + $LogMessage
    $output = "$timestamp : $LogMessage"
    $output | add-content $logpath
    }
Write-Log("Starting execution of script.")
#Global vars:
$logpath = "C:\Temp\csps_unattended.log" 
$setup_path = "C:\temp\csps_install_package"
#$user = $Env:UserName $userpath = "C:\Users\$user\Desktop"
$DownloadLocation = "https://aka.ms/unifiedinstaller" 
Write-Log("Starting VDS.")
#Make sure VDS is running before we do any of this.
$vds = Get-Service "Virtual Disk" 
while ($vds.Status -ne "Running")
    {
    if ($vds.Status -eq "Stopped")
        {
        Start-Service $vds
        }
    start-sleep -s 5
    $vds = Get-Service "Virtual Disk"
    }
$disk = Get-Disk | Where {$_.PartitionStyle -eq "RAW"} $disk | Initialize-Disk -PartitionStyle MBR $disk | New-Partition -DriveLetter "F" -UseMaximumSize Format-Volume -DriveLetter "F" -FileSystem NTFS -NewFileSystemLabel "ASR_Disk" -Confirm:$false
#Put Windows update to Manual as it bogs down the system for smaller VMs in my experience.
Write-Log("Setting Windows Update to manual.") 
$Service = Get-Service -Name "Windows Update" 
$Service | Set-Service -StartupType Manual 
$Service | Stop-Service 
Write-Log("Installing Az Powershell 
module, if it isn't already installed.")
#Get Vault credentials. Check to see if az powershell is installed.
Try
    {
    $az_module = Get-InstalledModule -name Az -ErrorAction Stop
    }
Catch
    {
    Write-Output "Unable to find AZ module, trying to install."
    Install-Packageprovider -name Nuget -Force
    Install-Module az -Force
    }
Write-Log("Importing certificate for AZ powershell use.")
$sp_file = Get-Content "$setup_path\Authitems.txt" | Where { $_ } 
$certpass = $sp_file[4]
#Have to import a cert: https://docs.microsoft.com/en-us/powershell/azure/authenticate-azureps?view=azps-3.4.0
$storeName = [System.Security.Cryptography.X509Certificates.StoreName]::My 
$storeLocation = [System.Security.Cryptography.X509Certificates.StoreLocation]::CurrentUser 
$store = [System.Security.Cryptography.X509Certificates.X509Store]::new($storeName, $storeLocation) 
$certPath = "$setup_path\service-principal.pfx" 
$flag = [System.Security.Cryptography.X509Certificates.X509KeyStorageFlags]::Exportable 
$certificate = [System.Security.Cryptography.X509Certificates.X509Certificate2]::new($certPath, $certpass, $flag) 
$store.Open([System.Security.Cryptography.X509Certificates.OpenFlags]::ReadWrite) 
$store.Add($Certificate) 
$store.Close() 
Write-log("Grabbing authentication info.")
#Going to have ansible drop a file with the required variables onto the source machine
$sp_file = Get-Content "$setup_path\Authitems.txt" | Where { $_ } 
$appid = $sp_file[0] 
$tid = $sp_file[1] 
$vault_name = $sp_file[2] 
$subscription_id = $sp_file[3] 
$thumbprint = $certificate.Thumbprint 
Write-Log("Connecting to Azure account.") 
Connect-AzAccount -ApplicationId $appid -TenantId $tid -CertificateThumbprint $certificate.Thumbprint 
$vault = Get-AzRecoveryServicesVault -name $vault_name $vault | set-AzRecoveryServicesAsrVaultContext 
Write-Log("Making self-signed cert for vault credentials.")
#The Vaultsettingsfile cmdlet has strange behavior. Found this workaround here: https://github.com/Azure/azure-powershell/issues/8885 but that didn't work, figured this one out:
$dt = $(Get-Date).ToString("M-d-yyyy") 
$cert = New-SelfSignedCertificate -CertStoreLocation Cert:\CurrentUser\My -FriendlyName 'test-vaultcredentials' -subject "Windows Azure Tools" -KeyExportPolicy xportable -NotAfter $(Get-Date).AddHours(48) -NotBefore $(Get-Date).AddHours(-24) -KeyProtection None -KeyUsage None -TextExtension @("2.5.29.37={text}1.3.6.1.5.5.7.3.2") -Provider "Microsoft Enhanced Cryptographic Provider v1.0" $certficate = [convert]::ToBase64String($cert.Export([System.Security.Cryptography.X509Certificates.X509ContentType]::Pfx)) 
Write-Log("Grabbing vault credentials.") 
$credential = Get-AzRecoveryServicesVaultSettingsFile -SiteRecovery -Vault $vault -Certificate $certficate.ToString() -Path "$setup_path"
#Starting the actual install section now.
$start_time = Get-Date
#Download Unified Installer
Write-Log("Starting download at $start_Time") 
$client = New-object System.Net.WebClient 
$client.DownloadFile("https://aka.ms/unifiedinstaller", "$setup_path\UnifiedInstaller.exe") 
$finish_time = Get-Date 
Write-Log("Finished Unified Installer download at $Finish_Time") 
$file = Get-item "$setup_path\UnifiedInstaller.exe" $filesize_mb = ($file.length/1MB) 
$download_time = ($finish_time-$start_time) 
$download_speed = $filesize_mb/(($download_time.Minutes*60) + ($download_time.Seconds)) 
$download_speed = [math]::Round($download_speed,2) 
write-log("Download speed: $Download_speed/ MB/s")
#Finished downloading, now extract the installer.
Write-Log("Extracting installer.") 
mkdir installer cmd.exe /c "$setup_path\UnifiedInstaller /q /x:$setup_path\installer"
#Create Mysql cred file: Couldn't think of an easy way to check if the right formatted file exists so just change it here if you want.
Add-Content "$setup_path\MySQLCredFile" "[MySQLCredentials]" 
Add-Content $setup_path\MySQLCredFile 'MySQLRootPassword = "root12345!"' 
Add-Content $setup_path\MySQLCredFile 'MySQLUserPassword = "password12345!"'
#Kicking off the actual install.
$credentialpath = $credential.FilePath.ToString(); 
Write-Log("Starting installation...") 
invoke-expression "$setup_path\installer\UnifiedSetup.exe /AcceptThirdpartyEULA /servermode 'CS' /InstallLocation 'F:\' /MySQLCredsFilePath '$setup_path\MySQLCredfile' /VaultCredsFilePath '$credentialpath' /EnvType 'NonVMware'"
#Find policies. If they don't exist, create them.
Write-Log("Find policies. If they don't exist, create them.") 
try {
    $Rep_Policy = Get-AzRecoveryServicesAsrPolicy -Name "DefaultReplicationPolicy"
    }
catch
    {
    Write-Log("No policy found. Creating...")
    $Create_PolicyJob = New-AzRecoveryServicesASrPolicy -VMwareToAzure -Name "LabReplicationPolicy" -RecoveryPointRetentionInHours 6 -ApplicationConsistentSnapshotFrequencyInHours 6 -POWarningThresholdInMinutes 120
    while ($Create_PolicyJob.State -eq "InProgress")
        {
        Start-sleep 10
        $Create_policyJob = Get-ASRJob -Job $Create_PolicyJob
        }
    }
try {
    $Failback_Policy = Get-AzRecoveryServicesAsrPolicy -Name "DefaultFailbackReplicationPolicy"
    }
catch
    {
    Write-Log("No failback policy found. Creating...")
    $Create_FailbackPolicyJob = New-AzRecoveryServicesASrPolicy -AzuretoVmware -Name "LabFailbackReplicationPolicy" -RecoveryPointRetentionInHours 6 -ApplicationConsistentSnapshotFrequencyInHours 6 -RPOWarningThresholdInMinutes 120
    while ($Create_PolicyJob.State -eq "InProgress")
        {
        Start-sleep 10
        $Create_FailbackpolicyJob = Get-ASRJob -Job $Create_FailbackpolicyJob
        }
    }
$Hostname = hostname $Fabric = Get-AzRecoveryServicesASRFabric | Where {$_.FriendlyName -eq $Hostname} 
$pc_name = $hostname + "_protectioncontainer" 
$Protection_Container = Get-AzRecoveryServicesAsrProtectionContainer -Fabric $fabric
#Probably will pass the replicated item info in a file like with the auth info, later.
$Replicated_item = New-AzRecoveryServicesASRProtectableItem -ProtectionContainer $protection_container -FriendlyName "Ubuntu_Replicated" -IPAddress "192.168.1.5" -OSType Linux while 
($Replicated_item.State -eq "InProgress")
    {
    Start-Sleep -Seconds 5
    $Replicated_Item = Get-ASRJob -Job $Replicated_item
    }
#Map REplication policy to container
Write-Log("Map REplication policy to container") 
$PolicyMap = Get-AzRecoveryServicesAsrProtectionContainerMapping -ProtectionContainer $Protection_Container
#Associate policy with CS/PS
$Associate = New-AzREcoveryServicesASrProtectionContainerMapping -Name "PolicyAssociation" -PrimaryProtectionContainer $Protection_Container -Policy $policy 
while ($associate.State -eq "InProgress")
    {
    start-sleep -s 5
    $Assocate = Get-AsrJob -Job $Associate
    }
#Get process server
$PS = $Fabric.FabricSpecificDetails.ProcessServers[0]
#Get Failover resource group, Vnet, Subnet
$RG = Get-AzREsourceGroup -Name "CSPSTest_Group" $Vnet = Get-AzVirtualNetwork -Name "csps_testvnet" $subnet_name = "csps_subnet" $Storage_account = Get-AzStorageAccount -name "cspstestgroupdiag" -ResourceGroupName "CSPSTest_Group" Write-Log("Add runas account to mysql.")
#Add runas account. Wait until it's updated in the fabric.
& mysql -u root -proot12345! "svsdb1" -e "source $userpath\runasaccount.sql" 
$Fabric = Get-AzRecoveryServicesASRFabric | Where {$_.FriendlyName -eq $Hostname} 
while ($Fabric.FabricSpecificDetails.RunAsAccounts -eq $null)
    {
    start-sleep -s 5
    $Fabric = Get-AzRecoveryServicesASRFabric | Where {$_.FriendlyName -eq $Hostname}
    }
$Runas_Account = $Fabric.FabricSpecificDetails.RunAsAccounts[0]
#Enable-Replication
$Protectable_Item = Get-AzRecoveryServicesAsrProtectableItem -ProtectionContainer $Protection_Container 
Write-Log("Enabling replication.")
#Change index on protectable_item. Just fo rtesting right now.
$Enable_Job = New-AzRecoveryServicesAsrReplicationProtectedItem -VMwareToAzure -Name "repubuntu_A5KfUR" -LogStorageAccountId $Storage_account.Id -ProtectableItem $Protectable_Item[1] -DiskType "Standard_LRS" -ProtectionContainerMapping $PolicyMap -ProcessServer $PS -Account $Runas_Account -RecoveryResourceGroupId $RG.ResourceId -RecoveryAzureNetworkId $Vnet.Id -RecoveryAzureSubnetName $subnet_name -RecoveryVmName "Ubuntufailover"
