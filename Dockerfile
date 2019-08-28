# escape=`
#FROM mcr.microsoft.com/windows/servercore/iis:windowsservercore-ltsc2016
FROM mcr.microsoft.com/dotnet/framework/aspnet:latest

SHELL ["powershell", "-Command", "$ErrorActionPreference = 'Stop'; $ProgressPreference = 'SilentlyContinue';"]

## define the path we will symbolic link to represent D:
RUN mkdir /data
RUN Set-ItemProperty -Path 'HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\DOS Devices' -Name 'D:' -Value "\??\C:\data" -Type String;

ARG temp_dir
ENV temp_dir ${temp_dir:-/temp}
ARG sisu_version
ENV sisu_version ${sisu_version:-2.1.24.0}
ARG sisu
ENV sisu ${sisu:-SISUInstaller.exe}
ARG lanmanbypass
ENV lanmanbypass ${lanmanbypass:-SA_Common_MemberServer_Install.cmd}
ARG first_install
ENV first_install ${first_install:-FirstInstall.bat}
ARG first_install_path
ENV first_install_path ${first_install_path:-C:\Scripts\${first_install}}
ARG secureauth_build
ENV secureauth_build ${secureauth_build:-SecureAuth_Base_Build.bat}
ARG base_install_path
ENV base_install_path ${base_install_path:-C:\Scripts\Setup\${secureauth_build}}
ARG sa_version
ENV sa_version ${sa_version:-19.07}
ARG sa_key
ENV sa_key ${sa_key}

RUN mkdir $env:temp_dir

# Install Chocolatey
RUN  "$env:ChocolateyUseWindowsCompression='false'; iex ((New-Object System.Net.WebClient).DownloadString('https://chocolatey.org/install.ps1'))"
#      choco install dotnet4.7 --allow-empty-checksums -y --ignorepackageexitcodes

COPY ["idp/DRIVE_C", "/"]
COPY ["idp/DRIVE_D", "/data"]
COPY ["SecureAuth-Idp-Setup-Utility-${sisu_version}-Installer.exe", "/data/MFCApp_BIN/SISU/SISUInstaller.exe"]

RUN (get-content $env:base_install_path).replace('Set /P BuildType=Is this a Production Appliance Image build (i.e. Sysprep should be run) [Y or N]?', 'Set BuildType=Y')|Set-Content $env:base_install_path; `
      (get-content $env:base_install_path).replace('PAUSE &:: ANSIBLE_REPLACE_PAUSE', ':: PAUSE')|Set-Content $env:base_install_path; `
      (get-content $env:first_install_path).replace('::ANSIBLE_COND1', 'call :Cond_1')|set-content $env:first_install_path; `
      (get-content $env:first_install_path).replace('Powershell &:: ANSIBLE_REMOVE', ':: Powershell')|Set-Content $env:first_install_path; `
      (get-content C:\Scripts\Setup\Security\$env:lanmanbypass).replace('NET STOP LanmanServer', 'NET STOP LanmanServer /y')|set-content C:\Scripts\Setup\Security\$env:lanmanbypass

RUN & "$env:first_install_path"
RUN & "C:\data\MFCApp_Bin\SISU\SISUInstaller.exe"; `
      & "'C:\Program Files (x86)\SecureAuth Corporation\SecureAuth IdP Setup Utility\SecureAuthIdPSetupUtility.exe' /version $env:sa_version /key $env:sa_key"

EXPOSE 80
EXPOSE 443