
[CmdletBinding(PositionalBinding=$false)]
Param
(
    [parameter(ParameterSetName='Default', Mandatory = $true, HelpMessage='Kubernetes Config File')] [string]$ConfigFile,
    [parameter(ParameterSetName='Default', Mandatory = $false, HelpMessage='Kubernetes Master Node Ip')] [string]$MasterIp="",
    [parameter(ParameterSetName='Default', Mandatory = $false, HelpMessage='Kubernetes Pod Service CIDR')] $ClusterCIDR = "10.244.0.0/16",
    [parameter(ParameterSetName='Default', Mandatory = $false)] [switch] $SkipInstall,

    [parameter(ParameterSetName='OnlyInstall', Mandatory = $false)] [switch] $OnlyInstall
)
$ProgressPreference = 'SilentlyContinue'

$kubernetesPath = "C:\k"
$cniDir = Join-Path $kubernetesPath cni
$containerdPath = "$Env:ProgramFiles\containerd"

New-Item -ItemType Directory -Path $kubernetesPath -Force > $null
New-Item -ItemType Directory -Path (Join-Path $cniDir config) -Force > $null
New-Item -ItemType Directory -Path $containerdPath -Force > $null

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

    if(-not (Test-Path (Join-Path $containerdPath crictl.exe))) {
        Write-Output "Downloading crictl"
        DownloadAndExtractTarGz https://github.com/kubernetes-sigs/cri-tools/releases/download/v1.13.0/crictl-v1.13.0-windows-amd64.tar.gz $containerdPath
    }
    TestAndDownloadFile https://github.com/Microsoft/hcsshim/releases/download/v0.8.3/runhcs.exe $containerdPath runhcs.exe

    TestAndDownloadFile https://github.com/SaswatB/SDN/raw/master/Kubernetes/windows/helper.psm1 $kubernetesPath helper.psm1
    TestAndDownloadFile https://github.com/SaswatB/SDN/raw/master/Kubernetes/windows/hns.psm1 $kubernetesPath hns.psm1
    TestAndDownloadFile https://github.com/SaswatB/SDN/raw/master/Kubernetes/windows/start-kubeproxy.ps1 $kubernetesPath start-kubeproxy.ps1
    TestAndDownloadFile https://github.com/SaswatB/SDN/raw/master/Kubernetes/windows/start.ps1 $kubernetesPath start.ps1
    TestAndDownloadFile https://github.com/SaswatB/SDN/raw/master/Kubernetes/windows/start-kubelet.ps1 $kubernetesPath start-kubelet.ps1
    TestAndDownloadFile https://github.com/Microsoft/SDN/raw/master/Kubernetes/windows/AddRoutes.ps1 $kubernetesPath AddRoutes.ps1
    TestAndDownloadFile https://github.com/SaswatB/SDN/raw/master/Kubernetes/windows/stop.ps1 $kubernetesPath stop.ps1

    TestAndDownloadFile https://github.com/SaswatB/windows-cri-kubernetes/raw/master/cri-configs/containerd-config.toml $containerdPath config.toml
}

Function Assert-FileExists($file) {
    if(-not (Test-Path $file)) {
        Write-Error "$file is missing, build and place the binary before continuing."
        Exit 1
    }
}

Function UpdateCrictlConfig() {
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
Assert-FileExists (Join-Path $cniDir wincni.exe)

#get the master ip
if($MasterIp.Length -eq 0) {
    $MasterIp = ([System.Uri](kubectl config view -o jsonpath='{.clusters[0].cluster.server}' --kubeconfig $ConfigFile)).Host
    if(-not $? -or $MasterIp.Length -eq 0) {
        Write-Error "Unable to get master ip from config"
        Exit 1
    }
    Write-Output "Using master ip $MasterIp"
}

#copy the config file
Copy-Item $ConfigFile $kubernetesPath\config
New-Item -ItemType Directory -Path $home\.kube -Force > $null
Copy-Item $kubernetesPath\config $home\.kube\

#start containerd
Write-Output "Starting containerd"
Start-Process powershell "containerd --log-level debug"

# wait for containerd to accept inputs, otherwise kubectl will close immediately
Start-Sleep 1
while(-not (get-childitem \\.\pipe\ | ?{ $_.name -eq "containerd-containerd" })) {
    Write-Output "Waiting for containerd to start"
    Start-Sleep 1
}

#start kubelet and associated processes
Push-Location $kubernetesPath
.\start.ps1 -MasterIp $MasterIp -ClusterCIDR $ClusterCIDR
Pop-Location