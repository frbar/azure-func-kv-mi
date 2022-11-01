# Purpose

This repository contains a Bicep template to setup an Azure Function (consumption plan, Linux), a Key Vault, and one reference to it in the function's App Configuration, to reproduce the issue https://github.com/Azure/Azure-Functions/issues/2248.

# Deploy the infrastructure

```powershell
$subscription = "Training Subscription"
$rgName = "" # Name of the resource group where to deploy (ex: "frbar-repro-issue-2248")
$location = "West Europe"

az login
az account set --subscription $subscription
az group create --name $rgName --location $location
az deployment group create --resource-group $rgName --template-file infra.bicep --mode complete
```

# Tear down

```powershell
az group delete --name $rgName
```

# Cookbook

```powershell
# https://learn.microsoft.com/fr-fr/cli/azure/keyvault?view=azure-cli-latest#az-keyvault-purge
az keyvault purge --name xxx --location xxx
``` 