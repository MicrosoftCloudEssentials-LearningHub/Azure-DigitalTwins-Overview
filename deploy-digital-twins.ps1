# Azure Digital Twins Demo Deployment Script
# This script guides you through the deployment process for the warehouse digital twin demo

# Script parameters
param (
    [switch]$SkipInstallation = $false
)

# Helper function to display colored messages
function Write-ColoredOutput {
    param (
        [string]$Message,
        [string]$ForegroundColor = "White"
    )
    
    Write-Host $Message -ForegroundColor $ForegroundColor
}

# Helper function to check if command exists
function Test-CommandExists {
    param (
        [string]$Command
    )
    
    $exists = $null -ne (Get-Command $Command -ErrorAction SilentlyContinue)
    return $exists
}

# Helper function to display step header
function Show-StepHeader {
    param (
        [string]$StepNumber,
        [string]$StepTitle
    )
    
    Write-ColoredOutput "`n`n========== STEP $StepNumber`: $StepTitle ==========" "Cyan"
}

# Title
Clear-Host
Write-ColoredOutput "`n====================================================" "Green"
Write-ColoredOutput "       AZURE DIGITAL TWINS DEPLOYMENT WIZARD" "Green"
Write-ColoredOutput "====================================================" "Green"
Write-ColoredOutput "`nThis script will guide you through the process of deploying the warehouse digital twin demo." "Yellow"
Write-ColoredOutput "Please follow the prompts and provide the requested information." "Yellow"

# Check prerequisites
Write-ColoredOutput "`n`nChecking prerequisites..." "Magenta"

# Check if Azure CLI is installed
$azCliInstalled = Test-CommandExists "az"
if (-not $azCliInstalled) {
    Write-ColoredOutput "`nAzure CLI is not installed." "Red"
    Write-ColoredOutput "Please install Azure CLI from: https://learn.microsoft.com/en-us/cli/azure/install-azure-cli" "Yellow"
    
    $installAzCli = Read-Host -Prompt "Do you want to open the Azure CLI installation page? (y/n)"
    if ($installAzCli -eq "y") {
        Start-Process "https://learn.microsoft.com/en-us/cli/azure/install-azure-cli"
    }
    
    Write-ColoredOutput "`nPlease restart this script after installing Azure CLI." "Red"
    exit
}
else {
    Write-ColoredOutput "Azure CLI is installed. ✓" "Green"
}

# Check if already logged in to Azure
$loggedIn = $false
try {
    $accountInfo = az account show 2>$null | ConvertFrom-Json
    $loggedIn = $true
    Write-ColoredOutput "You are logged in to Azure as: $($accountInfo.user.name) ✓" "Green"
    Write-ColoredOutput "Subscription: $($accountInfo.name) ($($accountInfo.id))" "Green"
}
catch {
    Write-ColoredOutput "Not logged in to Azure." "Yellow"
}

# Step 3: Upload Models Using Azure CLI
Show-StepHeader "3" "Upload Models Using Azure CLI"

# Login to Azure if not logged in
if (-not $loggedIn) {
    Write-ColoredOutput "`nYou need to log in to Azure to continue." "Yellow"
    Write-ColoredOutput "A browser window will open for you to sign in to your Azure account." "Yellow"
    Write-ColoredOutput "Please complete the authentication in the browser window." "Yellow"
    
    # Pause for user to read instructions
    Start-Sleep -Seconds 3
    
    # Login with device code flow (opens browser window)
    az login --use-device-code
    
    # Check if login was successful
    if ($LASTEXITCODE -ne 0) {
        Write-ColoredOutput "Failed to log in to Azure. Please restart the script and try again." "Red"
        exit
    }
    
    # Get account info
    $accountInfo = az account show | ConvertFrom-Json
    Write-ColoredOutput "Successfully logged in to Azure as: $($accountInfo.user.name) ✓" "Green"
    Write-ColoredOutput "Subscription: $($accountInfo.name) ($($accountInfo.id))" "Green"
    $loggedIn = $true
}

# Check for required Azure CLI extensions
Write-ColoredOutput "`nChecking for Azure IoT extension..." "Yellow"
$iotExtension = az extension show --name azure-iot 2>&1
$installIoTExtension = $false

# Check the exit code from the last command
if ($LASTEXITCODE -ne 0) {
    Write-ColoredOutput "Azure IoT extension is not installed. Installing now..." "Yellow"
    $installIoTExtension = $true
}
else {
    Write-ColoredOutput "Azure IoT extension is already installed. ✓" "Green"
}

