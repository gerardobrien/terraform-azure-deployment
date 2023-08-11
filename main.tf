# Create a resource group
resource "azurerm_resource_group" "tf-rg" {
  name     = "tf-rg"
  location = "UK South"
}


# Create a virtual network within the resource group
resource "azurerm_virtual_network" "tf-vnet" {
  name                = "tf-vnet"
  resource_group_name = azurerm_resource_group.tf-rg.name
  location            = azurerm_resource_group.tf-rg.location
  address_space       = ["10.0.0.0/16"]
}


# Create a subnet within the virtual network above
resource "azurerm_subnet" "tf-snet" {
  name                 = "tf-snet"
  resource_group_name  = azurerm_resource_group.tf-rg.name
  virtual_network_name = azurerm_virtual_network.tf-vnet.name
  address_prefixes     = ["10.0.1.0/24"]
  }


# Create a new public ip address
resource "azurerm_public_ip" "tf-pip" {
  name                = "tf-pip"
  resource_group_name = azurerm_resource_group.tf-rg.name
  location            = azurerm_resource_group.tf-rg.location
  allocation_method   = "Dynamic"

}

# Create a new nsg
resource "azurerm_network_security_group" "tf-nsg" {
  name                = "tf-vm-nsg"
  location            = azurerm_resource_group.tf-rg.location
  resource_group_name = azurerm_resource_group.tf-rg.name
}


# Find my current Public IP
data "http" "my_public_ip" {
    url = "https://ipv4.icanhazip.com"
}


# Create a new rule within the nsg above - lock down to my public ip address
resource "azurerm_network_security_rule" "tf-nsg-rule" {
  name                        = "vm-rdp"
  priority                    = 100
  direction                   = "Inbound"
  access                      = "Allow"
  protocol                    = "Tcp"
  source_port_range           = "*"
  destination_port_range      = "3389"
  source_address_prefix       = "${chomp(data.http.my_public_ip.body)}/32"
  destination_address_prefix  = "*"
  resource_group_name         = azurerm_resource_group.tf-rg.name
  network_security_group_name = azurerm_network_security_group.tf-nsg.name
}


# Create network interface for vm
resource "azurerm_network_interface" "tf-vm-nic" {
  name                = "tf-vm-nic"
  location            = azurerm_resource_group.tf-rg.location
  resource_group_name = azurerm_resource_group.tf-rg.name

  ip_configuration {
    name                          = "internal"
    subnet_id                     = azurerm_subnet.tf-snet.id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id = "${azurerm_public_ip.tf-pip.id}"
  }
}


# Associate nsg with network interface
resource "azurerm_network_interface_security_group_association" "tf-nsg-nic" {
  network_interface_id      = azurerm_network_interface.tf-vm-nic.id
  network_security_group_id = azurerm_network_security_group.tf-nsg.id
}



# Create a new windows virtual machine
resource "azurerm_windows_virtual_machine" "tf-vm" {
  name                = "tf-vm"
  resource_group_name = azurerm_resource_group.tf-rg.name
  location            = azurerm_resource_group.tf-rg.location
  size                = "Standard_F2"
  admin_username      = "adminuser"
  admin_password      = "P@$$w0rd1234!"
  network_interface_ids = [
    azurerm_network_interface.tf-vm-nic.id,
  ]

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }

  source_image_reference {
    publisher = "MicrosoftWindowsServer"
    offer     = "WindowsServer"
    sku       = "2022-Datacenter"
    version   = "latest"
  }
}

# output the public ip address of the vm

output "azurerm_public_ip" {
    value = azurerm_public_ip.tf-pip.ip_address
}

