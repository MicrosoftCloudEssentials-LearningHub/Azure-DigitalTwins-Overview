# variables.tf
# This file defines variables used in the Terraform configuration.
# Each variable has a description and some have default values.

variable "subscription_id" {
  description = "The Azure subscription ID to deploy resources to"
  type        = string
}

variable "resource_group_name" {
  description = "The name of the resource group"
  type        = string
  default     = "rg-digitaltwins-demo"
}

variable "location" {
  description = "The Azure region to deploy resources to"
  type        = string
  default     = "eastus"
}

variable "digital_twins_name" {
  description = "The name of the Azure Digital Twins instance"
  type        = string
  default     = "dt-warehouse-demo"
}

variable "vnet_name" {
  description = "The name of the Virtual Network"
  type        = string
  default     = "vnet-digitaltwins"
}

variable "vnet_address_space" {
  description = "Address space for the Virtual Network"
  type        = list(string)
  default     = ["10.0.0.0/16"]
}

variable "subnet_name" {
  description = "The name of the subnet for Digital Twins private endpoints"
  type        = string
  default     = "snet-digitaltwins"
}

variable "subnet_address_prefix" {
  description = "Address prefix for the subnet"
  type        = string
  default     = "10.0.1.0/24"
}

variable "private_endpoint_name" {
  description = "The name of the private endpoint for Digital Twins"
  type        = string
  default     = "pe-digitaltwins"
}

variable "private_dns_zone_name" {
  description = "The name of the private DNS zone for Digital Twins"
  type        = string
  default     = "privatelink.digitaltwins.azure.net"
}

variable "storage_account_name_prefix" {
  description = "Prefix for the storage account name"
  type        = string
  default     = "stadtevents"
}

variable "eventhub_namespace_name_prefix" {
  description = "Prefix for the Event Hub Namespace name"
  type        = string
  default     = "evhns-dt"
}

variable "eventgrid_topic_name_prefix" {
  description = "Prefix for the Event Grid Topic name"
  type        = string
  default     = "evgt-dt"
}

variable "tags" {
  description = "Tags to apply to resources"
  type        = map(string)
  default = {
    environment = "demo"
    project     = "warehouse-digitaltwins"
  }
}