# Install IoT extension if needed
if ($installIoTExtension) {
    Write-ColoredOutput "Installing Azure IoT extension..." "Yellow"
    az extension add --name azure-iot
    
    if ($LASTEXITCODE -eq 0) {
        Write-ColoredOutput "Azure IoT extension installed successfully. ✓" "Green"
    }
    else {
        Write-ColoredOutput "Failed to install Azure IoT extension. Please try manually." "Red"
        exit
    }
}

# Get Azure Digital Twins instance name
Write-ColoredOutput "`nSearching for existing Azure Digital Twins instances..." "Yellow"

# List all digital twins instances across all subscriptions
$allSubscriptions = az account list | ConvertFrom-Json
$dtInstances = @()
$createNew = $false

foreach ($subscription in $allSubscriptions) {
    # Switch to this subscription context
    Write-ColoredOutput "Checking subscription: $($subscription.name)..." "Gray"
    az account set --subscription $subscription.id | Out-Null
    
    # Get all Digital Twins instances in this subscription
    $subInstances = az dt list 2>&1
    
    if ($LASTEXITCODE -eq 0) {
        try {
            $subInstancesJson = $subInstances | ConvertFrom-Json
            if ($subInstancesJson -and $subInstancesJson.Count -gt 0) {
                foreach ($instance in $subInstancesJson) {
                    $dtInstances += [PSCustomObject]@{
                        Name = $instance.name
                        ResourceGroup = ($instance.id -split '/')[4]
                        Subscription = $subscription.name
                        SubscriptionId = $subscription.id
                        Location = $instance.location
                        HostName = $instance.hostName
                    }
                }
            }
        } 
        catch {
            # Continue if no instances found or error
        }
    }
}

# Switch back to original subscription
az account set --subscription $accountInfo.id | Out-Null

# Display found instances if any
if ($dtInstances.Count -gt 0) {
    Write-ColoredOutput "`nFound $($dtInstances.Count) Azure Digital Twins instance(s):" "Green"
    
    for ($i = 0; $i -lt $dtInstances.Count; $i++) {
        Write-ColoredOutput "[$($i + 1)] $($dtInstances[$i].Name) (Subscription: $($dtInstances[$i].Subscription), Resource Group: $($dtInstances[$i].ResourceGroup), Location: $($dtInstances[$i].Location))" "Cyan"
    }
    
    # Option to create a new instance
    Write-ColoredOutput "[N] Create a new Azure Digital Twins instance" "Yellow"
    
    $selection = Read-Host -Prompt "`nSelect an instance by number or 'N' to create a new one"
    
    # Handle selection
    if ($selection -match "^\d+$" -and [int]$selection -ge 1 -and [int]$selection -le $dtInstances.Count) {
        $selectedInstance = $dtInstances[[int]$selection - 1]
        $dtInstanceName = $selectedInstance.Name
        
        # Switch to the subscription where the instance is located
        if ($selectedInstance.SubscriptionId -ne $accountInfo.id) {
            Write-ColoredOutput "Switching to subscription: $($selectedInstance.Subscription)" "Yellow"
            az account set --subscription $selectedInstance.SubscriptionId | Out-Null
        }
        
        Write-ColoredOutput "Using Azure Digital Twins instance: $dtInstanceName" "Green"
        Write-ColoredOutput "Host name: $($selectedInstance.HostName)" "Green"
        
        # Set dtInstance for later use
        $dtInstance = @{
            hostName = $selectedInstance.HostName
            name = $selectedInstance.Name
            resourceGroup = $selectedInstance.ResourceGroup
        }
    }
    else {
        # User wants to create a new instance
        $createNew = $true
    }
}
else {
    Write-ColoredOutput "`nNo existing Azure Digital Twins instances found." "Yellow"
    $createNew = $true
}

