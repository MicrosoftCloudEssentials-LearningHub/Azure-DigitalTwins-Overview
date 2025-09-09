# outputs.tf
# This file defines outputs that are returned after the Terraform deployment is complete.
# These outputs provide valuable information about the deployed resources.

output "resource_group_name" {
  description = "The name of the resource group where resources are deployed"
  value       = azurerm_resource_group.rg.name
}

output "digital_twins_name" {
  description = "The name of the Azure Digital Twins instance"
  value       = local.dt_name
}

output "digital_twins_endpoint" {
  description = "The endpoint of the Azure Digital Twins instance"
  value       = "https://${data.azurerm_digital_twins_instance.dt.host_name}"
}

output "private_endpoint_name" {
  description = "The name of the Digital Twins private endpoint"
  value       = azurerm_private_endpoint.pe.name
}

output "vnet_id" {
  description = "The ID of the virtual network"
  value       = azurerm_virtual_network.vnet.id
}

output "subnet_id" {
  description = "The ID of the subnet for private endpoints"
  value       = azurerm_subnet.subnet.id
}

output "storage_account_name" {
  description = "The name of the storage account for event data"
  value       = local.storage_name
}

output "eventhub_namespace_name" {
  description = "The name of the Event Hub Namespace"
  value       = local.eventhub_ns_name
}

output "eventgrid_topic_name" {
  description = "The name of the Event Grid Topic for Digital Twins events"
  value       = local.topic_name
}
