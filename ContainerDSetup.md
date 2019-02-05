# ContainerD Setup on Windows

## Prerequisites

### ContainerD Binaries
You will need to build the following binaries and copy them to the specified folder
* `containerd.exe`
  * https://github.com/jterry75/cri/tree/windows_port/cmd/containerd
  * `C:\Program Files\containerd`
* `ctr.exe`
  * https://github.com/containerd/cri/tree/master/cmd/ctr
  * `C:\Program Files\containerd`
* `containerd-shim-runhcs-v1.exe`
  * https://github.com/containerd/containerd/tree/master/cmd/containerd-shim-runhcs-v1
  * `C:\Program Files\containerd`
* `host-local.exe`
  * https://github.com/containernetworking/plugins/tree/master/plugins/ipam/host-local
  * `C:\k\cni`
* `flannel.exe`
  * https://github.com/containernetworking/plugins/tree/master/plugins/meta/flannel
  * `C:\k\cni`
* `win-bridge.exe`
  * https://github.com/Microsoft/windows-container-networking/tree/master/plugins/sdnbridge
  * `C:\k\cni`

You can use the following command to build and place the binaries in the working directory.
Copy `scripts/cribuild.sh` to the working directory before running it.
```bash
docker run --rm -v "$PWD":/out -w /out golang:stretch bash cribuild.sh
```

### Windows Features
Windows Server 2019 is required with Hyper-V and Containers installed.
```powershell
Enable-WindowsOptionalFeature -Online -FeatureName "Containers" -All
Enable-WindowsOptionalFeature -Online -FeatureName "Microsoft-Hyper-V" -All
```

## Setup and Running
Use `Setup-CriKubernetesNode.ps1` from `scripts/` to setup and run the kubelet and containerd on the local node. This script will download most dependencies and config files.

```powershell
# Setup and run containerd and kubelet locally
# the config file can be obtained from /etc/kubernetes/admin.conf on the master
.\Setup-CriKubernetesNode.ps1 -ConfigFile my-config.conf

# Skip setup and only run containerd and kubelet
.\Setup-CriKubernetesNode.ps1 -ConfigFile my-config.conf -SkipInstall
```