# credit: adapted from: https://github.com/azure/azvmimagebuilder/tree/main/solutions/14_Building_Images_WVD
#
# must run elevated if installing apps.  Example code:
#   {
#    "type": "PowerShell",
#    "name": "installFsLogix",
#    "runElevated": true,
#    "runAsSystem": true,
#    "scriptUri": "https://raw.githubusercontent.com/danielsollondon/azvmimagebuilder/master/solutions/14_Building_Images_WVD/0_installConfFsLogix.ps1"
#
#############################################################################################################################################


# Register for Azure Image Builder Feature
Register-AzProviderFeature -FeatureName VirtualMachineTemplatePreview -ProviderNamespace Microsoft.VirtualMachineImages

Get-AzProviderFeature -FeatureName VirtualMachineTemplatePreview -ProviderNamespace Microsoft.VirtualMachineImages
# wait until RegistrationState is set to 'Registered'

# check you are registered for the providers, ensure RegistrationState is set to 'Registered'.
Get-AzResourceProvider -ProviderNamespace Microsoft.VirtualMachineImages
Get-AzResourceProvider -ProviderNamespace Microsoft.Storage 
Get-AzResourceProvider -ProviderNamespace Microsoft.Compute
Get-AzResourceProvider -ProviderNamespace Microsoft.KeyVault

# If they do not show as registered, runhe commented out code below.

## Register-AzResourceProvider -ProviderNamespace Microsoft.VirtualMachineImages
## Register-AzResourceProvider -ProviderNamespace Microsoft.Storage
## Register-AzResourceProvider -ProviderNamespace Microsoft.Compute
## Register-AzResourceProvider -ProviderNamespace Microsoft.KeyVault


# Step 1: Set up environment and variables

# Step 1: Import module
Import-Module Az.Accounts

# Step 2: get existing context
$currentAzContext = Get-AzContext

# destination image resource group
$imageResourceGroup="W365ImageDemo"

# location (see possible locations in main docs)
$location="westus2"

# your subscription, this will get your current subscription
$subscriptionID=$currentAzContext.Subscription.Id

# image template name
$imageTemplateName="10entM365Template"

# distribution properties object name (runOutput), i.e. this gives you the properties of the managed image on completion
$runOutputName="sigOutput"

# create resource group
New-AzResourceGroup -Name $imageResourceGroup -Location $location


## Step 2 : Permissions, create user idenity and role for AIB

# Create user identity
# setup role def names, these need to be unique
$timeInt=$(get-date -UFormat "%s")
$imageRoleDefName="Azure Image Builder Image Def"+$timeInt
$identityName="aibIdentity"+$timeInt

## Add AZ PS modules to support AzUserAssignedIdentity and Az AIB
'Az.ImageBuilder', 'Az.ManagedServiceIdentity' | ForEach-Object {Install-Module -Name $_ -AllowPrerelease}

# create identity
New-AzUserAssignedIdentity -ResourceGroupName $imageResourceGroup -Name $idenityName

$idenityNameResourceId=$(Get-AzUserAssignedIdentity -ResourceGroupName $imageResourceGroup -Name $identityName).Id
$idenityNamePrincipalId=$(Get-AzUserAssignedIdentity -ResourceGroupName $imageResourceGroup -Name $identityName).PrincipalId

# Assign permissions for identity to distribute images

$aibRoleImageCreationUrl="https://raw.githubusercontent.com/cbowlsby/aib/main/aibRoleImageCreation.json"
$aibRoleImageCreationPath = "aibRoleImageCreation.json"

# download config
Invoke-WebRequest -Uri $aibRoleImageCreationUrl -OutFile $aibRoleImageCreationPath -UseBasicParsing

((Get-Content -path $aibRoleImageCreationPath -Raw) -replace '<subscriptionID>',$subscriptionID) | Set-Content -Path $aibRoleImageCreationPath
((Get-Content -path $aibRoleImageCreationPath -Raw) -replace '<rgName>', $imageResourceGroup) | Set-Content -Path $aibRoleImageCreationPath
((Get-Content -path $aibRoleImageCreationPath -Raw) -replace 'Azure Image Builder Service Image Creation Role', $imageRoleDefName) | Set-Content -Path $aibRoleImageCreationPath