# Create new instance if needed
if ($createNew) {
    $dtInstanceName = Read-Host -Prompt "`nEnter a name for your new Azure Digital Twins instance"
    while ([string]::IsNullOrWhiteSpace($dtInstanceName)) {
        Write-ColoredOutput "Instance name cannot be empty!" "Red"
        $dtInstanceName = Read-Host -Prompt "Enter a name for your new Azure Digital Twins instance"
    }
    
    $resourceGroup = Read-Host -Prompt "Enter resource group name (existing or new)"
    $location = Read-Host -Prompt "Enter location (e.g. eastus, westeurope)"
    
    # Check if resource group exists
    $rgExists = az group show --name $resourceGroup 2>&1
    if ($LASTEXITCODE -ne 0) {
        Write-ColoredOutput "Resource group '$resourceGroup' does not exist. Creating new resource group..." "Yellow"
        az group create --name $resourceGroup --location $location | Out-Null
    }
    
    Write-ColoredOutput "`nCreating Azure Digital Twins instance '$dtInstanceName'..." "Yellow"
    az dt create --dt-name $dtInstanceName --resource-group $resourceGroup --location $location
    
    if ($LASTEXITCODE -ne 0) {
        Write-ColoredOutput "Failed to create Azure Digital Twins instance. Please check your permissions and try again." "Red"
        exit
    }
    
    Write-ColoredOutput "Azure Digital Twins instance created successfully. ✓" "Green"
    
    # Get instance details
    $dtInstance = az dt show --dt-name $dtInstanceName --resource-group $resourceGroup | ConvertFrom-Json
    Write-ColoredOutput "Host name: $($dtInstance.hostName)" "Green"
}

# Upload models
$modelsPath = Join-Path $PSScriptRoot "models"
$modelsExist = Test-Path $modelsPath
if (-not $modelsExist) {
    Write-ColoredOutput "`nModels directory not found at: $modelsPath" "Red"
    Write-ColoredOutput "Please make sure the models directory exists with the DTDL model files." "Red"
    exit
}

Write-ColoredOutput "`nUploading DTDL models to Azure Digital Twins instance..." "Yellow"
Write-ColoredOutput "Models must be uploaded in dependency order." "Yellow"

# Get all model files
$modelFiles = Get-ChildItem -Path $modelsPath -Filter "*.json" | Select-Object -ExpandProperty Name
if ($modelFiles.Count -eq 0) {
    Write-ColoredOutput "No model files found in $modelsPath" "Red"
    exit
}

# Upload models command
$modelsParam = $modelFiles -join " "
$currentLocation = Get-Location
Set-Location $modelsPath

Write-ColoredOutput "Uploading models: $modelsParam" "Yellow"
$uploadCommand = "az dt model create --dt-name $dtInstanceName --models $modelsParam"
Write-ColoredOutput "Running: $uploadCommand" "Gray"

Invoke-Expression $uploadCommand

if ($LASTEXITCODE -eq 0) {
    Write-ColoredOutput "Models uploaded successfully. ✓" "Green"
}
else {
    Write-ColoredOutput "Failed to upload models. Please check errors above." "Red"
    Set-Location $currentLocation
    exit
}

Set-Location $currentLocation

# Step 4: Instantiate Twins and Define Relationships
Show-StepHeader "4" "Instantiate Twins and Define Relationships"

Write-ColoredOutput "`nNow we'll create digital twin instances based on the uploaded models." "Yellow"
Write-ColoredOutput "We'll create instances for each model type in our warehouse scenario." "Yellow"

# Create warehouse twin
$warehouseId = Read-Host -Prompt "`nEnter a name for your warehouse twin (e.g. warehouse01)"
if ([string]::IsNullOrWhiteSpace($warehouseId)) {
    $warehouseId = "warehouse01"
    Write-ColoredOutput "Using default name: $warehouseId" "Yellow"
}

Write-ColoredOutput "`nCreating warehouse twin '$warehouseId'..." "Yellow"
az dt twin create --dt-name $dtInstanceName --twin-id $warehouseId --model-id "dtmi:com:example:Warehouse;1"

if ($LASTEXITCODE -ne 0) {
    Write-ColoredOutput "Failed to create warehouse twin. Please check errors above." "Red"
}
else {
    Write-ColoredOutput "Warehouse twin created successfully. ✓" "Green"
    
    # Set properties for warehouse twin
    $warehouseLocation = Read-Host -Prompt "Enter warehouse location (e.g. Seattle, WA)"
    if ([string]::IsNullOrWhiteSpace($warehouseLocation)) {
        $warehouseLocation = "Seattle, WA"
        Write-ColoredOutput "Using default location: $warehouseLocation" "Yellow"
    }
    
    Write-ColoredOutput "Updating warehouse properties..." "Yellow"
    $jsonPatch = '[{"op":"add", "path":"/name", "value":"Main Warehouse"}, {"op":"add", "path":"/location", "value":"' + $warehouseLocation + '"}, {"op":"add", "path":"/area", "value":5000}, {"op":"add", "path":"/status", "value":"active"}]'
    az dt twin update --dt-name $dtInstanceName --twin-id $warehouseId --json-patch $jsonPatch
}

