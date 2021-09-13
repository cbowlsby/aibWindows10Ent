## credit: adapted from: https://github.com/azure/azvmimagebuilder/tree/main/solutions/14_Building_Images_WVD
# meets Windows 365 custom image requirements: https://docs.microsoft.com/en-us/windows-365/device-images
#
# NOTE: The following prep work prior to running the body of the script only needs to be done if this script has never been run in a given tenant before
# NOTE: Recommend using Azure Cloud Shell to run this tool
#
# Download script to Azure account
# Invoke-WebRequest -uri https://raw.githubusercontent.com/cbowlsby/aibWindows10Ent/main/aibDeployWindows10Ent.ps1 -OutFile aibDeployWindows10Ent.ps1 -UseBasicParsing
#
## Prep Work
#
# Register Azure Image Builder Feature in your tenant
# Register-AzProviderFeature -FeatureName VirtualMachineTemplatePreview -ProviderNamespace Microsoft.VirtualMachineImages
# (do not continue until RegistrationState is set to 'Registered') -> Get-AzProviderFeature -FeatureName VirtualMachineTemplatePreview -ProviderNamespace Microsoft.VirtualMachineImages
#
# Check that you are registered for the appropriate providers, ensure RegistrationState is set to 'Registered'.
# Get-AzResourceProvider -ProviderNamespace Microsoft.VirtualMachineImages
# Get-AzResourceProvider -ProviderNamespace Microsoft.Storage 
# Get-AzResourceProvider -ProviderNamespace Microsoft.Compute
# Get-AzResourceProvider -ProviderNamespace Microsoft.KeyVault
#
# If the above providers do not show as registered, run the code below, otherwise, skip to the next section
# Register-AzResourceProvider -ProviderNamespace Microsoft.VirtualMachineImages
# Register-AzResourceProvider -ProviderNamespace Microsoft.Storage
# Register-AzResourceProvider -ProviderNamespace Microsoft.Compute
# Register-AzResourceProvider -ProviderNamespace Microsoft.KeyVault
#
# Final step: Add AZ PS modules to support AzUserAssignedIdentity and Az AIB
# 'Az.ImageBuilder', 'Az.ManagedServiceIdentity' | ForEach-Object {Install-Module -Name $_ -AllowPrerelease}
#
#############################################################################################################################################





## Phase 1: Set up environment and variables
# Import module
Import-Module Az.Accounts

# variables for existing context, destination image resource group, azure region, your subscription, image template name, 
# and distribution properties object name (properties of the managed image on completion)
$currentAzContext = Get-AzContext
$imageResourceGroup="AutomatedImagePipeline"
$location="westus2"
$subscriptionID=$currentAzContext.Subscription.Id
$imageTemplateName="10EntM365-Template"
$runOutputName="sigOutput"

# create resource group
New-AzResourceGroup -Name $imageResourceGroup -Location $location









## Phase 2 : Permissions, create user identity and role for AIB
# Create user identity, these values must be unique
$timeInt=$(get-date -UFormat "%s")
$imageRoleDefName="Azure Image Builder Image Def "+$timeInt
$identityName="aibIdentity"+$timeInt
New-AzUserAssignedIdentity -ResourceGroupName $imageResourceGroup -Name $identityName

$identityNameResourceId=$(Get-AzUserAssignedIdentity -ResourceGroupName $imageResourceGroup -Name $identityName).Id
$identityNamePrincipalId=$(Get-AzUserAssignedIdentity -ResourceGroupName $imageResourceGroup -Name $identityName).PrincipalId

# Assign permissions for identity to distribute images, then download config and configure
$aibRoleImageCreationUrl="https://raw.githubusercontent.com/cbowlsby/aibWindows10Ent/main/aibRoleImageCreation.json"
$aibRoleImageCreationPath = "aibRoleImageCreation.json"
Invoke-WebRequest -Uri $aibRoleImageCreationUrl -OutFile $aibRoleImageCreationPath -UseBasicParsing
((Get-Content -path $aibRoleImageCreationPath -Raw) -replace '<subscriptionID>',$subscriptionID) | Set-Content -Path $aibRoleImageCreationPath
((Get-Content -path $aibRoleImageCreationPath -Raw) -replace '<rgName>', $imageResourceGroup) | Set-Content -Path $aibRoleImageCreationPath
((Get-Content -path $aibRoleImageCreationPath -Raw) -replace 'Azure Image Builder Service Image Creation Role', $imageRoleDefName) | Set-Content -Path $aibRoleImageCreationPath

