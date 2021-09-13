# aibWindows10Ent
Leverages Azure Image Builder via Powershell and JSON scripting to deploy a Windows 10 image template for Azure



## credit: adapted from: https://github.com/azure/azvmimagebuilder/tree/main/solutions/14_Building_Images_WVD
# requirements: https://docs.microsoft.com/en-us/windows-365/device-images
#
# NOTE: Only needs to be done if this script has never been run in a given tenant before
# NOTE: Recommend using Azure Cloud Shell to run this tool
#
# Download script to Azure account
# Invoke-WebRequest -uri https://raw.githubusercontent.com/cbowlsby/aib/main/aibDeployWindows10Ent.ps1 -OutFile aibDeployWindows10Ent.ps1 -UseBasicParsing
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