# Create zone twin
$zoneId = Read-Host -Prompt "`nEnter a name for your zone twin (e.g. zone01)"
if ([string]::IsNullOrWhiteSpace($zoneId)) {
    $zoneId = "zone01"
    Write-ColoredOutput "Using default name: $zoneId" "Yellow"
}

Write-ColoredOutput "`nCreating zone twin '$zoneId'..." "Yellow"
az dt twin create --dt-name $dtInstanceName --twin-id $zoneId --model-id "dtmi:com:example:Zone;1"

if ($LASTEXITCODE -ne 0) {
    Write-ColoredOutput "Failed to create zone twin. Please check errors above." "Red"
}
else {
    Write-ColoredOutput "Zone twin created successfully. ✓" "Green"
    
    # Set properties for zone twin
    Write-ColoredOutput "Updating zone properties..." "Yellow"
    $jsonPatch = '[{"op":"add", "path":"/name", "value":"Storage Zone"}, {"op":"add", "path":"/zoneType", "value":"storage"}, {"op":"add", "path":"/level", "value":1}]'
    az dt twin update --dt-name $dtInstanceName --twin-id $zoneId --json-patch $jsonPatch
    
    # Create relationship between warehouse and zone
    Write-ColoredOutput "Creating relationship between warehouse and zone..." "Yellow"
    $relationshipId = "${warehouseId}_contains_${zoneId}"
    $relationshipProps = '{"zoneName": "Storage Zone"}'
    az dt twin relationship create --dt-name $dtInstanceName --twin-id $warehouseId --relationship-id $relationshipId --target $zoneId --relationship-name "contains" --properties $relationshipProps
}

# Create shelf twin
$shelfId = Read-Host -Prompt "`nEnter a name for your shelf twin (e.g. shelf01)"
if ([string]::IsNullOrWhiteSpace($shelfId)) {
    $shelfId = "shelf01"
    Write-ColoredOutput "Using default name: $shelfId" "Yellow"
}

Write-ColoredOutput "`nCreating shelf twin '$shelfId'..." "Yellow"
az dt twin create --dt-name $dtInstanceName --twin-id $shelfId --model-id "dtmi:com:example:Shelf;1"

if ($LASTEXITCODE -ne 0) {
    Write-ColoredOutput "Failed to create shelf twin. Please check errors above." "Red"
}
else {
    Write-ColoredOutput "Shelf twin created successfully. ✓" "Green"
    
    # Set properties for shelf twin
    Write-ColoredOutput "Updating shelf properties..." "Yellow"
    $jsonPatch = '[{"op":"add", "path":"/shelfId", "value":"' + $shelfId + '"}, {"op":"add", "path":"/capacity", "value":100}, {"op":"add", "path":"/itemCount", "value":42}, {"op":"add", "path":"/shelfType", "value":"standard"}]'
    az dt twin update --dt-name $dtInstanceName --twin-id $shelfId --json-patch $jsonPatch
    
    # Create relationship between zone and shelf
    Write-ColoredOutput "Creating relationship between zone and shelf..." "Yellow"
    $relationshipId = "${zoneId}_contains_${shelfId}"
    $relationshipProps = '{"shelfId": "' + $shelfId + '"}'
    az dt twin relationship create --dt-name $dtInstanceName --twin-id $zoneId --relationship-id $relationshipId --target $shelfId --relationship-name "contains" --properties $relationshipProps
}

# Create sensor twin
$sensorId = Read-Host -Prompt "`nEnter a name for your sensor twin (e.g. sensor01)"
if ([string]::IsNullOrWhiteSpace($sensorId)) {
    $sensorId = "sensor01"
    Write-ColoredOutput "Using default name: $sensorId" "Yellow"
}

Write-ColoredOutput "`nCreating sensor twin '$sensorId'..." "Yellow"
az dt twin create --dt-name $dtInstanceName --twin-id $sensorId --model-id "dtmi:com:example:Sensor;1"

