# Purpose

This repository contains a Bicep template to setup:
- an Azure Function (consumption plan, Linux), 
- a Key Vault,
- an Application Setting using a Key Vault reference.

A simple JavaScript function is also provided, which will output environment variables.

This is to reproduce the issue tracked here: https://github.com/Azure/Azure-Functions/issues/2248.

# Deploy the infrastructure

```powershell
az login

$subscription = "My Subscription"
az account set --subscription $subscription

$location     = "West Europe"
$kind         = "linux"              # or windows
$rgName       = "frbar-2248-$kind"   # Name of the resource group where to deploy

az group create --name $rgName --location $location
az deployment group create --resource-group $rgName --template-file infra.bicep --mode complete --parameters kind=$kind

$functionName = az deployment group show -g $rgName -n infra --query properties.outputs.functionName.value -otsv

start-sleep 60
cd src
func azure functionapp publish $functionName

(curl https://$($functionName).azurewebsites.net/api/httpexample -UseBasicParsing).Content

```

# Tear down

```powershell
az group delete --name $rgName
```
