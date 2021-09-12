#create directory for installers
#New-Item -Path "c:\" -Name "installers" -ItemType "directory"

#install chocolatey
Set-ExecutionPolicy AllSigned
Set-ExecutionPolicy Bypass -Scope Process -Force; [System.Net.ServicePointManager]::SecurityProtocol = [System.Net.ServicePointManager]::SecurityProtocol -bor 3072; iex ((New-Object System.Net.WebClient).DownloadString('https://community.chocolatey.org/install.ps1'))

Start-Sleep -s 20

choco install adobereader
choco install 7zip.install
choco install vlc

#download installers
##1. 7-zip
#Invoke-WebRequest "https://www.7-zip.org/a/7z1900-x64.msi" -OutFile "c:\installers\7z1900-x64.msi"

##2. adobe reader dc
#Invoke-WebRequest "https://ardownload2.adobe.com/pub/adobe/reader/win/AcrobatDC/2100520060/AcroRdrDC2100520060_en_US.exe" -OutFile "c:\installers\AcroRdrDC2100520060_en_US.exe"

##3. PuTTY
#Invoke-WebRequest "https://the.earth.li/~sgtatham/putty/0.75/w64/putty-64bit-0.75-installer.msi" -OutFile "c:\installers\putty-64bit-0.75-installer.msi"

#install apps silently
#Start-Process "c:\installers\7z1900-x64.msi" -ArgumentList "/S" -Wait
#Start-Process "c:\installers\AcroRdrDC2100520060_en_US.exe" -ArgumentList "/sAll /rs /msi EULA_ACCEPT=YES" -Wait
#Start-Process "c:\installers\putty-64bit-0.75-installer.msi" -ArgumentList "/qn" -Wait



#Clean up install files
#rm -r "c:\installers" -Force

write-host 'Completed baseline applications install script'