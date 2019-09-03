# escape=`
FROM mcr.microsoft.com/dotnet/framework/aspnet:latest

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

SHELL ["powershell", "-Command", "$ErrorActionPreference = 'Stop'; $ProgressPreference = 'SilentlyContinue';"]

RUN mkdir $env:temp_dir
# define the path we will symbolic link to represent D:
RUN mkdir /data
RUN Set-ItemProperty -Path 'HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\DOS Devices' -Name 'D:' -Value "\??\C:\data" -Type String;

COPY ["idp.zip", "/temp"]
# copy remote build files and clean up
RUN Expand-Archive -LiteralPath $env:temp_dir\idp.zip -DestinationPath $env:temp_dir; `
      Move-Item -Path $env:temp_dir\DRIVE_C\Scripts -Destination C:\Scripts; `
      Move-Item -Path $env:temp_dir\DRIVE_D\* -Destination C:\data; `
      Move-Item -Path $env:temp_dir\SecureAuth-Idp-Setup-Utility-$env:sisu_version-Installer.exe -Destination C:\data\MFCApp_BIN\SISU\SISUInstaller.exe; `
      Get-ChildItem $env:temp_dir -Recurse | ForEach ($_) {Remove-Item $_.fullname -Recurse}

# replace strings in build files
RUN (get-content $env:base_install_path).replace('Set /P BuildType=Is this a Production Appliance Image build (i.e. Sysprep should be run) [Y or N]?', 'Set BuildType=Y')|Set-Content $env:base_install_path; `
      (get-content $env:base_install_path).replace('PAUSE &:: ANSIBLE_REPLACE_PAUSE', ':: PAUSE')|Set-Content $env:base_install_path; `
      (get-content $env:first_install_path).replace('::ANSIBLE_COND1', 'call :Cond_1')|set-content $env:first_install_path; `
      (get-content $env:first_install_path).replace('Powershell &:: ANSIBLE_REMOVE', ':: Powershell')|Set-Content $env:first_install_path; `
      (get-content C:\Scripts\Setup\Security\$env:lanmanbypass).replace('NET STOP LanmanServer', 'NET STOP LanmanServer /y')|set-content C:\Scripts\Setup\Security\$env:lanmanbypass

# run hardening scripts then clean up
RUN & "$env:first_install_path"; `
      Get-ChildItem C:\Scripts -Recurse | ForEach ($_) {Remove-Item $_.fullname -Recurse}; `
      Get-ChildItem C:\data\Scripts -Recurse | ForEach ($_) {Remove-Item $_.fullname -Recurse}; `
      Remove-Item C:\Scripts -Recurse -Force; `
      Remove-Item C:\data\Scripts -Recurse -Force; `
      Remove-Item C:\data\MFCApp_Bin\FirstStartup*.cmd; `
      Remove-Item C:\data\MFCApp_Bin\*.vbs; `
      Remove-Item C:\data\MFCApp_Bin\*.reg; `
      Get-ChildItem C:\data\MFCApp_Bin\Startmenu -Recurse | ForEach ($_) {Remove-Item $_.fullname -Recurse}; `
      Remove-Item C:\data\MFCApp_Bin\Startmenu -Recurse -Force

# required for ARR rules with SA Cloud
RUN Invoke-WebRequest http://download.microsoft.com/download/E/9/8/E9849D6A-020E-47E4-9FD0-A023E99B54EB/requestRouter_amd64.msi -UseBasicParsing -OutFile C:/requestrouter.msi; `
      Start-Process msiexec -ArgumentList '/i C:\requestrouter.msi /qn' -Wait; rm C:\requestrouter.msi; `
      Invoke-WebRequest http://download.microsoft.com/download/C/9/E/C9E8180D-4E51-40A6-A9BF-776990D8BCA9/rewrite_amd64.msi -UseBasicParsing -OutFile C:/rewrite.msi; `
      Start-Process msiexec -ArgumentList '/i C:\rewrite.msi /qn' -Wait; rm C:\rewrite.msi

# run SISU installer, then run SA final install
RUN & "C:\data\MFCApp_Bin\SISU\SISUInstaller.exe"

# Start Script checks if IdP is installed, then runs W3SVC
COPY ["SecureAuth_Run.ps1", "/temp"]
ENTRYPOINT ["powershell", "-ExecutionPolicy", "ByPass", "-File", "./temp/SecureAuth_Run.ps1"]
EXPOSE 80 443