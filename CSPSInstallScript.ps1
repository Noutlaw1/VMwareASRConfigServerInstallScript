#Documentation link: https://docs.microsoft.com/en-us/azure/site-recovery/physical-manage-configuration-server
#Global vars:
$user = $Env:UserName
$userpath = "C:\Users\$user\Desktop"
$DownloadLocation = "https://aka.ms/unifiedinstaller"

#NOTE ON THE VAULT CREDENTIALS: Will likely have to send those via ansible to avoid having to authenticate to Azure on every machine you install via Powershell. So, that will change.

#Disable Windows update as it bogs down the system for smaller VMs in my experience.

Write-Output "Disabling Windows Updates because of performance problems on these smaller Azure Vms."
$Service = Get-Service -Name "Windows Update"
$Service | Set-Service -StartupType Disabled
$Service | Stop-Service

$start_time = Get-Date

#Download Unified Installer

Write-Output "Starting download at $start_Time"
$client = New-object System.Net.WebClient
$client.DownloadFile("https://aka.ms/unifiedinstaller", "C:\Users\$user\Desktop\UnifiedInstaller.exe")

#Calculate download speed for fun.
$finish_time = Get-Date
Write-Output "Finished Unified Installer download at $Finish_Time"
$file = Get-item "C:\Users\$user\Desktop\UnifiedInstaller.exe"
$filesize_mb = ($file.length/1MB)
$download_time = ($finish_time-$start_time)
$download_speed = $filesize_mb/(($download_time.Minutes*60) + ($download_time.Seconds))
$download_speed = [math]::Round($download_speed,2)
write-output "Download speed: $Download_speed/ MB/s"

#No silent switch or unattended install on Unified Installer, so going to try and extract the components then do them one by one.

mkdir $userpath\installer
#Create Mysql cred file: Couldn't think of an easy way to check if the right formatted file exists so just change it here if you want.
Write-Output "Creating MySQL Credentials file."
Add-Content "C:\Users\$user\Desktop\MySQLCredFile" "[MySQLCredentials]"
Add-Content  C:\Users\$user\Desktop\MySQLCredFile 'MySQLRootPassword = "root12345!"'
Add-Content  C:\Users\$user\Desktop\MySQLCredFile 'MySQLUserPassword = "password12345!"'

#I think we'll need this IP later for PS setup.
$ip=Get-NetIPAddress | Where {$_.InterfaceAlias -eq "Ethernet"}| Where {$_.AddressFamily -eq "IPv4"}

#Run the installer.
./unifiedsetup.exe /AcceptThirdPartyEULA /Servermode CS /InstallLocation "F:\" /EnvType NOnVMWare /MySQLCredsFilePath "C:\Users\$user\Desktop\MySQLCredFile" /VaultCredsFilePath "<Vault Credential File Path>'
