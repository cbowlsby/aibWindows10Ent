#create directory for installers
New-Item -Path "c:\" -Name "installers" -ItemType "directory"


#download installers
##1. 7-zip
Invoke-WebRequest "https://www.7-zip.org/a/7z1900-x64.msi" -OutFile "c:\installers\7z1900-x64.msi"

##2. adobe reader dc
Invoke-WebRequest "https://ardownload2.adobe.com/pub/adobe/reader/win/AcrobatDC/2100520060/AcroRdrDC2100520060_en_US.exe" -OutFile "c:\installers\AcroRdrDC2100520060_en_US.exe"


#install apps silently
Start-Process "c:\installers\7z1900-x64.msi" -ArgumentList "/S" -Wait
Start-Process "c:\installers\AcroRdrDC2100520060_en_US.exe" -ArgumentList "/sAll /rs /msi EULA_ACCEPT=YES" -Wait

#Clean up install files
#rm -r "c:\installers" -Force