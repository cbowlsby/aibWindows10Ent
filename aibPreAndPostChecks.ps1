# credit: adapted from: https://github.com/azure/azvmimagebuilder/tree/main/solutions/14_Building_Images_WVD
# requirements: https://docs.microsoft.com/en-us/windows-365/device-images
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

connect-azaccount -UseDeviceAuthentication
Invoke-WebRequest -uri https://raw.githubusercontent.com/cbowlsby/aib/main/aibDeployWindows10Ent.ps1 -OutFile aibDeployWindows10Ent.ps1 -UseBasicParsing

# Register for Azure Image Builder Feature
Register-AzProviderFeature -FeatureName VirtualMachineTemplatePreview -ProviderNamespace Microsoft.VirtualMachineImages

Get-AzProviderFeature -FeatureName VirtualMachineTemplatePreview -ProviderNamespace Microsoft.VirtualMachineImages
# wait until RegistrationState is set to 'Registered'

# check you are registered for the providers, ensure RegistrationState is set to 'Registered'.
Get-AzResourceProvider -ProviderNamespace Microsoft.VirtualMachineImages
Get-AzResourceProvider -ProviderNamespace Microsoft.Storage 
Get-AzResourceProvider -ProviderNamespace Microsoft.Compute
Get-AzResourceProvider -ProviderNamespace Microsoft.KeyVault

# If they do not show as registered, run the commented out code below.

## Register-AzResourceProvider -ProviderNamespace Microsoft.VirtualMachineImages
## Register-AzResourceProvider -ProviderNamespace Microsoft.Storage
## Register-AzResourceProvider -ProviderNamespace Microsoft.Compute
## Register-AzResourceProvider -ProviderNamespace Microsoft.KeyVault



## Add AZ PS modules to support AzUserAssignedIdentity and Az AIB
'Az.ImageBuilder', 'Az.ManagedServiceIdentity' | ForEach-Object {Install-Module -Name $_ -AllowPrerelease}




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
# Remove-AzRoleAssignment -ObjectId $identityNamePrincipalId -RoleDefinitionName $imageRoleDefName -Scope "/subscriptions/$subscriptionID/resourceGroups/$imageResourceGroup"

## remove definitions
# Remove-AzRoleDefinition -Name "$identityNamePrincipalId" -Force -Scope "/subscriptions/$subscriptionID/resourceGroups/$imageResourceGroup"

## delete identity
# Remove-AzUserAssignedIdentity -ResourceGroupName $imageResourceGroup -Name $identityName -Force

## Delete Resource Group
# Remove-AzResourceGroup $imageResourceGroup -Force