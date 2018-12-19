
[CmdletBinding(PositionalBinding=$false)]
Param
(
    [parameter(Mandatory = $true, HelpMessage='Kubernetes Config File')] [string]$ConfigFile,

    [parameter(Mandatory = $false)] [switch] $SkipInstall,
    [parameter(Mandatory = $false)] $ClusterCIDR = "10.244.0.0/16",
    [parameter(Mandatory = $false)] $KubeDnsServiceIP = "10.96.0.10",
    [parameter(Mandatory = $false)] $ServiceCIDR = "10.96.0.0/12"
)
$ProgressPreference = 'SilentlyContinue'

$kubernetesPath = "C:\k"
$containerdPath = "$Env:ProgramFiles\containerd"

mkdir -Force $kubernetesPath > $null; mkdir -Force (Join-Path $kubernetesPath cni\config) > $null
mkdir -Force $containerdPath > $null

Function CreateVMSwitch() {
    # make the switch with internet access a hyper-v switch, if it's not one already
    $interfaceIndex = (Get-WmiObject win32_networkadapterconfiguration | Where-Object {$null -ne $_.defaultipgateway}).InterfaceIndex
    $netAdapter = Get-NetAdapter -InterfaceIndex $interfaceIndex
    If(-not ($netAdapter.DriverDescription -Like "*Hyper-V*")) {
        Write-Output "Creating VM Switch"
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

Function TestAndDownloadFile($url, $destPath, $name) {
    $dest = Join-Path $destPath $name
    if(-not (Test-Path $dest)) {
        Write-Output "Downloading $name"
        Invoke-WebRequest $url -o $dest
    }
}

Function DownloadAllFiles() {
    TestAndDownloadFile https://storage.googleapis.com/kubernetes-release/release/v1.13.0/bin/windows/amd64/kubeadm.exe $kubernetesPath kubeadm.exe
    TestAndDownloadFile https://storage.googleapis.com/kubernetes-release/release/v1.13.0/bin/windows/amd64/kubectl.exe $kubernetesPath kubectl.exe
    TestAndDownloadFile https://storage.googleapis.com/kubernetes-release/release/v1.13.0/bin/windows/amd64/kubelet.exe $kubernetesPath kubelet.exe
    TestAndDownloadFile https://storage.googleapis.com/kubernetes-release/release/v1.13.0/bin/windows/amd64/kube-proxy.exe $kubernetesPath kube-proxy.exe

    $cniDir = Join-Path $kubernetesPath cni
    TestAndDownloadFile https://github.com/Microsoft/SDN/raw/master/Kubernetes/flannel/l2bridge/cni/flannel.exe $cniDir flannel.exe
    TestAndDownloadFile https://github.com/Microsoft/SDN/raw/master/Kubernetes/flannel/l2bridge/cni/host-local.exe $cniDir host-local.exe
    TestAndDownloadFile https://github.com/Microsoft/SDN/raw/master/Kubernetes/flannel/l2bridge/cni/win-bridge.exe $cniDir win-bridge.exe

    if(-not (Test-Path (Join-Path $containerdPath crictl.exe))) {
        Write-Output "Downloading crictl"
        DownloadAndExtractTarGz https://github.com/kubernetes-sigs/cri-tools/releases/download/v1.13.0/crictl-v1.13.0-windows-amd64.tar.gz $containerdPath
    }
    TestAndDownloadFile https://github.com/Microsoft/hcsshim/releases/download/v0.8.3/runhcs.exe $containerdPath runhcs.exe

    TestAndDownloadFile https://github.com/SaswatB/SDN/raw/master/Kubernetes/windows/helper.psm1 $kubernetesPath helper.psm1
    TestAndDownloadFile https://github.com/SaswatB/SDN/raw/master/Kubernetes/windows/hns.psm1 $kubernetesPath hns.psm1
    TestAndDownloadFile https://github.com/SaswatB/SDN/raw/master/Kubernetes/windows/start-kubeproxy.ps1 $kubernetesPath start-kubeproxy.ps1
    TestAndDownloadFile https://github.com/SaswatB/SDN/raw/master/Kubernetes/flannel/l2bridge/start.ps1 $kubernetesPath start.ps1
    TestAndDownloadFile https://github.com/SaswatB/SDN/raw/master/Kubernetes/flannel/l2bridge/start-kubelet.ps1 $kubernetesPath start-kubelet.ps1
    TestAndDownloadFile https://github.com/SaswatB/SDN/raw/master/Kubernetes/flannel/stop.ps1 $kubernetesPath stop.ps1
    TestAndDownloadFile https://github.com/Microsoft/SDN/raw/master/Kubernetes/flannel/l2bridge/net-conf.json $kubernetesPath net-conf.json

    TestAndDownloadFile https://github.com/SaswatB/windows-cri-kubernetes/raw/master/cri-configs/containerd-config.toml $containerdPath config.toml
}

Function Assert-FileExists($file) {
    if(-not (Test-Path $file)) {
        Write-Error "$file is missing, build and place the binary before continuing."
        Exit 1
    }
}

Function UpdatePath() {
    Write-Output "Updating Path"
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
        [Environment]::SetEnvironmentVariable("Path", $path, [EnvironmentVariableTarget]::Machine)
    }
    [Environment]::SetEnvironmentVariable("KUBECONFIG", "$kubernetesPath\config", [EnvironmentVariableTarget]::User)
    $env:Path = [System.Environment]::GetEnvironmentVariable("Path","Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path","User")
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
    UpdatePath
}

Assert-FileExists (Join-Path $containerdPath containerd.exe)
Assert-FileExists (Join-Path $containerdPath containerd-shim-runhcs-v1.exe)
Assert-FileExists (Join-Path $containerdPath ctr.exe)

#copy the config file
Copy-Item $ConfigFile $kubernetesPath\config
mkdir -Force $home\.kube > $null
Copy-Item $kubernetesPath\config $home\.kube\

#start containerd
Write-Output "Starting ContainerD"
start powershell "containerd --log-level debug"

#start kubelet and associated processes
pushd $kubernetesPath
$address = ((Get-NetAdapter -InterfaceIndex (Get-WmiObject win32_networkadapterconfiguration | Where-Object {$_.defaultipgateway -ne $null}).InterfaceIndex -IncludeHidden) | ? {-not $_.Hidden} | Get-NetIPAddress -AddressFamily IPv4).IPAddress | Select -First 1
.\start.ps1 -ManagementIP $address -ClusterCIDR $ClusterCIDR -KubeDnsServiceIP $KubeDnsServiceIP -ServiceCIDR $ServiceCIDR
popd