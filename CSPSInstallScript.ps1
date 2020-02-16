#Global vars:
$user = $Env:UserName
$userpath = "C:\Users\$user\Desktop"
$DownloadLocation = "https://aka.ms/unifiedinstaller"

#Disable Windows update as it bogs down the system for smaller VMs in my experience.

Write-Output "Setting Windows Updates to manual because of performance problems. This is mainly just a problem in my lab."
$Service = Get-Service -Name "Windows Update"
$Service | Set-Service -StartupType Manual
$Service | Stop-Service

$start_time = Get-Date

#Download Unified Installer

Write-Output "Starting download at $start_Time"
$client = New-object System.Net.WebClient
$client.DownloadFile("https://aka.ms/unifiedinstaller", "C:\Users\$user\Desktop\UnifiedInstaller.exe")
$finish_time = Get-Date
Write-Output "Finished Unified Installer download at $Finish_Time"
$file = Get-item "$UserPathDesktop\UnifiedInstaller.exe"
$filesize_mb = ($file.length/1MB)
$download_time = ($finish_time-$start_time)
$download_speed = $filesize_mb/(($download_time.Minutes*60) + ($download_time.Seconds))
$download_speed = [math]::Round($download_speed,2)
write-output "Download speed: $Download_speed/ MB/s"
mkdir installer
#Create Mysql cred file: Couldn't think of an easy way to check if the right formatted file exists so just change it here if you want.
Add-Content "C:\Users\$user\Desktop\MySQLCredFile" "[MySQLCredentials]"
Add-Content  C:\Users\$user\Desktop\MySQLCredFile 'MySQLRootPassword = "root12345!"'
Add-Content  C:\Users\$user\Desktop\MySQLCredFile 'MySQLUserPassword = "password12345!"'
#Had some trouble with the MARS install, so, doing it separately for now.
invoke-expression "$userpath\installer\MARSAgentInstaller.exe /q"
#CS/PS installer. 
invoke-expression "$userpath\installer\UnifiedSetup.exe /AcceptThirdpartyEULA /servermode 'CS' /InstallLocation 'F:\' /MySQLCredsFilePath '$userpath\MySQLCredfile' /VaultCredsFilePath '$userpath\CNO-Test-RecoveryVault1_Sat Feb 15 2020.VaultCredentials' /EnvType 'NonVMware'"


