## [CRITest on Windows Status](https://github.com/SaswatB/cri-tools)

`$cdep = "npipe:\\\\.\pipe\containerd-containerd"`

Waiting on [this pr](https://github.com/jterry75/cri/pull/6) for volume support

* AppArmor (apparmor.go)
  * `.\critest.exe -runtime-endpoint $cdep -"ginkgo.v" -"ginkgo.focus" "AppArmor"`
  * 0/0 passed

* Container Mount Propagation (container_linux.go)
  * `.\critest.exe -runtime-endpoint $cdep -"ginkgo.v" -"ginkgo.focus" "Container Mount Propagation"`
  * 0/0 passed

* Container (container.go)
  * `.\critest.exe -runtime-endpoint $cdep -"ginkgo.v" -"ginkgo.focus" "Container"`
  * 7/10 passed
    * Currently there's a bug when stopping a running container
    * Killing processes by closing execSync currently throws an error

* Image Manager (image.go)
  * `.\critest.exe -runtime-endpoint $cdep -"ginkgo.v" -"ginkgo.focus" "Image Manager"`
  * 5/5 passed

* Multiple Containers [Conformance] (multi_container_linux.go)
  * `.\critest.exe -runtime-endpoint $cdep -"ginkgo.v" -"ginkgo.focus" "Multiple Containers [Conformance]"`
  * 0/0 passed

* Networking (networking.go)
  * `.\critest.exe -runtime-endpoint $cdep -"ginkgo.v" -"ginkgo.focus" "Networking"`
  * 1/3 passed
    * Setting DNS is not implemented yet
    * Host port test is broken due to [current behavior in WinNAT](https://blogs.technet.microsoft.com/virtualization/2016/05/25/windows-nat-winnat-capabilities-and-limitations/)

* PodSandbox (pod.go)
  * `.\critest.exe -runtime-endpoint $cdep -"ginkgo.v" -"ginkgo.focus" "PodSandbox"`
  * 3/3 passed (moved 2 linux specific tests for sysctls)

* Runtime info (runtime_info.go)
  * `.\critest.exe -runtime-endpoint $cdep -"ginkgo.v" -"ginkgo.focus" "Runtime info"`
  * 2/2 passed

* Security Context (security_context.go)
  * `.\critest.exe -runtime-endpoint $cdep -"ginkgo.v" -"ginkgo.focus" "Security Context"`
  * 0/0 passed (moved 29 linux specific tests for security context)

* SELinux (selinux_linux.go)
  * `.\critest.exe -runtime-endpoint $cdep -"ginkgo.v" -"ginkgo.focus" "SELinux"`
  * 0/0 passed

* Streaming (streaming.go)
  * `.\critest.exe -runtime-endpoint $cdep -"ginkgo.v" -"ginkgo.focus" "Streaming"`
  * 3/5 passed
    * portForward not yet supported on Windows