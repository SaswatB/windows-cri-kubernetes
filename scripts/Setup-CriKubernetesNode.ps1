
[CmdletBinding(PositionalBinding=$false)]
Param
(
    [parameter(ParameterSetName='Default', Mandatory = $true, HelpMessage='Kubernetes Config File')] [string]$ConfigFile,
    [parameter(ParameterSetName='Default', Mandatory = $false, HelpMessage='Kubernetes cluster cidr')] [string]$ClusterCIDR,
    [parameter(ParameterSetName='Default', Mandatory = $false, HelpMessage='Kubernetes pod service cidr')] [string]$ServiceCIDR,
    [parameter(ParameterSetName='Default', Mandatory = $false, HelpMessage='Kubernetes DNS Ip')] [string]$KubeDnsServiceIP,
    [parameter(ParameterSetName='Default', Mandatory = $false, HelpMessage='Skip downloading binaries')] [switch] $SkipInstall,

    [parameter(ParameterSetName='OnlyInstall', Mandatory = $false)] [switch] $OnlyInstall
)
$ProgressPreference = 'SilentlyContinue'

$kubernetesPath = "C:\k"
$cniDir = Join-Path $kubernetesPath cni
$containerdPath = "$Env:ProgramFiles\containerd"
$flanneldPath = "C:\flannel"
$flanneldConfPath = "C:\etc\kube-flannel"
$lcowPath = "$Env:ProgramFiles\Linux Containers"

# create all the necessary directories if they don't already exist
New-Item -ItemType Directory -Path $kubernetesPath -Force > $null
New-Item -ItemType Directory -Path (Join-Path $cniDir config) -Force > $null
New-Item -ItemType Directory -Path $containerdPath -Force > $null
New-Item -ItemType Directory -Path $flanneldPath -Force > $null
New-Item -ItemType Directory -Path $flanneldConfPath -Force > $null
New-Item -ItemType Directory -Path $lcowPath -Force > $null

Function CreateVMSwitch() {
    # make the switch with internet access a hyper-v switch, if it's not one already
    $interfaceIndex = (Get-WmiObject win32_networkadapterconfiguration | Where-Object {$null -ne $_.defaultipgateway}).InterfaceIndex
    $netAdapter = Get-NetAdapter -InterfaceIndex $interfaceIndex
    If(-not ($netAdapter.DriverDescription -Like "*Hyper-V*")) {
        Write-Output "Creating VM switch"
        New-VMSwitch -SwitchName $netAdapter.Name -AllowManagementOS $true -NetAdapterName $netAdapter.Name *>&1
    }
}

# From https://social.technet.microsoft.com/Forums/en-US/5aa53fef-5229-4313-a035-8b3a38ab93f5/unzip-gz-files-using-powershell?forum=winserverpowershell
Function Expand-GZip($infile, $outfile = ($infile -replace '\.gz$','')) {
    $input = New-Object System.IO.FileStream $inFile, ([IO.FileMode]::Open), ([IO.FileAccess]::Read), ([IO.FileShare]::Read)
    $output = New-Object System.IO.FileStream $outFile, ([IO.FileMode]::Create), ([IO.FileAccess]::Write), ([IO.FileShare]::None)
    $gzipStream = New-Object System.IO.Compression.GzipStream $input, ([IO.Compression.CompressionMode]::Decompress)

    $buffer = New-Object byte[](1024)
    while($true){
        $read = $gzipstream.Read($buffer, 0, 1024)
        if ($read -le 0){break}
        $output.Write($buffer, 0, $read)
    }

    $gzipStream.Close()
    $output.Close()
    $input.Close()
}

Function DownloadAndExtractTarGz($url, $dstPath) {
    $tmpTarGz = New-TemporaryFile | Rename-Item -NewName { $_ -replace 'tmp$', 'tar.gz' } -PassThru
    $tmpTar = New-TemporaryFile | Rename-Item -NewName { $_ -replace 'tmp$', 'tar' } -PassThru

    Invoke-WebRequest $url -o $tmpTarGz.FullName
    Expand-GZip $tmpTarGz.FullName $tmpTar.FullName
    Expand-7Zip $tmpTar.FullName $dstPath
    Remove-Item $tmpTarGz.FullName,$tmpTar.FullName
}

Function DownloadAndExtractZip($url, $dstPath) {
    $tmpZip = New-TemporaryFile | Rename-Item -NewName { $_ -replace 'tmp$', 'zip' } -PassThru
    Invoke-WebRequest $url -o $tmpZip.FullName
    Expand-Archive $tmpZip.FullName $dstPath
    Remove-Item $tmpZip.FullName
}
Function TestAndDownloadFile($url, $destPath, $name) {
    $dest = Join-Path $destPath $name
    if(-not (Test-Path $dest)) {
        Write-Output "Downloading $name"
        Invoke-WebRequest $url -o $dest
    }
}

