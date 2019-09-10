# start application/host initialization logic

# check if debug.log exists, if not install IdP
if(!(Test-Path 'C:\Debug.log' -PathType Leaf))  {

    if(!(Test-Path 'C:\data\Secureauth\SecureAuth0\web.config' -PathType Leaf)) {
        # set permissions so that cleanup will work
        Get-ChildItem 'C:\data' -Recurse | ForEach-Object ($_) {
            $acl = Get-Acl -Path $_.fullname
            if(($_).GetType().Name -eq 'DirectoryInfo') {
                $accessrule = New-Object System.Security.AccessControl.FileSystemAccessRule ('Everyone', 'FullControl', 'ContainerInherit, ObjectInherit', 'None', 'Allow')
                $acl.SetAccessRule($accessrule)
                Set-Acl -Path $_.fullname -AclObject $acl
            }
            # permissions set are slightly different for files than directories
            if(($_).GetType().Name -eq 'FileInfo') {
                $accessrule = New-Object System.Security.AccessControl.FileSystemAccessRule ('Everyone', 'FullControl', 'ContainerInherit, ObjectInherit', 'InheritOnly', 'Allow')
                $acl.SetAccessRule($accessrule)
                Set-Acl -Path $_.fullname -AclObject $acl
            }
        }

        # copy remote build files and clean up
        Expand-Archive -LiteralPath $env:temp_dir\idp.zip -DestinationPath $env:temp_dir
        Copy-Item -Path $env:temp_dir\DRIVE_C\Scripts -Destination C:\Scripts -Recurse -Force
        Copy-Item -Path $env:temp_dir\DRIVE_D\* -Destination C:\data -Recurse -Force
        Copy-Item -Path $env:temp_dir\SecureAuth-Idp-Setup-Utility-$env:sisu_version-Installer.exe -Destination C:\data\MFCApp_BIN\SISU
        Rename-Item -Path C:\data\MFCApp_BIN\SISU\SecureAuth-Idp-Setup-Utility-$env:sisu_version-Installer.exe -NewName 'SISUInstaller.exe'
        Get-ChildItem $env:temp_dir -Recurse | ForEach-Object ($_) {Remove-Item $_.fullname -Recurse}

        # replace strings in build files
        (get-content $env:base_install_path).replace('Set /P BuildType=Is this a Production Appliance Image build (i.e. Sysprep should be run) [Y or N]?', 'Set BuildType=Y')|Set-Content $env:base_install_path
        (get-content $env:base_install_path).replace('PAUSE &:: ANSIBLE_REPLACE_PAUSE', ':: PAUSE')|Set-Content $env:base_install_path
        (get-content $env:first_install_path).replace('::ANSIBLE_COND1', 'call :Cond_1')|set-content $env:first_install_path
        (get-content $env:first_install_path).replace('Powershell &:: ANSIBLE_REMOVE', ':: Powershell')|Set-Content $env:first_install_path
        (get-content C:\Scripts\Setup\Security\$env:lanmanbypass).replace('NET STOP LanmanServer', 'NET STOP LanmanServer /y')|set-content C:\Scripts\Setup\Security\$env:lanmanbypass
    
        # run hardening scripts then clean up
        & "$env:first_install_path" | Out-Default
        
        # set permissions so that cleanup will work
        Get-ChildItem 'C:\data' -Recurse | ForEach-Object ($_) {
            $acl = Get-Acl -Path $_.fullname
            if(($_).GetType().Name -eq 'DirectoryInfo') {
                $accessrule = New-Object System.Security.AccessControl.FileSystemAccessRule ('Everyone', 'FullControl', 'ContainerInherit, ObjectInherit', 'None', 'Allow')
                $acl.SetAccessRule($accessrule)
                Set-Acl -Path $_.fullname -AclObject $acl
            }
            # permissions set are slightly different for files than directories
            if(($_).GetType().Name -eq 'FileInfo') {
                $accessrule = New-Object System.Security.AccessControl.FileSystemAccessRule ('Everyone', 'FullControl', 'ContainerInherit, ObjectInherit', 'InheritOnly', 'Allow')
                $acl.SetAccessRule($accessrule)
                Set-Acl -Path $_.fullname -AclObject $acl
            }
        }

        #clean up
        Get-ChildItem C:\Scripts -Recurse | ForEach-Object ($_) {Remove-Item $_.fullname -Recurse}
        Get-ChildItem C:\data\Scripts -Recurse | ForEach-Object ($_) {Remove-Item $_.fullname -Recurse}
        Remove-Item C:\Scripts -Recurse -Force
        Remove-Item C:\data\Scripts -Recurse -Force
        Remove-Item C:\data\MFCApp_Bin\FirstStartup*.cmd
        Remove-Item C:\data\MFCApp_Bin\*.vbs
        Remove-Item C:\data\MFCApp_Bin\*.reg
        Get-ChildItem C:\data\MFCApp_Bin\Startmenu -Recurse | ForEach-Object ($_) {Remove-Item $_.fullname -Recurse}
        Remove-Item C:\data\MFCApp_Bin\Startmenu -Recurse -Force

        # run SISU installer, then run SA final install
        & 'C:\data\MFCApp_Bin\SISU\SISUInstaller.exe' | Out-Default
    }
    # output to both log file and console for docker logs container_name
    # Tee-Object ensures that install completes before we run W3SVC
    # Setup failed to restart IIS. message at end of installation is OK. W3SVC starts after install completes.
    & 'C:\Program Files (x86)\SecureAuth Corporation\SecureAuth IdP Setup Utility\SecureAuthIdPSetupUtility.exe' @('/version', $env:sa_version, '/key', $env:sa_key) | Tee-Object -File C:\info.log | Out-Default
    
    # read result of install
    $install_result = Get-Content -Path C:\info.log | Where-Object { $_ -match '^Setup' }
    if($install_result -notmatch 'failed to install') {
        # modify web.config in Realm0 to allow access as we can't RDP
        $realm0_config = "C:\data\SecureAuth\SecureAuth0\web.config"
        $doc = (Get-Content $realm0_config) -as [Xml]
        $root = $doc.get_DocumentElement();
        $root | ForEach-Object { $_.location } | Where-Object { $_.path -match 'LocalAdmin.aspx'} | ForEach-Object { [void]$_.ParentNode.RemoveChild($_) }
        $doc.Save($realm0_config)
    }

    # condition statement to clean up Debug.log if failed, so that a restart of the container can run setup again
    if($install_result -match 'failed to install') {
        Remove-Item -Path C:\Debug.log
        Remove-Item -Path C:\sa.config
    }

    # clean up
    Remove-Item -Path C:\info.log
}

# end application/host initialization logic

# do not remove this block, this is the entrypoint that starts iis on the container
Write-Output "Starting ServiceMonitor.exe"
C:\\ServiceMonitor.exe w3svc
# do not remove this block, this is the entrypoint that starts iis on the container