if ($LASTEXITCODE -ne 0) {
    Write-ColoredOutput "Failed to create sensor twin. Please check errors above." "Red"
}
else {
    Write-ColoredOutput "Sensor twin created successfully. ✓" "Green"
    
    # Set properties for sensor twin
    Write-ColoredOutput "Updating sensor properties..." "Yellow"
    $jsonPatch = '[{"op":"add", "path":"/sensorId", "value":"' + $sensorId + '"}, {"op":"add", "path":"/manufacturer", "value":"SensorCorp"}, {"op":"add", "path":"/modelNumber", "value":"SC-2025"}, {"op":"add", "path":"/sensorType", "value":"temperature"}, {"op":"add", "path":"/batteryLevel", "value":85}, {"op":"add", "path":"/status", "value":"online"}]'
    az dt twin update --dt-name $dtInstanceName --twin-id $sensorId --json-patch $jsonPatch
    
    # Create relationship between shelf and sensor
    Write-ColoredOutput "Creating relationship between shelf and sensor..." "Yellow"
    $relationshipId = "${shelfId}_hasSensor_${sensorId}"
    $relationshipProps = '{"sensorId": "' + $sensorId + '"}'
    az dt twin relationship create --dt-name $dtInstanceName --twin-id $shelfId --relationship-id $relationshipId --target $sensorId --relationship-name "hasSensor" --properties $relationshipProps
}

# Create robot twin
$robotId = Read-Host -Prompt "`nEnter a name for your robot twin (e.g. robot01)"
if ([string]::IsNullOrWhiteSpace($robotId)) {
    $robotId = "robot01"
    Write-ColoredOutput "Using default name: $robotId" "Yellow"
}

Write-ColoredOutput "`nCreating robot twin '$robotId'..." "Yellow"
az dt twin create --dt-name $dtInstanceName --twin-id $robotId --model-id "dtmi:com:example:Robot;1"

if ($LASTEXITCODE -ne 0) {
    Write-ColoredOutput "Failed to create robot twin. Please check errors above." "Red"
}
else {
    Write-ColoredOutput "Robot twin created successfully. ✓" "Green"
    
    # Set properties for robot twin
    Write-ColoredOutput "Updating robot properties..." "Yellow"
    $jsonPatch = '[{"op":"add", "path":"/robotId", "value":"' + $robotId + '"}, {"op":"add", "path":"/model", "value":"WarehouseBot 3000"}, {"op":"add", "path":"/manufacturer", "value":"RobotIndustries"}, {"op":"add", "path":"/batteryLevel", "value":92}, {"op":"add", "path":"/status", "value":"idle"}, {"op":"add", "path":"/currentZone", "value":"' + $zoneId + '"}]'
    az dt twin update --dt-name $dtInstanceName --twin-id $robotId --json-patch $jsonPatch
}

# Step 5: Connect IoT Devices via IoT Hub (Optional)
Show-StepHeader "5" "Connect IoT Devices via IoT Hub (Optional)"

$setupIoTHub = Read-Host -Prompt "`nDo you want to set up IoT Hub integration? This is optional but recommended for a complete demo. (y/n)"
if ($setupIoTHub -eq "y") {
    # Get IoT Hub details
    $iotHubName = Read-Host -Prompt "`nEnter a name for your IoT Hub (e.g. WarehouseIoTHub)"
    if ([string]::IsNullOrWhiteSpace($iotHubName)) {
        $iotHubName = "WarehouseIoTHub$(Get-Random -Minimum 1000 -Maximum 9999)"
        Write-ColoredOutput "Using generated name: $iotHubName" "Yellow"
    }
    
    # Get resource group
    $resourceGroup = Read-Host -Prompt "Enter resource group name for IoT Hub"
    
    # Create IoT Hub
    Write-ColoredOutput "`nCreating IoT Hub '$iotHubName'..." "Yellow"
    az iot hub create --name $iotHubName --resource-group $resourceGroup --sku S1
    
    if ($LASTEXITCODE -ne 0) {
        Write-ColoredOutput "Failed to create IoT Hub. Please check errors above." "Red"
        Write-ColoredOutput "You can create an IoT Hub manually in the Azure portal." "Yellow"
    }
    else {
        Write-ColoredOutput "IoT Hub created successfully. ✓" "Green"
        
        # Register a device
        $deviceId = Read-Host -Prompt "`nEnter a name for your IoT device (e.g. WarehouseSensor01)"
        if ([string]::IsNullOrWhiteSpace($deviceId)) {
            $deviceId = "WarehouseSensor01"
            Write-ColoredOutput "Using default name: $deviceId" "Yellow"
        }
        
        Write-ColoredOutput "Registering device '$deviceId' in IoT Hub..." "Yellow"
        az iot hub device-identity create --hub-name $iotHubName --device-id $deviceId
        
        if ($LASTEXITCODE -eq 0) {
            Write-ColoredOutput "Device registered successfully. ✓" "Green"
            
            # Get connection string
            $connectionString = az iot hub device-identity connection-string show --hub-name $iotHubName --device-id $deviceId --query connectionString -o tsv
            
            Write-ColoredOutput "`nDevice connection string:" "Magenta"
            Write-ColoredOutput $connectionString "Yellow"
            Write-ColoredOutput "`nSave this connection string for use in your device code!" "Red"
        }
    }
}
else {
    Write-ColoredOutput "`nSkipping IoT Hub setup. You can set this up later if needed." "Yellow"
}

