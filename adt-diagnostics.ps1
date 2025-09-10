# Azure Digital Twins Diagnostic Tool
# This script helps troubleshoot Azure Digital Twins deployments

# Check if Azure CLI is installed
$azCliInstalled = Get-Command az -ErrorAction SilentlyContinue
if (-not $azCliInstalled) {
    Write-Error "Azure CLI is not installed. Please install it from https://docs.microsoft.com/en-us/cli/azure/install-azure-cli"
    exit 1
}

# Check if user is logged in to Azure
$loginStatus = az account show --query name -o tsv 2>$null
if (-not $loginStatus) {
    Write-Host "You need to log in to Azure first."
    az login
}

# Function to display colored output
function Write-ColoredOutput {
    param (
        [string]$Message,
        [string]$ForegroundColor = "White"
    )
    
    Write-Host $Message -ForegroundColor $ForegroundColor
}

# Function to display section header
function Show-SectionHeader {
    param (
        [string]$Title
    )
    
    Write-ColoredOutput "`n========== $Title ==========" "Cyan"
}

# Title
Clear-Host
Write-ColoredOutput "`n====================================================" "Green"
Write-ColoredOutput "       AZURE DIGITAL TWINS DIAGNOSTICS TOOL" "Green"
Write-ColoredOutput "====================================================" "Green"

# Get subscription information
Show-SectionHeader "SUBSCRIPTION INFORMATION"
$subscription = az account show | ConvertFrom-Json
Write-ColoredOutput "Current subscription: $($subscription.name) ($($subscription.id))" "Yellow"

# List all available Digital Twins instances
Show-SectionHeader "DIGITAL TWINS INSTANCES"
$dtInstances = az dt list | ConvertFrom-Json
if ($dtInstances.Count -eq 0) {
    Write-ColoredOutput "No Digital Twins instances found in the current subscription." "Red"
    exit 1
}

# Display all Digital Twins instances
Write-ColoredOutput "Found $($dtInstances.Count) Digital Twins instance(s):" "Yellow"
for ($i = 0; $i -lt $dtInstances.Count; $i++) {
    Write-ColoredOutput "[$($i + 1)] $($dtInstances[$i].name) (Resource Group: $($dtInstances[$i].resourceGroup), Location: $($dtInstances[$i].location))" "White"
}

# Ask user to select a Digital Twins instance
$selection = Read-Host -Prompt "`nSelect a Digital Twins instance by number"
if ($selection -match "^\d+$" -and [int]$selection -ge 1 -and [int]$selection -le $dtInstances.Count) {
    $selectedInstance = $dtInstances[[int]$selection - 1]
    $dtInstanceName = $selectedInstance.name
    Write-ColoredOutput "Selected Digital Twins instance: $dtInstanceName" "Green"
}
else {
    Write-ColoredOutput "Invalid selection. Exiting." "Red"
    exit 1
}

# Check models
Show-SectionHeader "MODELS"
$models = az dt model list --dt-name $dtInstanceName | ConvertFrom-Json
if ($models.Count -eq 0) {
    Write-ColoredOutput "No models found in the Digital Twins instance." "Red"
    
    # Ask if user wants to upload models
    $uploadModels = Read-Host -Prompt "Do you want to upload models from the 'models' directory? (y/n)"
    if ($uploadModels -eq "y") {
        $modelsPath = Join-Path $PSScriptRoot "models"
        $modelFiles = Get-ChildItem -Path $modelsPath -Filter "*.json"
        
        if ($modelFiles.Count -eq 0) {
            Write-ColoredOutput "No model files found in $modelsPath" "Red"
            exit 1
        }
        
# Define dependency order based on your models
$dependencyOrder = @("warehouse.json", "zone.json", "shelf.json", "robot.json", "sensor.json")
$uploadedModels = @()

# Upload models in dependency order first
foreach ($model in $dependencyOrder) {
    $modelPath = Join-Path $modelsPath $model
    if (Test-Path $modelPath) {
        Write-ColoredOutput "Uploading model: $model" "Yellow"
        $uploadCommand = "az dt model create --dt-name $dtInstanceName --models $modelPath"
        Write-ColoredOutput "Running: $uploadCommand" "Gray"
        Invoke-Expression $uploadCommand
        
        # Add a small delay between model uploads
        Start-Sleep -Seconds 2
        
        if ($LASTEXITCODE -eq 0) {
            Write-ColoredOutput "Model $model uploaded successfully. ✓" "Green"
            $uploadedModels += $model
        } else {
            Write-ColoredOutput "Failed to upload model $model. Please check errors above." "Red"
        }
    }
}        # Upload any remaining models
        foreach ($modelFile in $modelFiles) {
            if ($uploadedModels -notcontains $modelFile.Name) {
                Write-ColoredOutput "Uploading additional model: $($modelFile.Name)" "Yellow"
                $uploadCommand = "az dt model create --dt-name $dtInstanceName --models $($modelFile.FullName)"
                Write-ColoredOutput "Running: $uploadCommand" "Gray"
                Invoke-Expression $uploadCommand
                
                if ($LASTEXITCODE -eq 0) {
                    Write-ColoredOutput "Model $($modelFile.Name) uploaded successfully. ✓" "Green"
                } else {
                    Write-ColoredOutput "Failed to upload model $($modelFile.Name). Please check errors above." "Red"
                }
            }
        }
        
        # Refresh models list
        $models = az dt model list --dt-name $dtInstanceName | ConvertFrom-Json
    }
}

