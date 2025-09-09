# main.tf
# Azure Digital Twins infrastructure with VNet integration

# Get current client configuration
data "azurerm_client_config" "current" {}

# Create a random string for uniqueness
resource "random_string" "unique" {
  length  = 8
  special = false
  upper   = false
}

# Create a resource group
resource "azurerm_resource_group" "rg" {
  name     = var.resource_group_name
  location = var.location
  tags     = var.tags
  
  # Output the resource group name
  provisioner "local-exec" {
    command = "echo Resource Group: ${self.name}"
  }
}

# Create a virtual network
resource "azurerm_virtual_network" "vnet" {
  name                = var.vnet_name
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  address_space       = var.vnet_address_space
  tags                = var.tags
}

# Create a subnet for Digital Twins private endpoint
resource "azurerm_subnet" "subnet" {
  name                 = var.subnet_name
  resource_group_name  = azurerm_resource_group.rg.name
  virtual_network_name = azurerm_virtual_network.vnet.name
  address_prefixes     = [var.subnet_address_prefix]
  
  # Add service endpoints for Storage and EventHub
  service_endpoints    = ["Microsoft.Storage", "Microsoft.EventHub"]
  
  # Private endpoint settings
  private_link_service_network_policies_enabled = false
}

# Create Azure Digital Twins instance using Azure CLI to have more control
locals {
  dt_name = "${var.digital_twins_name}-${random_string.unique.result}"
}

resource "null_resource" "digital_twins_instance" {
  provisioner "local-exec" {
    command = "az dt create --dt-name ${local.dt_name} --resource-group ${azurerm_resource_group.rg.name} --location ${var.location} --tags Environment=demo Project=warehouse-digitaltwins"
  }
  
  depends_on = [azurerm_resource_group.rg]
}

# Use data source to get info about the created Digital Twins instance
data "azurerm_digital_twins_instance" "dt" {
  name                = local.dt_name
  resource_group_name = azurerm_resource_group.rg.name

  depends_on = [null_resource.digital_twins_instance]
}

# Assign Azure Digital Twins Data Reader role to the current user
resource "azurerm_role_assignment" "dt_data_reader" {
  scope                = data.azurerm_digital_twins_instance.dt.id
  role_definition_name = "Azure Digital Twins Data Reader"
  principal_id         = data.azurerm_client_config.current.object_id

  depends_on = [data.azurerm_digital_twins_instance.dt]
}

# Create private DNS zone for Digital Twins
resource "azurerm_private_dns_zone" "dns_zone" {
  name                = var.private_dns_zone_name
  resource_group_name = azurerm_resource_group.rg.name
  tags                = var.tags
}

# Link the private DNS zone to the virtual network
resource "azurerm_private_dns_zone_virtual_network_link" "dns_link" {
  name                  = "link-${var.vnet_name}"
  resource_group_name   = azurerm_resource_group.rg.name
  private_dns_zone_name = azurerm_private_dns_zone.dns_zone.name
  virtual_network_id    = azurerm_virtual_network.vnet.id
  registration_enabled  = true
  tags                  = var.tags
}

# Create private endpoint for Digital Twins
resource "azurerm_private_endpoint" "pe" {
  name                = var.private_endpoint_name
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  subnet_id           = azurerm_subnet.subnet.id
  tags                = var.tags

  private_service_connection {
    name                           = "psc-digitaltwins"
    private_connection_resource_id = data.azurerm_digital_twins_instance.dt.id
    is_manual_connection           = false
    subresource_names              = ["API"]
  }

  private_dns_zone_group {
    name                 = "dns-zone-group"
    private_dns_zone_ids = [azurerm_private_dns_zone.dns_zone.id]
  }
  
  depends_on = [
    data.azurerm_digital_twins_instance.dt,
    azurerm_private_dns_zone.dns_zone
  ]
}

# Storage Account for Digital Twins event data using Azure CLI
locals {
  storage_name = "stdtdata${random_string.unique.result}"
}

resource "null_resource" "storage_account" {
  provisioner "local-exec" {
    command = "az storage account create --name ${local.storage_name} --resource-group ${azurerm_resource_group.rg.name} --location ${var.location} --sku Standard_LRS --https-only true --min-tls-version TLS1_2"
  }
  
  depends_on = [azurerm_resource_group.rg]
}

# Use data source to get info about the created storage account
data "azurerm_storage_account" "storage" {
  name                = local.storage_name
  resource_group_name = azurerm_resource_group.rg.name

  depends_on = [null_resource.storage_account]
}

# Create a storage container for Digital Twins data
resource "null_resource" "dt_container" {
  provisioner "local-exec" {
    command = "az storage container create --name digitaltwinsdata --account-name ${local.storage_name} --auth-mode login"
  }
  
  depends_on = [null_resource.storage_account, data.azurerm_storage_account.storage]
}

# Create an Event Hub Namespace using Azure CLI
locals {
  eventhub_ns_name = "evhns-dt-${random_string.unique.result}"
}

resource "null_resource" "eventhub_namespace" {
  provisioner "local-exec" {
    command = "az eventhubs namespace create --name ${local.eventhub_ns_name} --resource-group ${azurerm_resource_group.rg.name} --location ${var.location} --sku Standard"
  }
  
  depends_on = [azurerm_resource_group.rg]
}

# Use data source to get info about the created Event Hub Namespace
data "azurerm_eventhub_namespace" "eventhub_ns" {
  name                = local.eventhub_ns_name
  resource_group_name = azurerm_resource_group.rg.name

  depends_on = [null_resource.eventhub_namespace]
}

# Create an Event Hub using Azure CLI
resource "null_resource" "eventhub" {
  provisioner "local-exec" {
    command = "az eventhubs eventhub create --name evh-digitaltwins --namespace-name ${local.eventhub_ns_name} --resource-group ${azurerm_resource_group.rg.name} --partition-count 2"
  }
  
  depends_on = [null_resource.eventhub_namespace, data.azurerm_eventhub_namespace.eventhub_ns]
}

# Create an Event Grid Topic using Azure CLI
locals {
  topic_name = "evgt-digitaltwins"
}

resource "null_resource" "eventgrid_topic" {
  provisioner "local-exec" {
    command = "az eventgrid topic create --name ${local.topic_name} --resource-group ${azurerm_resource_group.rg.name} --location ${var.location}"
  }
  
  depends_on = [azurerm_resource_group.rg]
}

# Network Security Group for subnet
resource "azurerm_network_security_group" "nsg" {
  name                = "nsg-${var.subnet_name}"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  tags                = var.tags
  
  # Allow inbound traffic to Digital Twins endpoint
  security_rule {
    name                       = "AllowHttpsInbound"
    priority                   = 100
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "443"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }
}

# Associate NSG with the subnet
resource "azurerm_subnet_network_security_group_association" "nsg_association" {
  subnet_id                 = azurerm_subnet.subnet.id
  network_security_group_id = azurerm_network_security_group.nsg.id
}
