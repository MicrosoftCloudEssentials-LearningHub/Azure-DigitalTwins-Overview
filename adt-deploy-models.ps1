# Azure Digital Twins Model Deployment Script
# This script deploys DTDL model files to an Azure Digital Twins instance and creates basic twins

# Script parameters
param (
    [string]$SubscriptionId = "",
    [string]$ResourceGroup = "",
    [string]$DTInstanceName = ""
)

# Function to display colored messages without special characters
function Write-ColorOutput {
    param (
        [string]$Message,
        [string]$ForegroundColor = "White"
    )
    
    Write-Host $Message -ForegroundColor $ForegroundColor
}

# Function to display step headers
function Show-StepHeader {
    param (
        [string]$StepNumber,
        [string]$StepTitle
    )
    
    Write-ColorOutput "`n========== STEP $StepNumber`: $StepTitle ==========" "Cyan"
}

# Display title
Clear-Host
Write-ColorOutput "`n====================================================" "Green"
Write-ColorOutput "       AZURE DIGITAL TWINS MODEL DEPLOYMENT" "Green"
Write-ColorOutput "====================================================" "Green"
Write-ColorOutput "`nThis script will deploy the warehouse digital twin models." "Yellow"

# Check if Azure CLI is installed
$azCliInstalled = $null -ne (Get-Command "az" -ErrorAction SilentlyContinue)
if (-not $azCliInstalled) {
    Write-ColorOutput "`nAzure CLI is not installed." "Red"
    Write-ColorOutput "Please install Azure CLI from: https://learn.microsoft.com/en-us/cli/azure/install-azure-cli" "Yellow"
    exit
}
else {
    Write-ColorOutput "Azure CLI is installed." "Green"
}

# Login to Azure if needed
$loggedIn = $false
try {
    $accountInfo = az account show 2>$null | ConvertFrom-Json
    $loggedIn = $true
    Write-ColorOutput "You are logged in to Azure as: $($accountInfo.user.name)" "Green"
    Write-ColorOutput "Subscription: $($accountInfo.name) ($($accountInfo.id))" "Green"
} 
catch {
    Write-ColorOutput "Not logged in to Azure." "Yellow"
    
    Write-ColorOutput "Logging in to Azure..." "Yellow"
    az login --use-device-code
    
    if ($LASTEXITCODE -ne 0) {
        Write-ColorOutput "Failed to log in to Azure. Please restart the script and try again." "Red"
        exit
    }
    
    $accountInfo = az account show | ConvertFrom-Json
    Write-ColorOutput "Successfully logged in to Azure as: $($accountInfo.user.name)" "Green"
    $loggedIn = $true
}

# If a specific subscription ID was provided, use it
if (-not [string]::IsNullOrWhiteSpace($SubscriptionId)) {
    Write-ColorOutput "Switching to specified subscription..." "Yellow"
    az account set --subscription $SubscriptionId
    $accountInfo = az account show | ConvertFrom-Json
    Write-ColorOutput "Using subscription: $($accountInfo.name) ($($accountInfo.id))" "Green"
}

