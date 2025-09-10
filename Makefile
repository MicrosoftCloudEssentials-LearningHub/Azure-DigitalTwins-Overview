# Makefile for Azure Digital Twins Demo
# This Makefile provides commands to run the Digital Twins deployment script

# Default target
.PHONY: all
all: help

# Help message
.PHONY: help
help:
	@echo "Azure Digital Twins Demo Makefile"
	@echo "----------------------------------"
	@echo "Available targets:"
	@echo "  deploy          - Run the Digital Twins deployment script"
	@echo "  deploy-skip     - Run the deployment script but skip installation checks"
	@echo "  deploy-secure   - Run the script respecting execution policy (requires admin approval)"
	@echo "  deploy-simple   - Run the simplified model deployment script"
	@echo "  diagnostics     - Run diagnostics to troubleshoot Digital Twins issues"
	@echo "  infrastructure  - Deploy Azure infrastructure using Terraform"
	@echo "  help            - Show this help message"
	@echo ""
	@echo "Usage examples:"
	@echo "  make deploy          # Run the full deployment script"
	@echo "  make deploy-skip     # Skip installation checks during deployment"
	@echo "  make deploy-secure   # Run without bypassing execution policy"
	@echo "  make deploy-simple   # Run simplified model deployment only"
	@echo "  make diagnostics     # Run diagnostics to troubleshoot issues"
	@echo "  make infrastructure  # Deploy the infrastructure with Terraform"

# Run the PowerShell deployment script
.PHONY: deploy
deploy:
	@echo "Running Azure Digital Twins deployment script..."
	@echo "Unblocking script file to mark it as trusted..."
	powershell.exe -Command "Unblock-File -Path '$(CURDIR)\adt-deploy-full.ps1'"
	powershell.exe -NoExit -ExecutionPolicy RemoteSigned -Command "& '$(CURDIR)\adt-deploy-full.ps1'"

# Run the PowerShell deployment script with skip installation flag
.PHONY: deploy-skip
deploy-skip:
	@echo "Running Azure Digital Twins deployment script (skipping installation checks)..."
	@echo "Unblocking script file to mark it as trusted..."
	powershell.exe -Command "Unblock-File -Path '$(CURDIR)\adt-deploy-full.ps1'"
	powershell.exe -NoExit -ExecutionPolicy RemoteSigned -Command "& '$(CURDIR)\adt-deploy-full.ps1' -SkipInstallation"

# Deploy Azure infrastructure using Terraform
.PHONY: infrastructure
infrastructure:
	@echo "Deploying Azure infrastructure using Terraform..."
	cd terraform-infrastructure && terraform init && terraform apply

# Run the PowerShell deployment script without bypassing execution policy
.PHONY: deploy-secure
deploy-secure:
	@echo "Running Azure Digital Twins deployment script with secure execution policy..."
	@echo "Note: This may require approval or a signed script depending on your system settings."
	powershell.exe -Command "& { $ErrorActionPreference = 'Stop'; Unblock-File -Path '$(CURDIR)\adt-deploy-full.ps1'; & '$(CURDIR)\adt-deploy-full.ps1' }"

# Run the PowerShell diagnostics script
.PHONY: diagnostics
diagnostics:
	@echo "Running Azure Digital Twins diagnostics tool..."
	@echo "Unblocking script file to mark it as trusted..."
	powershell.exe -Command "Unblock-File -Path '$(CURDIR)\adt-diagnostics.ps1'"
	powershell.exe -NoExit -ExecutionPolicy RemoteSigned -Command "& '$(CURDIR)\adt-diagnostics.ps1'"

# Run the simplified model deployment script
.PHONY: deploy-simple
deploy-simple:
	@echo "Running simplified Azure Digital Twins model deployment script..."
	@echo "Unblocking script file to mark it as trusted..."
	powershell.exe -Command "Unblock-File -Path '$(CURDIR)\adt-deploy-models.ps1'"
	powershell.exe -NoExit -ExecutionPolicy RemoteSigned -Command "& '$(CURDIR)\adt-deploy-models.ps1'"
