# Windows CRI/ContainerD for Kubernetes
The purpose of this repository is to provide updates on the status of Kubernetes running with CRI/ContainerD on Windows.
Relevant scripts and code will also be kept here as necessary.

Instructions to setup a Windows k8s node with CRI/ContainerD are available in ContainerDSetup.md

## Status

### 2/12/19
  * Updated containerd configuration to use better runtime names

### 2/5/19
  * Upstreamed critest port
  * Added start of flannel configuration to setup script

### 1/28/19
  * Updated instructions for cni
  * [Started upstreaming critest port](https://github.com/kubernetes-sigs/cri-tools/pull/430)

### 1/14/19
  * Implemented volume support in CRI for Windows
  * Ported volume tests in CRITest
  * Updated default containerd config to support runtimes

### 1/7/19
  * Added additional runtimes and windows test images to CRITest

### 12/31/18
  * Finished porting CRITest for working tests

### 12/18/18
  * Added setup script
    * ~~Working on getting the pause container set up properly~~
  * Continuing work on CRITest

### 12/10/18
  * Creating setup script for CRI/ContainerD on Windows
  * Working on getting CRITest to pass on Windows