Function DownloadAllFiles() {
    # download k8s binaries
    TestAndDownloadFile https://storage.googleapis.com/kubernetes-release/release/v1.13.0/bin/windows/amd64/kubeadm.exe $kubernetesPath kubeadm.exe
    TestAndDownloadFile https://storage.googleapis.com/kubernetes-release/release/v1.13.0/bin/windows/amd64/kubectl.exe $kubernetesPath kubectl.exe
    TestAndDownloadFile https://storage.googleapis.com/kubernetes-release/release/v1.13.0/bin/windows/amd64/kubelet.exe $kubernetesPath kubelet.exe
    TestAndDownloadFile https://storage.googleapis.com/kubernetes-release/release/v1.13.0/bin/windows/amd64/kube-proxy.exe $kubernetesPath kube-proxy.exe

    # download available cri binaries
    if(-not (Test-Path (Join-Path $containerdPath crictl.exe))) {
        Write-Output "Downloading crictl"
        DownloadAndExtractTarGz https://github.com/kubernetes-sigs/cri-tools/releases/download/v1.13.0/crictl-v1.13.0-windows-amd64.tar.gz $containerdPath
    }
    TestAndDownloadFile https://github.com/Microsoft/hcsshim/releases/download/v0.8.4/runhcs.exe $containerdPath runhcs.exe

    # download SDN scripts and configs
    TestAndDownloadFile https://github.com/SaswatB/SDN/raw/master/Kubernetes/windows/hns.psm1 $kubernetesPath hns.psm1
    TestAndDownloadFile https://github.com/SaswatB/SDN/raw/master/Kubernetes/windows/helper.psm1 $kubernetesPath helper.psm1
    TestAndDownloadFile https://github.com/SaswatB/SDN/raw/master/Kubernetes/windows/start-kubeproxy.ps1 $kubernetesPath start-kubeproxy.ps1
    
    TestAndDownloadFile https://github.com/SaswatB/SDN/raw/master/Kubernetes/flannel/l2bridge/start.ps1 $kubernetesPath start.ps1
    TestAndDownloadFile https://github.com/SaswatB/SDN/raw/master/Kubernetes/flannel/l2bridge/start-kubelet.ps1 $kubernetesPath start-kubelet.ps1
    TestAndDownloadFile https://github.com/SaswatB/SDN/raw/master/Kubernetes/flannel/stop.ps1 $kubernetesPath stop.ps1

    TestAndDownloadFile https://github.com/SaswatB/SDN/raw/master/Kubernetes/flannel/l2bridge/net-conf.json $kubernetesPath net-conf.json
    Copy-Item (Join-Path $kubernetesPath net-conf.json) $flanneldConfPath

    # download flannel
    TestAndDownloadFile https://github.com/coreos/flannel/releases/download/v0.11.0/flanneld.exe $kubernetesPath flanneld.exe
    Copy-Item (Join-Path $kubernetesPath flanneld.exe) $flanneldPath

    # download containerd's config
    TestAndDownloadFile https://github.com/SaswatB/windows-cri-kubernetes/raw/master/cri-configs/containerd-config.toml $containerdPath config.toml

    # download LCOW
    if(-not (Test-Path (Join-Path $lcowPath kernel))) {
        Write-Output "Downloading LCOW"
        DownloadAndExtractZip https://github.com/linuxkit/lcow/releases/download/v4.14.35-v0.3.9/release.zip  $lcowPath
    }
}

Function Assert-FileExists($file) {
    if(-not (Test-Path $file)) {
        Write-Error "$file is missing, build and place the binary before continuing."
        Exit 1
    }
}

Function UpdateCrictlConfig() {
    # set crictl to access the configured container endpoint by default
    $crictlConfigDir = "$($env:USERPROFILE)\.crictl"
    $crictlConfigPath = Join-Path $crictlConfigDir "crictl.yaml"

    if(Test-Path $crictlConfigPath) {
        return;
    }

    Write-Output "Updating crictl config"
    New-Item -ItemType Directory -Path $crictlConfigDir -Force > $null
@"
runtime-endpoint: npipe:\\\\.\pipe\containerd-containerd
image-endpoint: npipe:\\\\.\pipe\containerd-containerd
timeout: 0
debug: false
"@ | Out-File $crictlConfigPath
}

