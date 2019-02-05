export GOOS=windows
apt-get update
apt-get install -y mingw-w64

#cri/containerd
cd /go/src
mkdir -p github.com/containerd
cd github.com/containerd/
git clone https://github.com/jterry75/cri.git
cd cri
git checkout windows_port
cd cmd/containerd/
echo "Getting dependencies"
go get
echo "Building containerd"
go build -o /out/containerd.exe .

#ctr
cd ../ctr
git remote add upstream https://github.com/containerd/cri.git
git fetch upstream
git checkout upstream/master
echo "Getting dependencies"
go get
echo "Building ctr"
go build -o /out/ctr.exe .

#containerd-shim-runhcs-v1
cd /go/src/github.com/containerd/
git clone https://github.com/containerd/containerd.git
cd containerd/cmd/containerd-shim-runhcs-v1/
echo "Getting dependencies"
go get
echo "Building containerd-shim-runhcs-v1"
go build -o /out/containerd-shim-runhcs-v1.exe .

#wincni
cd /go/src/github.com/
mkdir -p Microsoft
cd Microsoft/
git clone https://github.com/SaswatB/windows-container-networking.git
cd windows-container-networking/
git checkout v2flowinv1
cd cni/
echo "Getting dependencies"
go get
cd ..
echo "Building wincni"
make
mv out/wincni.exe /out/

#host-local
cd /go/src/github.com/
mkdir -p containernetworking
cd containernetworking/
git clone https://github.com/containernetworking/plugins.git
cd plugins/plugins/ipam/host-local
echo "Getting dependencies"
go get
echo "Building host-local"
go build -o /out/host-local.exe .

#flannel
cd /go/src/github.com/containernetworking/plugins/plugins/meta/flannel/
echo "Getting dependencies"
go get
echo "Building flannel"
go build -o /out/flannel.exe .

#win-bridge
cd /go/src/github.com/
mkdir -p Microsoft
cd Microsoft/
git clone https://github.com/Microsoft/windows-container-networking.git
cd windows-container-networking/plugins/sdnbridge/
echo "Getting dependencies"
go get
echo "Building win-bridge"
go build -o /out/win-bridge.exe .

#flanneld
cd /go/src/github.com/
mkdir -p coreos
cd coreos/
git clone https://github.com/coreos/flannel.git
cd flannel/
echo "Getting dependencies"
go get
echo "Building flanneld"
make dist/flanneld.exe
mv dist/flanneld.exe /out/.