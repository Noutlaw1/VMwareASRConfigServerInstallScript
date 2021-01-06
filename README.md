# VMwareASRConfigServerInstallScript
An install script for the Vmware to Azure Configuration Server - going to use it with Ansible for automated deployments.

General flow i am going for is this:

1. Terraform kicks off the Azure IAAS provisioning jobs based on a trigger (Maybe a CI/CD pipeline?) Right now that trigger is just running Terraform Apply, which is not great. The Terraform bit is done, though, and works.
2. Once the required VMs are provisioned and running, a custom script extension prepares the machine(s) for access via Ansible. Mainly, it opens WinRM. This is done.
3. Once the CSE is done, then Ansible pushes out the configuration/process server software to the configuration server (CXPS-<GUID>) via Powershell script as well as a certificate to authenticate with service principal. This is done, however, I've decided to rewrite the script to make it function better.
4. Once the CS/PS is installed, the install script registers the CS to a pre-defined Recovery Vault, creates replication policies, etc. This works.
5. Once that is done, Ansible connects to the replicated machine, pushes the mobility agent, installs and registers it to configuration server.
6. Lastly, replication needs to be enabled. I am not yet sure how I am going to do that but likely I will have Ansible do it.

Current challenges:
1. What triggers the initial Terraform job? My thought is a CI/CD pipeline.
2. If Ansible isn't going to handle the entire workflow, what will link the Terraform job finishing with ANsible kicking off the actual configuration jobs?
3. How to handle enable replication job?


How to use it:

1. If you want to use this, I've set up Terraform to connect via a Service Principal and just keep that Service Principal info (Such as the subscription/tenant ID, etc) as OS-level environment variables. You could manually authenticate with Azure via the CLI and just use the same main.tf file if you wished. This is also how the Powershell script run on the configuration/process server authenticates with Azure. The certificate and account info are passed to the machine by Ansible in a text file.
2. Currently using Azure provider version 1.27 for Terraform.
3. The Powershell script used on the Configuration Server doesn't have any dependencies, and will download the latest version of the AZ module as well as the latest version of the Configuration/Process server installer.

Test commit to test Github File Watcher
