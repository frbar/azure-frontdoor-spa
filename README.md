# Purpose

This repository contains a Bicep template to setup:
- App Service Linux,
- Static Web App,
- Azure Front Door in front of both.

There is also a very basic API backend and a 10 lines SPA.

Bicep template is to be run from your local. Deployment of the SPA is to be done using a GitHub Actions workflow.

# Deploy the infrastructure

```powershell
$subscription = "Training Subscription"
$rgName = "frbar-fd-spa-api"
$envName = "frbarfdspapoc"
$location = "France Central"

az login
az account set --subscription $subscription
az group create --name $rgName --location $location
az deployment group create --resource-group $rgName --template-file infra.bicep --mode complete --parameters envName=$envName
```

# Build and Deploy the API backend

```powershell
dotnet publish .\api\ -r linux-x64 --self-contained -o publish
Compress-Archive publish\* publish.zip
az webapp deployment source config-zip --src .\publish.zip -n "$($envName)-api" -g $rgName

Remove-Item publish -Recurse
Remove-Item publish.zip
```

# Get the Azure Front Door ID

```powershell
az afd endpoint list -g $rgName --profile-name "$($envName)-afd" --query [0].hostName
```


# Deploy the Azure Static Web App

*You will have to fork the GitHub repository.*

In GitHub, trigger workflow `Deploy Azure Static Web App` and fill in the ID of the Azure Front Door instance, retrieved previously. This is used to set network restriction at deployment time, to only allow traffic from the Azure Front Door instance.

I stopped there but fetching this ID could be fully automated, using Azure CLI and a service connection.

# Tear down

```powershell
az group delete --name $rgName
```

# Cookbook

```powershell
az afd profile list -g $rgName --query [0].frontDoorId 

az afd endpoint list -g $rgName --profile-name "$($envName)-afd" --query [0].hostName
``` 
