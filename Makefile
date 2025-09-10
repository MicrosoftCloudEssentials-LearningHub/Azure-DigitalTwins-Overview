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
	@echo "  deploy       - Run the Digital Twins deployment script"
	@echo "  deploy-skip  - Run the deployment script but skip installation checks"
	@echo "  help         - Show this help message"
	@echo ""
	@echo "Usage examples:"
	@echo "  make deploy       # Run the full deployment script"
	@echo "  make deploy-skip  # Skip installation checks during deployment"

# Run the PowerShell deployment script
.PHONY: deploy
deploy:
	@echo "Running Azure Digital Twins deployment script..."
	powershell.exe -ExecutionPolicy Bypass -File deploy-digital-twins.ps1

# Run the PowerShell deployment script with skip installation flag
.PHONY: deploy-skip
deploy-skip:
	@echo "Running Azure Digital Twins deployment script (skipping installation checks)..."
	powershell.exe -ExecutionPolicy Bypass -File deploy-digital-twins.ps1 -SkipInstallation
