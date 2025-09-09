# terraform.tfvars
# This file contains the actual values for variables defined in variables.tf.
# Replace with your own values as needed.

subscription_id = "YOUR_SUBSCRIPTION_ID"
resource_group_name = "RG-digitaltwins-demox1"
location = "eastus"
digital_twins_name = "dt-warehouse-demox1"
vnet_name = "vnet-digitaltwinsx1"
vnet_address_space = ["10.0.0.0/16"]
subnet_name = "snet-digitaltwinsx1"
subnet_address_prefix = "10.0.1.0/24"
private_endpoint_name = "pe-digitaltwinsx1"
private_dns_zone_name = "privatelinkx1.digitaltwins.azure.net"

tags = {
  environment = "demo"
  project     = "warehouse-digitaltwins"
  owner       = "operations-team"
}
