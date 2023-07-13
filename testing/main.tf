#create a resource group
resource "azurerm_resource_group" "rg-terraform" {
    name = "rg-terraform"
    location = "uk south"
}



#create a virtual network in resource group
resource "azurerm_virtual_network" "vnet-terraform" {
  name                = "vnet-terraform"
  resource_group_name = azurerm_resource_group.rg-terraform.name
  location            = azurerm_resource_group.rg-terraform.location
  address_space       = ["10.10.90.0/24"]


}

#create subnet within vnet address space
resource "azurerm_subnet" "subnet-terraform" {
  name                 = "subnet-terraform"
  resource_group_name  = azurerm_resource_group.rg-terraform.name
  virtual_network_name = azurerm_virtual_network.vnet-terraform.name
  address_prefixes     = ["10.10.90.0/27"]
}



#create a public ip address for VM
resource "azurerm_public_ip" "pip-terraform" {
  name                    = "pip-terraform"
  resource_group_name     = azurerm_resource_group.rg-terraform.name
  location                = azurerm_resource_group.rg-terraform.location
  allocation_method       = "Dynamic"
  idle_timeout_in_minutes = 30

  tags = {
    environment = "pub-ip-terraform-vm"
  }
}



#create nsg for VM
resource "azurerm_network_security_group" "nsg-terraform" {
  name                = "nsg-terraform"
  location            = azurerm_resource_group.rg-terraform.location
  resource_group_name = azurerm_resource_group.rg-terraform.name
}



# Find my current Public IP
data "http" "my_public_ip" {
    url = "https://ipv4.icanhazip.com"
}



#create a rule and add to nsg 
resource "azurerm_network_security_rule" "nsgrule-terraform" {
  name                        = "inbound-rdp"
  priority                    = 100
  direction                   = "Inbound"
  access                      = "Allow"
  protocol                    = "Tcp"
  source_port_range           = "*"
  destination_port_range      = "3389"
  source_address_prefix      = "${chomp(data.http.my_public_ip.body)}/32"
  destination_address_prefix  = "*"
  resource_group_name         = azurerm_resource_group.rg-terraform.name
  network_security_group_name = azurerm_network_security_group.nsg-terraform.name
}



#create network interface for VM
resource "azurerm_network_interface" "netint-terraform" {
  name                = "netint-terraform"
  resource_group_name     = azurerm_resource_group.rg-terraform.name
  location                = azurerm_resource_group.rg-terraform.location

  ip_configuration {
    name                          = "internal"
    subnet_id                     = azurerm_subnet.subnet-terraform.id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = "${azurerm_public_ip.pip-terraform.id}"
  }
}

#associate nsg with network interface
resource "azurerm_network_interface_security_group_association" "nsg-netint-terraform" {
  network_interface_id      = azurerm_network_interface.netint-terraform.id
  network_security_group_id = azurerm_network_security_group.nsg-terraform.id
}





#create a windows vm
resource "azurerm_windows_virtual_machine" "vm-terraform" {
  name                = "vm-terraform"
  resource_group_name = azurerm_resource_group.rg-terraform.name
  location            = azurerm_resource_group.rg-terraform.location
  size                = "Standard_F2"
  admin_username      = "adminuser"
  admin_password      = "P@$$w0rd1234!"
  network_interface_ids = [
    azurerm_network_interface.netint-terraform.id,
  ]

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }

  source_image_reference {
    publisher = "MicrosoftWindowsServer"
    offer     = "WindowsServer"
    sku       = "2019-Datacenter"
    version   = "latest"
  }
}






#output the public ip address to screen
output "azurerm_public_ip" {
  value = azurerm_public_ip.pip-terraform.ip_address
}