# Get Azure Digital Twins instance name if not provided
if ([string]::IsNullOrWhiteSpace($DTInstanceName)) {
    # List digital twins instances in the current subscription
    Write-ColorOutput "Searching for Azure Digital Twins instances..." "Yellow"
    $dtInstances = az dt list | ConvertFrom-Json
    
    if ($dtInstances.Count -gt 0) {
        Write-ColorOutput "Found $($dtInstances.Count) Azure Digital Twins instance(s):" "Green"
        
        for ($i = 0; $i -lt $dtInstances.Count; $i++) {
            Write-ColorOutput "[$($i + 1)] $($dtInstances[$i].name) (Resource Group: $($dtInstances[$i].resourceGroup), Location: $($dtInstances[$i].location))" "Cyan"
        }
        
        $selection = Read-Host -Prompt "Select an instance by number or enter a new name"
        
        if ($selection -match "^\d+$" -and [int]$selection -ge 1 -and [int]$selection -le $dtInstances.Count) {
            $DTInstanceName = $dtInstances[[int]$selection - 1].name
            $ResourceGroup = ($dtInstances[[int]$selection - 1].id -split '/')[4]
            Write-ColorOutput "Using Azure Digital Twins instance: $DTInstanceName" "Green"
        }
        else {
            $DTInstanceName = $selection
            if ([string]::IsNullOrWhiteSpace($ResourceGroup)) {
                $ResourceGroup = Read-Host -Prompt "Enter resource group name"
            }
            
            # Check if instance exists
            $instanceExists = $false
            try {
                $instance = az dt show --dt-name $DTInstanceName --resource-group $ResourceGroup 2>$null
                $instanceExists = $true
            }
            catch {
                $instanceExists = $false
            }
            
            if (-not $instanceExists) {
                $location = Read-Host -Prompt "Enter Azure region (e.g., eastus, westus2)"
                Write-ColorOutput "Creating Azure Digital Twins instance '$DTInstanceName'..." "Yellow"
                az dt create --dt-name $DTInstanceName --resource-group $ResourceGroup --location $location
                
                if ($LASTEXITCODE -ne 0) {
                    Write-ColorOutput "Failed to create Azure Digital Twins instance. Please check your permissions and try again." "Red"
                    exit
                }
            }
        }
    }
    else {
        Write-ColorOutput "No existing Azure Digital Twins instances found." "Yellow"
        $DTInstanceName = Read-Host -Prompt "Enter a name for your new Azure Digital Twins instance"
        
        if ([string]::IsNullOrWhiteSpace($ResourceGroup)) {
            $ResourceGroup = Read-Host -Prompt "Enter resource group name"
        }
        
        $location = Read-Host -Prompt "Enter Azure region (e.g., eastus, westus2)"
        Write-ColorOutput "Creating Azure Digital Twins instance '$DTInstanceName'..." "Yellow"
        az dt create --dt-name $DTInstanceName --resource-group $ResourceGroup --location $location
        
        if ($LASTEXITCODE -ne 0) {
            Write-ColorOutput "Failed to create Azure Digital Twins instance. Please check your permissions and try again." "Red"
            exit
        }
    }
}

Show-StepHeader "1" "Upload Models to Azure Digital Twins"

# Verify models directory exists
$modelsPath = Join-Path $PSScriptRoot "models"
if (-not (Test-Path $modelsPath)) {
    Write-ColorOutput "Models directory not found at: $modelsPath" "Red"
    exit
}

# Ensure current user has data access role
Write-ColorOutput "Ensuring current user has Azure Digital Twins Data Owner role..." "Yellow"
$currentUserId = az ad signed-in-user show --query id -o tsv

if ($LASTEXITCODE -eq 0) {
    # Check if role assignment exists
    Write-ColorOutput "Current User ID: $currentUserId" "Green"
    $roleAssignment = az dt role-assignment create --dt-name $DTInstanceName --assignee "$currentUserId" --role "Azure Digital Twins Data Owner" 2>&1
    Write-ColorOutput "Role assignment created or already exists." "Green"
    
    # Wait for role assignment to propagate
    Write-ColorOutput "Waiting 30 seconds for role assignment to propagate..." "Yellow"
    Start-Sleep -Seconds 30
}

# Upload models
Write-ColorOutput "Uploading DTDL models to Azure Digital Twins instance..." "Yellow"
Set-Location $modelsPath

# Define model files in dependency order (warehouse depends on zone, zone depends on shelf, etc.)
$modelFiles = @("warehouse.json", "zone.json", "shelf.json", "sensor.json", "robot.json")

foreach ($model in $modelFiles) {
    if (Test-Path $model) {
        Write-ColorOutput "Uploading model: $model" "Yellow"
        az dt model create --dt-name $DTInstanceName --models $model
        
        # Add a small delay between model uploads
        Start-Sleep -Seconds 2
        
        if ($LASTEXITCODE -eq 0) {
            Write-ColorOutput "Model $model uploaded successfully." "Green"
        } else {
            Write-ColorOutput "Failed to upload model $model. Please check errors above." "Red"
        }
    } else {
        Write-ColorOutput "Model file not found: $model" "Red"
    }
}