# Display models
if ($models.Count -gt 0) {
    Write-ColoredOutput "Found $($models.Count) model(s):" "Yellow"
    foreach ($model in $models) {
        Write-ColoredOutput "- $($model.id) (Uploaded: $($model.uploadTime))" "White"
    }
}

# Check twins
Show-SectionHeader "DIGITAL TWINS"
$twins = az dt twin list --dt-name $dtInstanceName | ConvertFrom-Json
if ($twins.Count -eq 0) {
    Write-ColoredOutput "No twins found in the Digital Twins instance." "Red"
    
    # Ask if user wants to create sample twins
    $createTwins = Read-Host -Prompt "Do you want to create sample twins? (y/n)"
    if ($createTwins -eq "y") {
        # Check if we have the necessary models
        $requiredModels = @(
            "dtmi:com:example:Warehouse;1",
            "dtmi:com:example:Zone;1",
            "dtmi:com:example:Shelf;1",
            "dtmi:com:example:Robot;1",
            "dtmi:com:example:Sensor;1"
        )
        
        $modelIds = $models | ForEach-Object { $_.id }
        $missingModels = $requiredModels | Where-Object { $modelIds -notcontains $_ }
        
        if ($missingModels.Count -gt 0) {
            Write-ColoredOutput "Missing required models: $($missingModels -join ', ')" "Red"
            Write-ColoredOutput "Please upload all required models before creating twins." "Red"
            exit 1
        }
        
        # Create Warehouse twin
        Write-ColoredOutput "Creating Warehouse twin..." "Yellow"
        az dt twin create --dt-name $dtInstanceName --twin-id "Warehouse_01" --model-id "dtmi:com:example:Warehouse;1" --properties '{"name": "Main Warehouse", "location": "123 Factory Road", "area": 15000, "status": "active"}'
        
        # Create Zones
        Write-ColoredOutput "Creating Zone twins..." "Yellow"
        az dt twin create --dt-name $dtInstanceName --twin-id "Zone_01" --model-id "dtmi:com:example:Zone;1" --properties '{"name": "Storage Zone", "zoneType": "storage", "level": 1}'
        az dt twin create --dt-name $dtInstanceName --twin-id "Zone_02" --model-id "dtmi:com:example:Zone;1" --properties '{"name": "Shipping Zone", "zoneType": "shipping", "level": 1}'
        
        # Create Shelves
        Write-ColoredOutput "Creating Shelf twins..." "Yellow"
        az dt twin create --dt-name $dtInstanceName --twin-id "Shelf_01" --model-id "dtmi:com:example:Shelf;1" --properties '{"shelfId": "SH001", "capacity": 100, "itemCount": 75, "shelfType": "standard"}'
        az dt twin create --dt-name $dtInstanceName --twin-id "Shelf_02" --model-id "dtmi:com:example:Shelf;1" --properties '{"shelfId": "SH002", "capacity": 150, "itemCount": 120, "shelfType": "heavyDuty"}'
        
        # Create Robot
        Write-ColoredOutput "Creating Robot twin..." "Yellow"
        az dt twin create --dt-name $dtInstanceName --twin-id "Robot_01" --model-id "dtmi:com:example:Robot;1" --properties '{"robotId": "RB001", "model": "PickerBot 3000", "manufacturer": "RobotCorp", "batteryLevel": 95, "status": "idle", "currentZone": "Zone_01"}'
        
        # Create Sensor
        Write-ColoredOutput "Creating Sensor twin..." "Yellow"
        az dt twin create --dt-name $dtInstanceName --twin-id "Sensor_01" --model-id "dtmi:com:example:Sensor;1" --properties '{"sensorId": "SENS001", "manufacturer": "SensorTech", "modelNumber": "ST-100", "sensorType": "temperature", "batteryLevel": 87, "status": "online"}'
        
        # Create relationships
        Write-ColoredOutput "Creating relationships between twins..." "Yellow"
        
# Warehouse contains Zones
az dt twin relationship create --dt-name $dtInstanceName --relationship-id "Warehouse_Zone_01" --source-id "Warehouse_01" --target-id "Zone_01" --relationship "contains"
az dt twin relationship create --dt-name $dtInstanceName --relationship-id "Warehouse_Zone_02" --source-id "Warehouse_01" --target-id "Zone_02" --relationship "contains"

# Zones contain Shelves
az dt twin relationship create --dt-name $dtInstanceName --relationship-id "Zone_Shelf_01" --source-id "Zone_01" --target-id "Shelf_01" --relationship "contains"
az dt twin relationship create --dt-name $dtInstanceName --relationship-id "Zone_Shelf_02" --source-id "Zone_01" --target-id "Shelf_02" --relationship "contains"

# Robot is in Zone
az dt twin relationship create --dt-name $dtInstanceName --relationship-id "Robot_Zone_01" --source-id "Robot_01" --target-id "Zone_01" --relationship "isIn"

# Sensor is on Shelf
az dt twin relationship create --dt-name $dtInstanceName --relationship-id "Sensor_Shelf_01" --source-id "Sensor_01" --target-id "Shelf_01" --relationship "isOn"        # Refresh twins list
        $twins = az dt twin list --dt-name $dtInstanceName | ConvertFrom-Json
    }
}