# Step 6: Optional - Create Azure Function for Routing (Very simplified version)
Show-StepHeader "6" "Create Azure Function for Routing (Optional)"

$setupFunction = Read-Host -Prompt "`nDo you want to create an Azure Function for routing telemetry? This is optional. (y/n)"
if ($setupFunction -eq "y") {
    Write-ColoredOutput "`nTo create an Azure Function App for routing telemetry:" "Yellow"
    Write-ColoredOutput "1. Go to the Azure portal and create a new Function App" "Yellow"
    Write-ColoredOutput "2. Create an IoT Hub trigger function" "Yellow"
    Write-ColoredOutput "3. Use the Azure Digital Twins SDK to update twin data" "Yellow"
    
    Write-ColoredOutput "`nFor a full implementation, please refer to the Azure Digital Twins documentation." "Yellow"
    Start-Process "https://learn.microsoft.com/en-us/azure/digital-twins/how-to-ingest-iot-hub-data"
}
else {
    Write-ColoredOutput "`nSkipping Azure Function setup. You can set this up later if needed." "Yellow"
}

# Step 7: Visualize Using Digital Twins Explorer
Show-StepHeader "7" "Visualize Using Digital Twins Explorer"

Write-ColoredOutput "`nWould you like to download and use the Azure Digital Twins Explorer to visualize your digital twin graph?" "Yellow"
$setupExplorer = Read-Host -Prompt "Open the Digital Twins Explorer documentation? (y/n)"

if ($setupExplorer -eq "y") {
    Start-Process "https://learn.microsoft.com/en-us/azure/digital-twins/overview-digital-twins-explorer"
    
    Write-ColoredOutput "`nFollow the documentation to download and connect the Explorer to your Azure Digital Twins instance:" "Yellow"
    
    # Get the correct host URL depending on available information
    if ($dtInstance -and $dtInstance.hostName) {
        Write-ColoredOutput "Host URL: https://$($dtInstance.hostName)" "Green"
    }
    else {
        Write-ColoredOutput "Host URL: https://$($dtInstanceName).digitaltwins.azure.net" "Green"
    }
}

# Completion
Write-ColoredOutput "`n`n====================================================" "Green"
Write-ColoredOutput "       AZURE DIGITAL TWINS DEPLOYMENT COMPLETE" "Green"
Write-ColoredOutput "====================================================" "Green"

Write-ColoredOutput "`nYour digital twin deployment is now complete!" "Yellow"
Write-ColoredOutput "Here's a summary of what you've deployed:" "Yellow"
Write-ColoredOutput "- Azure Digital Twins instance: $dtInstanceName" "Cyan"
Write-ColoredOutput "- Warehouse twin: $warehouseId" "Cyan"
Write-ColoredOutput "- Zone twin: $zoneId" "Cyan"
Write-ColoredOutput "- Shelf twin: $shelfId" "Cyan"
Write-ColoredOutput "- Sensor twin: $sensorId" "Cyan"
Write-ColoredOutput "- Robot twin: $robotId" "Cyan"

if ($setupIoTHub -eq "y") {
    Write-ColoredOutput "- IoT Hub: $iotHubName" "Cyan"
    Write-ColoredOutput "- IoT Device: $deviceId" "Cyan"
}

Write-ColoredOutput "`nNext steps:" "Magenta"
Write-ColoredOutput "1. Use the Digital Twins Explorer to visualize your digital twin graph" "White"
Write-ColoredOutput "2. Connect real or simulated devices to update your digital twins" "White"
Write-ColoredOutput "3. Explore querying and analyzing your digital twin data" "White"

Write-ColoredOutput "`nThank you for using the Azure Digital Twins Demo Deployment Wizard!" "Green"
