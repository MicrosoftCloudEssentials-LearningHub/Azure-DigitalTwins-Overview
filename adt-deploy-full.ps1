# Azure Digital Twins Full Deployment Script
# This script deploys Azure Digital Twins models and creates twins with relationships

# Function to check if a command is available
function Test-CommandExists {
    param ($command)
    $oldPreference = $ErrorActionPreference
    $ErrorActionPreference = 'stop'
    try {
        if (Get-Command $command) { return $true }
    } catch {
        return $false
    }
    finally {
        $ErrorActionPreference = $oldPreference
    }
}

# Ensure Azure CLI is installed
if (-not (Test-CommandExists "az")) {
    Write-Error "Azure CLI is not installed. Please install it from https://docs.microsoft.com/en-us/cli/azure/install-azure-cli"
    exit 1
}

# Login to Azure
Write-Host "Logging in to Azure..." -ForegroundColor Blue
try {
    # Try to get current account info
    $accountInfo = az account show 2>$null | ConvertFrom-Json
    Write-Host "Already logged in as: $($accountInfo.user.name)" -ForegroundColor Green
} catch {
    # Need to login
    Write-Host "Not logged in, initiating Azure login..." -ForegroundColor Yellow
    az login --use-device-code
    
    if ($LASTEXITCODE -ne 0) {
        Write-Error "Failed to log in to Azure. Please restart the script and try again."
        exit 1
    }
    
    $accountInfo = az account show | ConvertFrom-Json
    Write-Host "Successfully logged in to Azure as: $($accountInfo.user.name)" -ForegroundColor Green
}

# Set variables
$dtName = "WarehouseDigitalTwins"
$rgName = "WarehouseDT-rg"
$location = "eastus"

# Create resource group if it doesn't exist
Write-Host "Creating resource group if it doesn't exist..." -ForegroundColor Blue
az group create --name $rgName --location $location

# Create Digital Twins instance
Write-Host "Creating Digital Twins instance..." -ForegroundColor Blue
az dt create --dt-name $dtName --resource-group $rgName --location $location

# Assign user role as owner
Write-Host "Assigning user role as owner..." -ForegroundColor Blue
$userObjectId = $(az ad signed-in-user show --query id -o tsv)
if ([string]::IsNullOrEmpty($userObjectId)) {
    Write-Error "Failed to get user object ID. Please check if you're logged in properly."
    exit 1
}
Write-Host "User Object ID: $userObjectId" -ForegroundColor Green
az dt role-assignment create --dt-name $dtName --resource-group $rgName --role "Azure Digital Twins Data Owner" --assignee "$userObjectId"

# Wait for role assignment to propagate
Write-Host "Waiting for role assignment to propagate (30 seconds)..." -ForegroundColor Yellow
Start-Sleep -Seconds 30

# Create models
Write-Host "Creating models..." -ForegroundColor Blue

# Upload models in the correct order (handling dependencies)
$modelFiles = @(
    "warehouse.json",
    "zone.json",
    "shelf.json",
    "sensor.json",
    "robot.json"
)

foreach ($modelFile in $modelFiles) {
    $modelPath = Join-Path -Path ".\models" -ChildPath $modelFile
    Write-Host "Uploading model: $modelFile" -ForegroundColor Green
    az dt model create --dt-name $dtName --resource-group $rgName --models $modelPath
    # Add small delay between model uploads
    Start-Sleep -Seconds 2
}

# Create twins
Write-Host "Creating twins..." -ForegroundColor Blue

# Create warehouse twin
Write-Host "Creating warehouse twin..." -ForegroundColor Green
$warehouseId = "warehouse_001"
$warehouseProperties = @"
{
  "name": "Main Warehouse",
  "location": "Seattle"
}
"@
az dt twin create --dt-name $dtName --resource-group $rgName --twin-id $warehouseId --model-id "dtmi:com:example:Warehouse;1" --properties $warehouseProperties

# Create zone twins
Write-Host "Creating zone twins..." -ForegroundColor Green
$zoneIds = @("zone_a", "zone_b", "zone_c")
$zoneNames = @("Storage Zone A", "Storage Zone B", "Shipping Zone")

for ($i = 0; $i -lt $zoneIds.Length; $i++) {
    $zoneName = $zoneNames[$i]
    $zoneProperties = @"
{
  "name": "$zoneName"
}
"@
    az dt twin create --dt-name $dtName --resource-group $rgName --twin-id $zoneIds[$i] --model-id "dtmi:com:example:Zone;1" --properties $zoneProperties
}

