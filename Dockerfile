# escape=`
FROM mcr.microsoft.com/dotnet/framework/aspnet:latest

ARG temp_dir
ENV temp_dir ${temp_dir:-C:\temp}
ARG entrypoint_dir
ENV entrypoint_dir ${entrypoint_dir:-C:\entrypoint}
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

RUN mkdir $env:temp_dir; `
      mkdir $env:entrypoint_dir
# define the path we will symbolic link to represent D:
#RUN mkdir /data
VOLUME [ "C:\\data" ]
RUN Set-ItemProperty -Path 'HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\DOS Devices' -Name 'D:' -Value "\??\C:\data" -Type String;

COPY ./idp.zip ${temp_dir}

# required for ARR rules with SA Cloud
RUN Invoke-WebRequest http://download.microsoft.com/download/E/9/8/E9849D6A-020E-47E4-9FD0-A023E99B54EB/requestRouter_amd64.msi -UseBasicParsing -OutFile C:/requestrouter.msi; `
      Start-Process msiexec -ArgumentList '/i C:\requestrouter.msi /qn' -Wait; rm C:\requestrouter.msi; `
      Invoke-WebRequest http://download.microsoft.com/download/C/9/E/C9E8180D-4E51-40A6-A9BF-776990D8BCA9/rewrite_amd64.msi -UseBasicParsing -OutFile C:/rewrite.msi; `
      Start-Process msiexec -ArgumentList '/i C:\rewrite.msi /qn' -Wait; rm C:\rewrite.msi

# Start Script checks if IdP is installed, then runs W3SVC
COPY ./SecureAuth_Run.ps1 ${entrypoint_dir}
ENTRYPOINT powershell.exe -ExecutionPolicy ByPass -File $env:entrypoint_dir/SecureAuth_Run.ps1
EXPOSE 80 443