# Display twins
if ($twins.Count -gt 0) {
    Write-ColoredOutput "Found $($twins.Count) twin(s):" "Yellow"
    foreach ($twin in $twins) {
        Write-ColoredOutput "- $($twin.$dtId) (Model: $($twin.$metadata.$model))" "White"
    }
}

# Check relationships
Show-SectionHeader "RELATIONSHIPS"
$relationships = az dt twin relationship list --dt-name $dtInstanceName --twin-id "Warehouse_01" 2>$null | ConvertFrom-Json
if ($relationships.Count -gt 0) {
    Write-ColoredOutput "Found relationships for Warehouse_01:" "Yellow"
    foreach ($rel in $relationships) {
        Write-ColoredOutput "- $($rel.$relationshipName): $($rel.$targetId)" "White"
    }
}
else {
    Write-ColoredOutput "No relationships found for Warehouse_01. This might be normal if you haven't created this twin." "Yellow"
}

# Check role assignments
Show-SectionHeader "ROLE ASSIGNMENTS"
$roles = az dt role-assignment list --dt-name $dtInstanceName | ConvertFrom-Json
if ($roles.Count -gt 0) {
    Write-ColoredOutput "Found $($roles.Count) role assignment(s):" "Yellow"
    foreach ($role in $roles) {
        Write-ColoredOutput "- $($role.roleDefinitionName): $($role.principalId)" "White"
    }
}
else {
    Write-ColoredOutput "No role assignments found. This might cause permission issues." "Red"
    
    # Ask if user wants to create role assignment
    $createRole = Read-Host -Prompt "Do you want to create a role assignment for the current user? (y/n)"
    if ($createRole -eq "y") {
        $currentUserId = az ad signed-in-user show --query id -o tsv
        if ($LASTEXITCODE -eq 0) {
            Write-ColoredOutput "Current User ID: $currentUserId" "Green"
            Write-ColoredOutput "Creating role assignment for the current user..." "Yellow"
            az dt role-assignment create --dt-name $dtInstanceName --assignee "$currentUserId" --role "Azure Digital Twins Data Owner"
            
            if ($LASTEXITCODE -eq 0) {
                Write-ColoredOutput "Role assignment created successfully. ✓" "Green"
                Write-ColoredOutput "Waiting 30 seconds for role assignment to propagate..." "Yellow"
                Start-Sleep -Seconds 30
            }
            else {
                Write-ColoredOutput "Failed to create role assignment. Please check errors above." "Red"
            }
        }
        else {
            Write-ColoredOutput "Failed to get current user ID." "Red"
        }
    }
}

# Provide guidance on next steps
Show-SectionHeader "NEXT STEPS"
Write-ColoredOutput "1. To visualize your digital twins, use the Azure Digital Twins Explorer:" "White"
Write-ColoredOutput "   https://explorer.digitaltwins.azure.net" "Cyan"
Write-ColoredOutput "2. To query your digital twins, use the query explorer in the Azure portal" "White"
Write-ColoredOutput "3. To learn more about Azure Digital Twins, visit:" "White"
Write-ColoredOutput "   https://learn.microsoft.com/en-us/azure/digital-twins/" "Cyan"

# Keep window open
Read-Host -Prompt "`nPress Enter to close this window"