# Create shelf twins
Write-Host "Creating shelf twins..." -ForegroundColor Green
$shelfCount = 5
for ($i = 1; $i -le $shelfCount; $i++) {
    $shelfId = "shelf_a$i"
    $shelfName = "Shelf A$i"
    $shelfProperties = @"
{
  "name": "$shelfName",
  "capacity": 50
}
"@
    az dt twin create --dt-name $dtName --resource-group $rgName --twin-id $shelfId --model-id "dtmi:com:example:Shelf;1" --properties $shelfProperties
}

for ($i = 1; $i -le $shelfCount; $i++) {
    $shelfId = "shelf_b$i"
    $shelfName = "Shelf B$i"
    $shelfProperties = @"
{
  "name": "$shelfName",
  "capacity": 75
}
"@
    az dt twin create --dt-name $dtName --resource-group $rgName --twin-id $shelfId --model-id "dtmi:com:example:Shelf;1" --properties $shelfProperties
}

# Create sensor twins
Write-Host "Creating sensor twins..." -ForegroundColor Green
$sensorCount = 10
for ($i = 1; $i -le $sensorCount; $i++) {
    $sensorId = "sensor_$i"
    $sensorName = "Temperature Sensor $i"
    $sensorProperties = @"
{
  "name": "$sensorName",
  "type": "temperature"
}
"@
    az dt twin create --dt-name $dtName --resource-group $rgName --twin-id $sensorId --model-id "dtmi:com:example:Sensor;1" --properties $sensorProperties
}

# Create robot twins
Write-Host "Creating robot twins..." -ForegroundColor Green
$robotIds = @("robot_001", "robot_002", "robot_003")
$robotNames = @("Inventory Bot", "Picker Bot", "Delivery Bot")

for ($i = 0; $i -lt $robotIds.Length; $i++) {
    $robotName = $robotNames[$i]
    $robotProperties = @"
{
  "name": "$robotName"
}
"@
    az dt twin create --dt-name $dtName --resource-group $rgName --twin-id $robotIds[$i] --model-id "dtmi:com:example:Robot;1" --properties $robotProperties
}

# Create relationships
Write-Host "Creating relationships..." -ForegroundColor Blue

# Connect zones to warehouse
foreach ($zoneId in $zoneIds) {
    $relationshipId = "rel_warehouse_to_" + $zoneId
    az dt twin relationship create --dt-name $dtName --resource-group $rgName --relationship "contains" --relationship-id $relationshipId --twin-id $warehouseId --target $zoneId
}

# Connect shelves to zones
for ($i = 1; $i -le $shelfCount; $i++) {
    $shelfId = "shelf_a$i"
    $relationshipId = "rel_zone_to_" + $shelfId
    az dt twin relationship create --dt-name $dtName --resource-group $rgName --relationship "contains" --relationship-id $relationshipId --twin-id "zone_a" --target $shelfId
}

for ($i = 1; $i -le $shelfCount; $i++) {
    $shelfId = "shelf_b$i"
    $relationshipId = "rel_zone_to_" + $shelfId
    az dt twin relationship create --dt-name $dtName --resource-group $rgName --relationship "contains" --relationship-id $relationshipId --twin-id "zone_b" --target $shelfId
}

# Connect sensors to shelves (distribute evenly)
for ($i = 1; $i -le $sensorCount; $i++) {
    $sensorId = "sensor_$i"
    $shelfIndex = ($i % $shelfCount) + 1
    $zonePrefix = if ($i -le 5) { "a" } else { "b" }
    $shelfId = "shelf_$zonePrefix$shelfIndex"
    $relationshipId = "rel_shelf_to_" + $sensorId
    az dt twin relationship create --dt-name $dtName --resource-group $rgName --relationship "contains" --relationship-id $relationshipId --twin-id $shelfId --target $sensorId
}

# Connect robots to zones
$robotZones = @("zone_a", "zone_b", "zone_c")
for ($i = 0; $i -lt $robotIds.Length; $i++) {
    $robotId = $robotIds[$i]
    $zoneId = $robotZones[$i]
    $relationshipId = "rel_zone_to_" + $robotId
    az dt twin relationship create --dt-name $dtName --resource-group $rgName --relationship "contains" --relationship-id $relationshipId --twin-id $zoneId --target $robotId
}

Write-Host "Deployment completed successfully!" -ForegroundColor Green
Write-Host "Azure Digital Twins instance: $dtName is ready to use" -ForegroundColor Green
