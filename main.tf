locals{
  env_name = (terraform.workspace == "default") ? "default" : "prod"
}
resource "azurerm_resource_group" "rg" { 
    name     = "${local.env_name}_${var.resource_group_name}"
    location = var.location
}
#Create virtual network
resource "azurerm_virtual_network" "vnet" {
    name = var.vnet_name
    address_space      = var.vnet_address_space
    location            = var.location
    resource_group_name = azurerm_resource_group.rg.name
}
# create availability set
resource "azurerm_availability_set" "avs" {
  name                = "shayavsetn"
  location            = var.location
  resource_group_name = azurerm_resource_group.rg.name
}
# Create subnet
resource "azurerm_subnet" "subnet" {
#count = length(var.subnet)
  name                 = "subnet_v1"
  resource_group_name  = azurerm_resource_group.rg.name
  virtual_network_name = azurerm_virtual_network.vnet.name
  #address_prefix  =  [var.subnet[count.index]]
  #address_prefix = [element(var.subnet, count.index)]
   address_prefix  = var.address_prefix
}
# Create network interface
resource "azurerm_network_interface" "nic" {
  count = 2
  name                      = "nii${count.index}-nic"
  location                  = var.location
  resource_group_name       = azurerm_resource_group.rg.name
ip_configuration {
    name                          = "test"
    subnet_id                     = azurerm_subnet.subnet.id
    private_ip_address_allocation = "dynamic"
    public_ip_address_id = azurerm_public_ip.pi[count.index].id
  }
}

# Create virtual machine
resource "azurerm_virtual_machine" "vm" {
  count = 2
  name                  = "nmm${count.index}-vm"
  location              = var.location
  resource_group_name   = azurerm_resource_group.rg.name
  network_interface_ids = [azurerm_network_interface.nic[count.index].id]
  vm_size               = "Standard_DS1_v2"
  availability_set_id   = azurerm_availability_set.avs.id
  #zones = [count.index+1]
  storage_os_disk {
    name              = "stvmm${count.index}os"
    caching           = "ReadWrite"
    create_option     = "FromImage"
    managed_disk_type = lookup(var.managed_disk_type, var.location, "Standard_LRS")
  }

  storage_image_reference {
    publisher = var.os.publisher
    offer     = var.os.offer
    sku       = var.os.sku
    version   = var.os.version
  }

  os_profile {
    computer_name  = var.servername
    admin_username = "shay"
  }
    os_profile_linux_config {
    disable_password_authentication = true
    ssh_keys {
      key_data = data.azurerm_key_vault_secret.shaypubb.value
      path     = "/home/shay/.ssh/authorized_keys"
    }
  }
}

resource "azurerm_public_ip" "pi" {
 count = 2
  name                = "public${count.index}ip"
  location            = var.location
  resource_group_name = azurerm_resource_group.rg.name
  allocation_method   = "Static"
}
 resource "azurerm_network_security_group" "nsg" {
   name                = "firewall"
   location            = var.location
   resource_group_name = azurerm_resource_group.rg.name
    security_rule {
     name                       = "port8080"
     priority                   = 100
     direction                  = "Inbound"
     access                     = "Allow"
     protocol                   = "*"
     source_port_range          = "*"
     destination_port_range     = "8080"
     source_address_prefix      = "212.179.161.98/32"
     destination_address_prefix = "*"
   }
    security_rule {
     name                       = "git1"
     priority                   = 101
     direction                  = "Inbound"
     access                     = "Allow"
     protocol                   = "*"
     source_port_range          = "*"
     destination_port_range     = "8080"
     source_address_prefix      = "192.30.252.0/22"
     destination_address_prefix = "*"
 }
    security_rule {
     name                       = "git2"
     priority                   = 102
     direction                  = "Inbound"
     access                     = "Allow"
     protocol                   = "Tcp"
     source_port_range          = "*"
     destination_port_range     = "8080"
     source_address_prefix      = "140.82.112.0/20"
     destination_address_prefix = "*"
 }
    security_rule {
     name                       = "ssh"
     priority                   = 103
     direction                  = "Inbound"
     access                     = "Allow"
     protocol                   = "Tcp"
     source_port_range          = "*"
     destination_port_range     = "22"
     source_address_prefix      = "212.179.161.98/32"
     destination_address_prefix = "*"
 }
}
 resource "azurerm_network_interface_security_group_association" "nsgg" {
    count = 2
   network_interface_id      = azurerm_network_interface.nic[count.index].id
   network_security_group_id = azurerm_network_security_group.nsg.id
    depends_on                = [azurerm_network_security_group.nsg, azurerm_network_interface.nic]
 }
#data "azurerm_resource_group" "ng" {
#name = "prod_shayv"
#}
data "azurerm_key_vault" "shayKeyVaultnn" {
  name                = "shayKeyVaultnn"
  resource_group_name = "default_shayvn2"
}
data "azurerm_key_vault_secret" "shaypubb" {
  name         = "shaypubb"
  key_vault_id = "${data.azurerm_key_vault.shayKeyVaultnn.id}"
}