Function UpdatePath() {
    # update the path variable if it doesn't have the needed paths
    $path = [Environment]::GetEnvironmentVariable("Path", [EnvironmentVariableTarget]::Machine)
    $updated = $false
    if(-not ($path -match $kubernetesPath.Replace("\","\\")+"(;|$)"))
    {
        $path += ";"+$kubernetesPath
        $updated = $true
    }
    if(-not ($path -match $containerdPath.Replace("\","\\")+"(;|$)"))
    {
        $path += ";"+$containerdPath
        $updated = $true
    }
    if($updated)
    {
        Write-Output "Updating path"
        [Environment]::SetEnvironmentVariable("Path", $path, [EnvironmentVariableTarget]::Machine)
        $env:Path = [System.Environment]::GetEnvironmentVariable("Path","Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path","User")
    }

    # update the kubeconfig env variable
    $env:KUBECONFIG = "$kubernetesPath\config"
    [Environment]::SetEnvironmentVariable("KUBECONFIG", $env:KUBECONFIG, [EnvironmentVariableTarget]::User)
}

if(-not $SkipInstall) {
    # ask to install 7zip, if it's not already installed
    if (-not (Get-Command Expand-7Zip -ErrorAction Ignore)) {
        $confirmation = Read-Host "7Zip4PowerShell is required to extract some packages but it is not installed, would you like to install it? (y/n)"
        if ($confirmation -ne 'y') {
            Write-Error "Aborting setup"
            Exit 1
        }
        Install-Package -Scope CurrentUser -Force 7Zip4PowerShell > $null
        if(-not $?) {
            Write-Error "Failed to install package"
            Exit 1
        }
    }

    CreateVMSwitch
    DownloadAllFiles
    UpdateCriCtlConfig
    UpdatePath
}

if($OnlyInstall) {
    Exit
}

Assert-FileExists (Join-Path $containerdPath containerd.exe)
Assert-FileExists (Join-Path $containerdPath containerd-shim-runhcs-v1.exe)
Assert-FileExists (Join-Path $containerdPath ctr.exe)
Assert-FileExists (Join-Path $cniDir host-local.exe)
Assert-FileExists (Join-Path $cniDir flannel.exe)
Assert-FileExists (Join-Path $cniDir win-bridge.exe)

# copy the config file
Copy-Item $ConfigFile $kubernetesPath\config
New-Item -ItemType Directory -Path $home\.kube -Force > $null
Copy-Item $kubernetesPath\config $home\.kube\

# get the cluster cidr
if($ClusterCIDR.Length -eq 0) {
    $ccFlag = (kubectl describe pod kube-controller-manager- -n kube-system | ? { $_.Contains("--cluster-cidr") })
    if(-not $? -or $ccFlag.Length -eq 0) {
        Write-Error "Unable to get cluster cidr from config, please set -ClusterCIDR manually"
        Exit 1
    }
    $ClusterCIDR = $ccFlag.SubString($ccFlag.IndexOf("=")+1)
    Write-Output "Using cluster cidr $ClusterCIDR"
}

# get the service cidr
if($ServiceCIDR.Length -eq 0) {
    $scFlag = (kubectl describe pod kube-apiserver- -n kube-system | ? { $_.Contains("--service-cluster-ip-range") })
    if(-not $? -or $scFlag.Length -eq 0) {
        Write-Error "Unable to get service cidr from config, please set -ServiceCIDR manually"
        Exit 1
    }
    $ServiceCIDR = $scFlag.SubString($scFlag.IndexOf("=")+1, $scFlag.IndexOf("/") - $scFlag.IndexOf("=") - 1)
    Write-Output "Using service cidr $ServiceCIDR"
}

# get the dns ip
if($KubeDnsServiceIP.Length -eq 0) {
    $KubeDnsServiceIP = kubectl get svc/kube-dns -o jsonpath='{.spec.clusterIP}' -n kube-system
    if(-not $? -or $KubeDnsServiceIP.Length -eq 0) {
        Write-Error "Unable to get dns ip from config, please set -KubeDnsServiceIP manually"
        Exit 1
    }
    Write-Output "Using dns ip $KubeDnsServiceIP"
}

# get the management ip
if($ManagementIP.Length -eq 0) {
    $na = Get-NetAdapter -InterfaceIndex (Get-WmiObject win32_networkadapterconfiguration | Where-Object {$_.defaultipgateway -ne $null}).InterfaceIndex
    $ManagementIP = (Get-NetIPAddress -InterfaceAlias $na.ifAlias -AddressFamily IPv4).IPAddress
    if(-not $? -or $ManagementIP.Length -eq 0) {
        Write-Error "Unable to get dns ip from config, please set -ManagementIP manually"
        Exit 1
    }
    Write-Output "Using management ip $ManagementIP"
}

# start containerd
Write-Output "Starting containerd"
Start-Process powershell "containerd --log-level debug"

# wait for containerd to accept inputs, otherwise kubectl will close immediately
Start-Sleep 1
while(-not (get-childitem \\.\pipe\ | ?{ $_.name -eq "containerd-containerd" })) {
    Write-Output "Waiting for containerd to start"
    Start-Sleep 1
}

# start kubelet and associated processes
Push-Location $kubernetesPath
.\start.ps1 -ClusterCIDR $ClusterCIDR -ManagementIP $ManagementIP -KubeDnsServiceIP $KubeDnsServiceIP -ServiceCIDR $ServiceCIDR
Pop-Location