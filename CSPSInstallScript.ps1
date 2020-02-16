#Global vars:
$user = $Env:UserName
$userpath = "C:\Users\$user\Desktop"
$DownloadLocation = "https://aka.ms/unifiedinstaller"

#Disable Windows update as it bogs down the system for smaller VMs in my experience.

Write-Output "Disabling Windows Updates because of performance problems."
$Service = Get-Service -Name "Windows Update"
$Service | Set-Service -StartupType Manual
$Service | Stop-Service

Write-Output "Installing Azure Powershell."
#Get Vault credentials
Install-Packageprovider -name Nuget -Force
Install-Module az -Force

Write-Output "Authenticating to Azure Powershell."
#Have to import a cert: https://docs.microsoft.com/en-us/powershell/azure/authenticate-azureps?view=azps-3.4.0
$storeName = [System.Security.Cryptography.X509Certificates.StoreName]::My 
$storeLocation = [System.Security.Cryptography.X509Certificates.StoreLocation]::CurrentUser 
$store = [System.Security.Cryptography.X509Certificates.X509Store]::new($storeName, $storeLocation) 
$certPath = "$userpath\service-principal.pfx"
$flag = [System.Security.Cryptography.X509Certificates.X509KeyStorageFlags]::Exportable 

#Set up a way to programmatically grab the certificate password later ------------------------------------------------------
$certificate = [System.Security.Cryptography.X509Certificates.X509Certificate2]::new($certPath, "certpass", $flag)

$store.Open([System.Security.Cryptography.X509Certificates.OpenFlags]::ReadWrite) 
$store.Add($Certificate) 
$store.Close()

#Going to have ansible drop a file with the required variables onto the source machine
$sp_file = Get-Content "$userpath\Authitems.txt"
$appid = $sp_file[0]
$tid = $sp_file[1]
$thumbprint = $sp_file[2]
$vault_name = $sp_file[3]

Connect-AzAccount -ApplicationId $appid -TenantId $tid -CertificateThumbprint $thumbprint

Write-output "Authenticating to Recovery Services Vault"
Get-AzRecoveryServicesVault -name $vault_name
$vault | set-AzRecoveryServicesAsrVaultContext

#The Vaultsettingsfile cmdlet has strange behavior. Found this workaround here: https://github.com/Azure/azure-powershell/issues/8885
$dt = $(Get-Date).ToString("M-d-yyyy")
$cert = New-SelfSignedCertificate -DnsName $($vault.Name+$subscriptionid+'-'+$dt+'-vaultcredentials') -CertStoreLocation cert:\CurrentUser\My -NotAfter $(Get-Date).AddHours(2)
$certficate = [Convert]::ToBase64String($cert.RawData)

$credential = Get-AzRecoveryServicesVaultSettingsFile -SiteRecovery -Vault $vault -Certificate $certficate.ToString() -Path "$userpath"

Write-output "Authenticated. Beginning install section."
#Starting the actual install section now.

$start_time = Get-Date

#Download Unified Installer

Write-Output "Starting download at $start_Time"
$client = New-object System.Net.WebClient
$client.DownloadFile("https://aka.ms/unifiedinstaller", "C:\Users\$user\Desktop\UnifiedInstaller.exe")
$finish_time = Get-Date
Write-Output "Finished Unified Installer download at $Finish_Time"
$file = Get-item "C:\Users\$user\Desktop\UnifiedInstaller.exe"
$filesize_mb = ($file.length/1MB)
$download_time = ($finish_time-$start_time)
$download_speed = $filesize_mb/(($download_time.Minutes*60) + ($download_time.Seconds))
$download_speed = [math]::Round($download_speed,2)
write-output "Download speed: $Download_speed/ MB/s"
#No silent switch or unattended install on Unified Installer, so going to try and extract the components then do them one by one. The example in the docs does not work.
mkdir installer
cmd.exe /c "C:\Users\$user\Desktop\UnifiedInstaller /q /x:C:\Users\$user\Desktop\installer"
#Create Mysql cred file: Couldn't think of an easy way to check if the right formatted file exists so just change it here if you want.
Add-Content "C:\Users\$user\Desktop\MySQLCredFile" "[MySQLCredentials]"
Add-Content  C:\Users\$user\Desktop\MySQLCredFile 'MySQLRootPassword = "root12345!"'
Add-Content  C:\Users\$user\Desktop\MySQLCredFile 'MySQLUserPassword = "password12345!"'
invoke-expression "C:\Users\$user\Desktop\installer\MARSAgentInstaller.exe /q"
invoke-expression "$userpath\installer\UnifiedSetup.exe /AcceptThirdpartyEULA /servermode 'CS' /InstallLocation 'F:\' /MySQLCredsFilePath '$userpath\MySQLCredfile' /VaultCredsFilePath '$credential.Filepath' /EnvType 'NonVMware'"

