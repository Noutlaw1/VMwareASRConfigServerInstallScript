# VMwareASRConfigServerInstallScript
An install script for the Vmware to Azure Configuration Server - going to use it with Ansible for automated deployments.

General flow i am going for is this:

1. Terraform kicks off the Azure IAAS provisioning jobs based on a trigger (Maybe a CI/CD pipeline?)
2. Once the required VMs are provisioned and running, a custom script extension prepares the machine(s) for access via Ansible. Mainly, it opens WinRM.
3. Once the CSE is done, then Ansible pushes out the configuration/process server software to the configuration server (CXPS-<GUID>) via Powershell script as well as a certificate to authenticate with service principal.
4. Once the CS/PS is installed, the install script registers the CS to a pre-defined Recovery Vault, creates replication policies, etc.
5. Once that is done, Ansible connects to the replicated machine, pushes the mobility agent, installs and registers it to configuration server.
6. Lastly, replication needs to be enabled. I am not yet sure how I am going to do that but likely I will have Ansible do it.

Current challenges:
1. What triggers the initial Terraform job? My thought is a CI/CD pipeline.
2. If Ansible isn't going to handle the entire workflow, what will link the Terraform job finishing with ANsible kicking off the actual configuration jobs?
3. How to handle enable replication job?
