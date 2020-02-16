provider "azurerm" {
  version = "~> 1.27"
  subscription_id = "${var.SUBID}"
  client_id = "${var.CLIENTID}"
  client_certificate_path ="${var.CERTPATH}"
  client_certificate_password = "${var.CERTPASS}"
  tenant_id = "${var.TENANTID}"
}


resource "azurerm_resource_group" "csps_rg" {
    name     = "CSPSTest_Group"
    location = "eastus"
}


# Create virtual network
resource "azurerm_virtual_network" "csps_testvnet" {
    name                = "csps_testvnet"
    address_space       = ["192.168.1.0/24"]
    location            = "eastus"
    resource_group_name = azurerm_resource_group.csps_rg.name
}

# Create subnet
resource "azurerm_subnet" "csps_subnet" {
    name                 = "csps_subnet"
    resource_group_name  = azurerm_resource_group.csps_rg.name
    virtual_network_name = azurerm_virtual_network.csps_testvnet.name
    address_prefix       = "192.168.1.0/25"
}


# Generate random text for a unique storage account name
resource "random_id" "randomId" {
    keepers = {
        # Generate a new ID only when a new resource group is defined
        resource_group = azurerm_resource_group.csps_rg.name
    }

    byte_length = 8
}


# Create Network Security Group and rule
resource "azurerm_network_security_group" "csps_testnsg" {
    name                = "csps_nsg${random_id.randomId.hex}"
    location            = "eastus"
    resource_group_name = azurerm_resource_group.csps_rg.name

    security_rule {
        name                       = "RDP"
        priority                   = 1001
        direction                  = "Inbound"
        access                     = "Allow"
        protocol                   = "Tcp"
        source_port_range          = "*"
        destination_port_range     = "3389"
        source_address_prefix      = "*"
        destination_address_prefix = "*"
    }
}

#Generate random string for hostname
resource "random_string" "random" {
  length = 6
  special = false
}
# Create network interface
resource "azurerm_network_interface" "cspsnic" {
    name                      = "cspsnic_${random_id.randomId.hex}"
    location                  = "eastus"
    resource_group_name       = azurerm_resource_group.csps_rg.name
    network_security_group_id = azurerm_network_security_group.csps_testnsg.id

    ip_configuration {
        name                          = "nicconfig_diag${random_id.randomId.hex}"
        subnet_id                     = azurerm_subnet.csps_subnet.id
        private_ip_address_allocation = "Dynamic"
     }
}


# Create virtual machine
resource "azurerm_virtual_machine" "cspsvm" {
    name                  = "csps-${random_string.random.result}"
    location              = "eastus"
    resource_group_name   = azurerm_resource_group.csps_rg.name
    network_interface_ids = [azurerm_network_interface.cspsnic.id]
    vm_size               = "Standard_B2ms"

    storage_image_reference {
        publisher = "MicrosoftWindowsServer"
        offer = "WindowsServer"
        sku = "2016-Datacenter"
        version = "latest"
    }
    storage_os_disk {
        name              = "cspsosdisk${random_string.random.result}"
        caching           = "ReadWrite"
        create_option     = "FromImage"
        managed_disk_type = "Premium_LRS"
    }
    storage_data_disk {
        name              = "cspsdatadisk${random_string.random.result}"
        lun               = 1
        create_option     = "Empty"
        disk_size_gb      = "1000"
        managed_disk_type = "Standard_LRS"
    }
    os_profile {
        computer_name  =  "csps-${random_string.random.result}"
        admin_username = "${var.DEFAULTUSER}"
        admin_password = "${var.DEFAULTPASSWORD}"
    }
    os_profile_windows_config {
        provision_vm_agent = true
        timezone = "Eastern Standard Time"
    }
}
