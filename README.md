# IdentityGuard Infrastructure
Infrastructure as Code definitions to support the IdentityGuard project.

## Requirements
* Terraform 1.0 or higher
* Terraform exe is in the PATH of your local machines
* Azure CLI 2.28 or higher

## Projects
|Folder|Type|Description|
|---|---|---|
|src/Azure|Terraform|Azure resources for IdentityGuard|
|src/Azure/config|Terraform|Configuration values for different environments|
|src/Azure/scripts|Powershell|Scripts to run for development use|

## Actions
|Action|Description|
|---|---|
|.github/workflows/ci-build.yml|Continuous Integration build for the the /src/Azure code|
|.github/workflows/deploy-prd.yml|Deploys the Terraform code to production when the CI build completes successfully on the main branch|

## Development Environment Setup
To configure your develpment environment, use the following steps:
1. Pull down the code from GitHub.
2. Change your working directory to src/Azure
3. Using Powershell run az login -t <tenant id>
```
az login - t 335776b5-3fba-4122-bcef-84458b1b8201
```
4. Initialize the project by running src/Azure/scripts/initialize.ps1

After changes are made, you can then plan and apply changes by running the src/Azure/scripts/plan.ps1 and src/Azure/scripts.apply.ps1 scripts.

