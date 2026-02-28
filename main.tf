# Configure the Terraform runtime requirements.
terraform {
  required_version = ">= 1.1.0"

  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 3.0.2"
    }
    cloudinit = {
      source  = "hashicorp/cloudinit"
      version = "2.3.3"
    }
  }
}

# Define providers and their config params
provider "azurerm" {
  features {}
}

provider "cloudinit" {}

# ---------------------------------------------------------------------------
# Variables
# ---------------------------------------------------------------------------
variable "labelPrefix" {
  description = "Your college username. This will form the beginning of various resource names."
  type        = string
}

variable "region" {
  description = "Azure region for resources."
  type        = string
  default     = "canadacentral"
}

variable "admin_username" {
  description = "Admin username for the Linux VM."
  type        = string
  default     = "azureadmin"
}

variable "admin_ssh_public_key" {
  description = "SSH public key for VM login (e.g. contents of ~/.ssh/id_rsa.pub)."
  type        = string
  sensitive   = true
}

# ---------------------------------------------------------------------------
# Resource Group
# ---------------------------------------------------------------------------
resource "azurerm_resource_group" "main" {
  name     = "${var.labelPrefix}-A05-RG"
  location = var.region
}

# ---------------------------------------------------------------------------
# Public IP
# ---------------------------------------------------------------------------
resource "azurerm_public_ip" "main" {
  name                = "${var.labelPrefix}-A05-PIP"
  resource_group_name = azurerm_resource_group.main.name
  location            = azurerm_resource_group.main.location
  allocation_method   = "Static"
}

# ---------------------------------------------------------------------------
# Virtual Network and Subnet
# ---------------------------------------------------------------------------
resource "azurerm_virtual_network" "main" {
  name                = "${var.labelPrefix}-A05-VNet"
  resource_group_name = azurerm_resource_group.main.name
  location            = azurerm_resource_group.main.location
  address_space       = ["10.0.0.0/16"]
}

resource "azurerm_subnet" "main" {
  name                 = "${var.labelPrefix}-A05-Subnet"
  resource_group_name  = azurerm_resource_group.main.name
  virtual_network_name = azurerm_virtual_network.main.name
  address_prefixes     = ["10.0.1.0/24"]
}

# ---------------------------------------------------------------------------
# Network Security Group (inline rules for SSH and HTTP)
# ---------------------------------------------------------------------------
resource "azurerm_network_security_group" "main" {
  name                = "${var.labelPrefix}-A05-NSG"
  resource_group_name = azurerm_resource_group.main.name
  location            = azurerm_resource_group.main.location

  security_rule {
    name                       = "AllowSSH"
    priority                   = 100
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range    = "22"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }

  security_rule {
    name                       = "AllowHTTP"
    priority                   = 110
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range    = "80"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }
}

# ---------------------------------------------------------------------------
# Network Interface (with Public IP)
# ---------------------------------------------------------------------------
resource "azurerm_network_interface" "main" {
  name                = "${var.labelPrefix}-A05-NIC"
  resource_group_name = azurerm_resource_group.main.name
  location            = azurerm_resource_group.main.location

  ip_configuration {
    name                          = "internal"
    subnet_id                     = azurerm_subnet.main.id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = azurerm_public_ip.main.id
  }
}

# Apply NSG to the NIC (web server only, not the whole subnet)
resource "azurerm_network_interface_security_group_association" "main" {
  network_interface_id      = azurerm_network_interface.main.id
  network_security_group_id = azurerm_network_security_group.main.id
}

# ---------------------------------------------------------------------------
# Cloud-init config (runs init.sh on first boot)
# ---------------------------------------------------------------------------
data "cloudinit_config" "main" {
  gzip          = true
  base64_encode = true

  part {
    content_type = "text/x-shellscript"
    content     = file("${path.module}/init.sh")
  }
}

# ---------------------------------------------------------------------------
# Linux VM (Ubuntu, B1s, Apache via cloud-init)
# ---------------------------------------------------------------------------
resource "azurerm_linux_virtual_machine" "main" {
  name                = "${var.labelPrefix}-A05-VM"
  resource_group_name = azurerm_resource_group.main.name
  location            = azurerm_resource_group.main.location
  size                = "Standard_B1s"
  admin_username      = var.admin_username

  admin_ssh_key {
    username   = var.admin_username
    public_key = var.admin_ssh_public_key
  }

  custom_data = data.cloudinit_config.main.rendered

  network_interface_ids = [
    azurerm_network_interface.main.id,
  ]

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }

  source_image_reference {
    publisher = "Canonical"
    offer     = "0001-com-ubuntu-server-jammy"
    sku       = "22_04-lts"
    version   = "latest"
  }
}

# ---------------------------------------------------------------------------
# Outputs
# ---------------------------------------------------------------------------
output "resource_group_name" {
  description = "Name of the resource group (for Azure portal inspection)."
  value       = azurerm_resource_group.main.name
}

output "public_ip_address" {
  description = "Public IP of the web server (browser and SSH)."
  value       = azurerm_public_ip.main.ip_address
}
