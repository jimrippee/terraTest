resource "random_pet" "rg-name" {
    prefix = var.resource_group_name_prefix
}
resource "azurerm_resource_group" "rg" {
  name = random_pet.rg-name.id
  location = var.resource_group_location 
}

#create vnet 
resource "azurerm_virtual_network" "myterraformnetwork" {
    name                    ="myVnet"
    address_space           = ["172.29.0.0/16"]
    location                = azurerm_resource_group.rg.location
    resource_group_name     = azurerm_resource_group.rg.name
}

#create subnet 
resource "azurerm_subnet" "myterraformsubnet" {
    name                            = "mySubnet"
    resource_group_name             = azurerm_resource_group.rg.name
    virtual_network_name            = azurerm_virtual_network.myterraformnetwork.name
    address_prefixes                = ["172.29.192.0/24"]  
}
#create public IPs
resource "azurerm_public_ip" "myterraformpublicip" {
    name                = "myPublicIP"
    location            = azurerm_resource_group.rg.location
    resource_group_name = azurerm_resource_group.rg.name
    allocation_method   = "Dynamic"
}
#create nsg 
resource "azurerm_network_security_group" "myterraformnsg" {
    name                = "myNetworkSecurityGroup"
    location            = azurerm_resource_group.rg.location
    resource_group_name = azurerm_resource_group.rg.name

    security_rule {
      name                        = "SSH"
      priority                    = 1001
      direction                   = "Inbound"
      access                      = "Allow"
      protocol                    = "Tcp"
      source_port_range           = "*"
      destination_port_range      = "22"
      source_address_prefix       = "*"
      destination_address_prefix  = "*" 
      } 
}
#create network interface
resource "azurerm_network_interface" "myterraformnic" {
    name                = "myNIC"
    location            = azurerm_resource_group.rg.location
    resource_group_name = azurerm_resource_group.rg.name

    ip_configuration {
      name                                  = "ipconfig1"
      subnet_id                             = azurerm_subnet.myterraformsubnet.id
      private_ip_address_allocation         = "Dynamic"
      public_ip_address_id                  = azurerm_public_ip.myterraformpublicip.id 
    }   
}
#connect nsg to the nic 
resource "azurerm_network_interface_security_group_association" "example" {
    network_interface_id        = azurerm_network_interface.myterraformnic.id
    network_security_group_id   = azurerm_network_security_group.myterraformnsg.id
}
#gen random text for a unique storage account name 
resource "random_id" "randomId" {
    keepers = {
      # gen a new ID only when a new rg is defined   
      "resource_group" = "azurerm_resource_group.rg.name"
    }
    byte_length = 0 
}
#storage account for boot diag 
resource "azurerm_storage_account" "mystorageaccount" {
  name                              = "diag${random_id.randomId.hex}"
  location                          = azurerm_resource_group.rg.location
  resource_group_name               = azurerm_resource_group.rg.name
  account_tier                      = "Standard"
  account_replication_type          = "LRS" 
}  
#Create (and display) an SSH key
resource "tls_private_key" "example_ssh" {
    algorithm   = "RSA"
    rsa_bits    = 4096 
}
#finally, create the fucking VM
resource "azurerm_linux_virtual_machine" "myterraformvm" {
    name                            = "myVM"
    location                        = azurerm_resource_group.rg.location
    resource_group_name             = azurerm_resource_group.rg.name
    network_interface_ids           = [azurerm_network_interface.myterraformnic.id]
    size                            = "Standard_B1ls"

    os_disk {
      name                          = "myOsDisk"
      caching                       = "ReadWrite"
      storage_account_type          = "Standard_LRS"    
    }

    source_image_reference {
      publisher         = "Canonical"
      offer             = "UbuntuServer"
      sku               = "18.04-LTS"
      version           = "latest"
    }
  computer_name                     = "myvm"
  admin_username                    = "rippee"
  disable_password_authentication   = true

  admin_ssh_key {
    username            = "rippee"
    public_key = tls_private_key.example_ssh.public_key_openssh
  }
  boot_diagnostics {
    storage_account_uri = azurerm_storage_account.mystorageaccount.primary_blob_endpoint
  }  
}