# create role definition
New-AzRoleDefinition -InputFile  ./aibRoleImageCreation.json

# grant role definition to image builder service principal
New-AzRoleAssignment -ObjectId $idenityNamePrincipalId -RoleDefinitionName $imageRoleDefName -Scope "/subscriptions/$subscriptionID/resourceGroups/$imageResourceGroup"

# Step 3 : Create the Shared Image Gallery
$sigGalleryName= "w365SharedImageGallery"
$imageDefName ="10EntM365Apps"

# create gallery
New-AzGallery -GalleryName $sigGalleryName -ResourceGroupName $imageResourceGroup  -Location $location

# create gallery definition
New-AzGalleryImageDefinition -GalleryName $sigGalleryName -ResourceGroupName $imageResourceGroup -Location $location -Name $imageDefName -OsState generalized -OsType Windows -Publisher 'ChristopherB' -Offer 'Windows' -Sku '10EntM365Apps'


# Configure the Image Template

# Download template and configure
$templateUrl="https://raw.githubusercontent.com/cbowlsby/aib/main/armTemplatew365.003.json"
$templateFilePath = "armTemplatew365.003.json"

Invoke-WebRequest -Uri $templateUrl -OutFile $templateFilePath -UseBasicParsing

((Get-Content -path $templateFilePath -Raw) -replace '<subscriptionID>',$subscriptionID) | Set-Content -Path $templateFilePath
((Get-Content -path $templateFilePath -Raw) -replace '<rgName>',$imageResourceGroup) | Set-Content -Path $templateFilePath
((Get-Content -path $templateFilePath -Raw) -replace '<region>',$location) | Set-Content -Path $templateFilePath
((Get-Content -path $templateFilePath -Raw) -replace '<runOutputName>',$runOutputName) | Set-Content -Path $templateFilePath

((Get-Content -path $templateFilePath -Raw) -replace '<imageDefName>',$imageDefName) | Set-Content -Path $templateFilePath
((Get-Content -path $templateFilePath -Raw) -replace '<sharedImageGalName>',$sigGalleryName) | Set-Content -Path $templateFilePath
((Get-Content -path $templateFilePath -Raw) -replace '<region1>',$location) | Set-Content -Path $templateFilePath
((Get-Content -path $templateFilePath -Raw) -replace '<imgBuilderId>',$idenityNameResourceId) | Set-Content -Path $templateFilePath

# Submit the template
New-AzResourceGroupDeployment -ResourceGroupName $imageResourceGroup -TemplateFile $templateFilePath -api-version "2020-02-14" -imageTemplateName $imageTemplateName -svclocation $location

# Optional - if you have any errors running the above, run:
# $getStatus=$(Get-AzImageBuilderTemplate -ResourceGroupName $imageResourceGroup -Name $imageTemplateName)
# $getStatus.ProvisioningErrorCode 
# $getStatus.ProvisioningErrorMessage



# Build the image
Start-AzImageBuilderTemplate -ResourceGroupName $imageResourceGroup -Name $imageTemplateName -NoWait

# status can be queryed as below
# $getStatus=$(Get-AzImageBuilderTemplate -ResourceGroupName $imageResourceGroup -Name $imageTemplateName)

# this shows all the properties
# $getStatus | Format-List -Property *

# these show status of the build
# $getStatus.LastRunStatusRunState 
# $getStatus.LastRunStatusMessage


# once template is built, we need to delete all template creation resources in the following order
## Remove Image Template
# Remove-AzImageBuilderTemplate -ResourceGroupName $imageResourceGroup -Name 10entM365Template

## Delete role assignment
# Remove-AzRoleAssignment -ObjectId $idenityNamePrincipalId -RoleDefinitionName $imageRoleDefName -Scope "/subscriptions/$subscriptionID/resourceGroups/$imageResourceGroup"

## remove definitions
# Remove-AzRoleDefinition -Name "$idenityNamePrincipalId" -Force -Scope "/subscriptions/$subscriptionID/resourceGroups/$imageResourceGroup"

## delete identity
# Remove-AzUserAssignedIdentity -ResourceGroupName $imageResourceGroup -Name $idenityName -Force

## Delete Resource Group
# Remove-AzResourceGroup $imageResourceGroup -Force