# create role definition
New-AzRoleDefinition -InputFile  ./aibRoleImageCreation.json

# pause for 1 minute while waiting for Azure to catch up
# without this, the next step errors out.  It takes a few seconds for Azure to provision the PrincipalID mentioned earlier and required in the next step
Start-Sleep -s 60

# grant role definition to image builder service principal
New-AzRoleAssignment -ObjectId $identityNamePrincipalId -RoleDefinitionName $imageRoleDefName -Scope "/subscriptions/$subscriptionID/resourceGroups/$imageResourceGroup"








## Phase 3 : Create the Shared Image Gallery
$sigGalleryName= "w365SharedImageGallery"
$imageDefName ="10EntM365"

# create gallery and gallery definition
New-AzGallery -GalleryName $sigGalleryName -ResourceGroupName $imageResourceGroup  -Location $location
New-AzGalleryImageDefinition -GalleryName $sigGalleryName -ResourceGroupName $imageResourceGroup -Location $location -Name $imageDefName -OsState generalized -OsType Windows -Publisher 'ChristopherBowlsby' -Offer 'Windows' -Sku '10EntM365'

# Download image template and configure
$templateUrl="https://github.com/cbowlsby/aibWindows10Ent/blob/main/armTemplateWindows10Ent.json"
$templateFilePath = "armTemplateWindows10Ent.json"
Invoke-WebRequest -Uri $templateUrl -OutFile $templateFilePath -UseBasicParsing
((Get-Content -path $templateFilePath -Raw) -replace '<subscriptionID>',$subscriptionID) | Set-Content -Path $templateFilePath
((Get-Content -path $templateFilePath -Raw) -replace '<rgName>',$imageResourceGroup) | Set-Content -Path $templateFilePath
((Get-Content -path $templateFilePath -Raw) -replace '<region>',$location) | Set-Content -Path $templateFilePath
((Get-Content -path $templateFilePath -Raw) -replace '<runOutputName>',$runOutputName) | Set-Content -Path $templateFilePath
((Get-Content -path $templateFilePath -Raw) -replace '<imageDefName>',$imageDefName) | Set-Content -Path $templateFilePath
((Get-Content -path $templateFilePath -Raw) -replace '<sharedImageGalName>',$sigGalleryName) | Set-Content -Path $templateFilePath
((Get-Content -path $templateFilePath -Raw) -replace '<region1>',$location) | Set-Content -Path $templateFilePath
((Get-Content -path $templateFilePath -Raw) -replace '<imgBuilderId>',$identityNameResourceId) | Set-Content -Path $templateFilePath

# Submit the template
New-AzResourceGroupDeployment -ResourceGroupName $imageResourceGroup -TemplateFile $templateFilePath -api-version "2020-02-14" -imageTemplateName $imageTemplateName -svclocation $location

# pause for 15 minutes while waiting for Azure to catch up
# without this, the next step errors out irregularly.  Permissions take a bit to populate in Azure
Start-Sleep -s 900

# Build the image
Start-AzImageBuilderTemplate -ResourceGroupName $imageResourceGroup -Name $imageTemplateName -NoWait





# Optional, only needed if you have any errors running the above:
# $getStatus=$(Get-AzImageBuilderTemplate -ResourceGroupName $imageResourceGroup -Name $imageTemplateName)
# $getStatus.ProvisioningErrorCode 
# $getStatus.ProvisioningErrorMessage
#
# This shows all properties if desired
# $getStatus | Format-List -Property *

# Once the template is built, if you do not intend to use this again delete all resources used to build the template.