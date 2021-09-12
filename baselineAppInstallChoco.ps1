#install chocolatey
Set-ExecutionPolicy Bypass -Scope Process -Force; [System.Net.ServicePointManager]::SecurityProtocol = [System.Net.ServicePointManager]::SecurityProtocol -bor 3072; iex ((New-Object System.Net.WebClient).DownloadString('https://community.chocolatey.org/install.ps1'))

Start-Sleep -s 20

#configure chocolatey and install packages
choco feature enable -n allowGlobalConfirmation
choco install adobereader
choco install 7zip.install
choco install putty.install
choco install vscode
choco install googlechrome