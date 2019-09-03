# start application/host initialization logic

# check if debug.log exists, if not install IdP
if(!(Test-Path 'C:\Debug.log' -PathType Leaf))  {
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