# Return to original directory
Set-Location $PSScriptRoot

Show-StepHeader "2" "Create Digital Twin Instances"

# Create digital twins
Write-ColorOutput "Creating digital twin instances..." "Yellow"

# Warehouse twin
$warehouseId = "warehouse01"
Write-ColorOutput "Creating warehouse twin '$warehouseId'..." "Yellow"
az dt twin create --dt-name $DTInstanceName --twin-id $warehouseId --model-id "dtmi:com:example:Warehouse;1"

# Zone twin
$zoneId = "zone01"
Write-ColorOutput "Creating zone twin '$zoneId'..." "Yellow"
az dt twin create --dt-name $DTInstanceName --twin-id $zoneId --model-id "dtmi:com:example:Zone;1"

# Shelf twin
$shelfId = "shelf01"
Write-ColorOutput "Creating shelf twin '$shelfId'..." "Yellow"
az dt twin create --dt-name $DTInstanceName --twin-id $shelfId --model-id "dtmi:com:example:Shelf;1"

# Sensor twin
$sensorId = "sensor01"
Write-ColorOutput "Creating sensor twin '$sensorId'..." "Yellow"
az dt twin create --dt-name $DTInstanceName --twin-id $sensorId --model-id "dtmi:com:example:Sensor;1"

# Robot twin
$robotId = "robot01"
Write-ColorOutput "Creating robot twin '$robotId'..." "Yellow"
az dt twin create --dt-name $DTInstanceName --twin-id $robotId --model-id "dtmi:com:example:Robot;1"

Show-StepHeader "3" "Create Relationships Between Twins"

# Create relationships
Write-ColorOutput "Creating relationships between twins..." "Yellow"

# Warehouse contains Zone
Write-ColorOutput "Creating relationship: Warehouse contains Zone" "Yellow"
az dt twin relationship create --dt-name $DTInstanceName --twin-id $warehouseId --relationship-id "rel1" --target $zoneId --relationship "contains"

# Zone contains Shelf
Write-ColorOutput "Creating relationship: Zone contains Shelf" "Yellow"
az dt twin relationship create --dt-name $DTInstanceName --twin-id $zoneId --relationship-id "rel2" --target $shelfId --relationship "contains"

# Shelf has Sensor
Write-ColorOutput "Creating relationship: Shelf has Sensor" "Yellow"
az dt twin relationship create --dt-name $DTInstanceName --twin-id $shelfId --relationship-id "rel3" --target $sensorId --relationship "hasSensor"

Show-StepHeader "4" "Visualize Using Digital Twins Explorer"

# Get Digital Twins Explorer URL
$tenantId = az account show --query tenantId -o tsv
$explorerUrl = "https://explorer.digitaltwins.azure.net/?tid=$tenantId&eid=$DTInstanceName"

Write-ColorOutput "Your Digital Twins instance is ready for visualization!" "Green"
Write-ColorOutput "To open Digital Twins Explorer, visit:" "Yellow"
Write-ColorOutput $explorerUrl "Cyan"

Write-ColorOutput "`nDeployment complete! Your Azure Digital Twins warehouse demo has been deployed." "Green"
Write-ColorOutput "Summary of created resources:" "Cyan"
Write-ColorOutput "- Digital Twins Instance: $DTInstanceName" "Cyan"
Write-ColorOutput "- Warehouse twin: $warehouseId" "Cyan"
Write-ColorOutput "- Zone twin: $zoneId" "Cyan"
Write-ColorOutput "- Shelf twin: $shelfId" "Cyan"
Write-ColorOutput "- Sensor twin: $sensorId" "Cyan"
Write-ColorOutput "- Robot twin: $robotId" "Cyan"
