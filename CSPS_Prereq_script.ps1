Function Write-Log($logmessage)
    {
    $logpath = "C:\Temp\csps_unattended.log"
    $timestamp = Get-Date -Format "MM-dd-yyyy hh:mm:ss"
    Write-Host $timestamp + " : " + $LogMessage
    $output = "$timestamp : $LogMessage"
    $output | add-content $logpath
    }

Function Get-AuthInfo($setup_path)
    {
    $sp_file = Get-Content "$setup_path\Authitems.txt" | Where { $_ } 
    $appid = $sp_file[0] 
    $tid = $sp_file[1] 
    $vault_name = $sp_file[2] 
    $subscription_id = $sp_file[3] 
    $thumbprint = $certificate.Thumbprint
    $certpass = $sp_file[4]
    $storeName = [System.Security.Cryptography.X509Certificates.StoreName]::My 
    $storeLocation = [System.Security.Cryptography.X509Certificates.StoreLocation]::CurrentUser 
    $store = [System.Security.Cryptography.X509Certificates.X509Store]::new($storeName, $storeLocation) 
    $certPath = "$setup_path\service-principal.pfx" 
    $flag = [System.Security.Cryptography.X509Certificates.X509KeyStorageFlags]::Exportable 
    $certificate = [System.Security.Cryptography.X509Certificates.X509Certificate2]::new($certPath, $certpass, $flag) 
    $store.Open([System.Security.Cryptography.X509Certificates.OpenFlags]::ReadWrite) 
    $store.Add($Certificate) 
    $store.Close() 
    $authinfo = @{appid = $appid; 
                tid = $tid; 
                vault_name = $vault_name; 
                subscription_id = $subscription_id;
                certificate = $certificate;
                thumbprint = $certificate.thumbprint;
                certpass = $certpass}
    #Have to import a cert: https://docs.microsoft.com/en-us/powershell/azure/authenticate-azureps?view=azps-3.4.0
    
    return $authinfo;
    }

Function Download-Installer($setup_path)
    {
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
    }

Function CSPSRequiresUpgrade($SetupPath, $authinfo)
    {
    $logpath = "C:\Temp\csps_unattended.log" 
    $setup_path = "C:\temp\csps_install_package"
    Write-Log("Installing Az Powershell module, if it isn't already installed.")
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
        <#$sp_file = Get-Content "$setup_path\Authitems.txt" | Where { $_ } 
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
        $thumbprint = $certificate.Thumbprint #>
        $vault = Get-AzRecoveryServicesVault -name $authitems.vault_name 
        if ($Vault -eq $null)
        {
            Write-log("May not be connected to Azure powershell. Trying to connect...")
            $subscription = Get-AzSubscription | Where {$_.Id -eq $authitems.subscription_id}
            if ($subscription -eq $null)
            {
                Write-Log("Unable to connect to subscription. Trying to connect to that.")
                Try
                {
                    Connect-AzAccount -ApplicationId $authitems.appid -TenantId $authitems.tid -CertificateThumbprint $authitems.thumbprint 
                }
                Catch
                {
                    Write-Log("Unable to connect to AZ account. Exiting.")
                    Exit
                }
                
            }
        }
        Write-Log("Connected to Azure account.") 
        #Connect-AzAccount -ApplicationId $appid -TenantId $tid -CertificateThumbprint $thumbprint 
        $vault = Get-AzRecoveryServicesVault -name $authinfo.vault_name 
        $vault | set-AzRecoveryServicesAsrVaultContext
        $hostname = $hostname
        $Fabric = Get-AzRecoveryServicesAsrFabric | Where {$_.FriendlyName -eq $hostname}
        
        #Break if it can't even find the fabric, probably a first setup.
        if ($Fabric -eq $null)
        {
            return 1;
        }
        if ($fabric.FabricSpecificDetails.VersionStatus -eq "UpdateRequired")
        {
            return 1;
        }
        else
        {
            return 0;
        }
        
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
$disk = Get-Disk | Where {$_.PartitionStyle -eq "RAW"} 
$disk | Initialize-Disk -PartitionStyle MBR 
$disk | New-Partition -DriveLetter "F" -UseMaximumSize | Format-Volume -FileSystem NTFS -NewFileSystemLabel "ASR_Disk" -Confirm:$false
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
$authinfo = Get-AuthInfo($Setup_Path)
<#$sp_file = Get-Content "$setup_path\Authitems.txt" | Where { $_ } 
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
Going to have ansible drop a file with the required variables onto the source machine
$sp_file = Get-Content "$setup_path\Authitems.txt" | Where { $_ } 
$appid = $sp_file[0] 
$tid = $sp_file[1] 
$vault_name = $sp_file[2] 
$subscription_id = $sp_file[3] 
$thumbprint = $certificate.Thumbprint 
#>
Write-Log("Connecting to Azure account.") 
Connect-AzAccount -ApplicationId $authinfo.appid -TenantId $authinfo.tid -CertificateThumbprint $authinfo.Certificate.Thumbprint 
$vault = Get-AzRecoveryServicesVault -name $authinfo.vault_name 
$vault | set-AzRecoveryServicesAsrVaultContext 

Write-Log("Making self-signed cert for vault credentials.")
#The Vaultsettingsfile cmdlet has strange behavior. Found this workaround here: https://github.com/Azure/azure-powershell/issues/8885 but that didn't work, figured this one out:
$dt = $(Get-Date).ToString("M-d-yyyy") 
$cert = New-SelfSignedCertificate -CertStoreLocation Cert:\CurrentUser\My -FriendlyName 'test-vaultcredentials' -subject "Windows Azure Tools" -KeyExportPolicy Exportable -NotAfter $(Get-Date).AddHours(48) -NotBefore $(Get-Date).AddHours(-24) -KeyProtection None -KeyUsage None -TextExtension @("2.5.29.37={text}1.3.6.1.5.5.7.3.2") -Provider "Microsoft Enhanced Cryptographic Provider v1.0" 
$certificate = [convert]::ToBase64String($cert.Export([System.Security.Cryptography.X509Certificates.X509ContentType]::Pfx)) 

Write-Log("Grabbing vault credentials.") 
$credential = Get-AzRecoveryServicesVaultSettingsFile -SiteRecovery -Vault $vault -Certificate $certificate.ToString() -Path "$setup_path"

#Powershell is stupid and returns the entire output stream of a function. I'll fix it later. Expected behavior is that the real return value is the last in the array, so, [-1]
$UpgradeRequired = CSPSRequiresUpgrade($SetupPath)

#Start actual download, if $upgradeRequired -eq True
if ($UpgradeRequired[-1] -eq 1)
    {
    Download-Installer($Setup_Path)
    "UpgradeRequired" | out-file $SetupPath\UpgradeRequired.txt
    #Create Mysql cred file: Couldn't think of an easy way to check if the right formatted file exists so just change it here if you want.
    Add-Content "$setup_path\MySQLCredFile" "[MySQLCredentials]" 
    Add-Content $setup_path\MySQLCredFile 'MySQLRootPassword = "root12345!"' 
    Add-Content $setup_path\MySQLCredFile 'MySQLUserPassword = "password12345!"'
    #Writing down the path for the vault creds, since we don't know what it's going to be named.
    $credentialpath = $credential.FilePath.ToString(); 
    Add-Content $Setup_Path\VaultCred.txt $credentialpath
    }
else
    {
    "UpgradeNotRequired" | out-file $SetupPath\UpgradeRequired.txt
    Return 0;
    }


