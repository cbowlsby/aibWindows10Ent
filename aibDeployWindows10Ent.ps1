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
$aibRoleImageCreationUrl="https://raw.githubusercontent.com/cbowlsby/aib/main/aibRoleImageCreation.json"
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
$templateUrl="https://raw.githubusercontent.com/cbowlsby/aib/main/armTemplatew365.json"
$templateFilePath = "armTemplatew365.json"
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

# Optional - if you have any errors running the above, run:
# $getStatus=$(Get-AzImageBuilderTemplate -ResourceGroupName $imageResourceGroup -Name $imageTemplateName)
# $getStatus.ProvisioningErrorCode 
# $getStatus.ProvisioningErrorMessage

# pause for 15 minutes while waiting for Azure to catch up
# without this, the next step errors out irregularly.  Permissions take a bit to populate in Azure
Start-Sleep -s 900

# Build the image
Start-AzImageBuilderTemplate -ResourceGroupName $imageResourceGroup -Name $imageTemplateName -NoWait