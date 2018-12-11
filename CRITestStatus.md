## [CRITest on Windows Status](https://github.com/SaswatB/cri-tools)

* AppArmor (apparmor.go)
  * .\critest.exe -runtime-endpoint $cdep -"ginkgo.v" -"ginkgo.focus" "AppArmor"
  * 0/0 passed

* Container Mount Propagation (container_linux.go)
  * .\critest.exe -runtime-endpoint $cdep -"ginkgo.v" -"ginkgo.focus" "Container Mount Propagation"
  * 0/0 passed

* Container (container.go)
  * .\critest.exe -runtime-endpoint $cdep -"ginkgo.v" -"ginkgo.focus" "Container"
  * 0/10 passed

* Image Manager (image.go)
  * .\critest.exe -runtime-endpoint $cdep -"ginkgo.v" -"ginkgo.focus" "Image Manager"
  * 6/6 passed

* Multiple Containers [Conformance] (multi_container_linux.go)
  * .\critest.exe -runtime-endpoint $cdep -"ginkgo.v" -"ginkgo.focus" "Multiple Containers [Conformance]"
  * 0/0 passed

* Networking (networking.go)
  * .\critest.exe -runtime-endpoint $cdep -"ginkgo.v" -"ginkgo.focus" "Networking"
  * 0/3 passed

* PodSandbox (pod.go)
  * .\critest.exe -runtime-endpoint $cdep -"ginkgo.v" -"ginkgo.focus" "PodSandbox"
  * 3/3 passed (removed 2 linux specific tests for sysctls)

* Runtime info (runtime_info.go)
  * .\critest.exe -runtime-endpoint $cdep -"ginkgo.v" -"ginkgo.focus" "Runtime info"
  * 2/2 passed

* Security Context (security_context.go)
  * .\critest.exe -runtime-endpoint $cdep -"ginkgo.v" -"ginkgo.focus" "Security Context"
  * 0/29 passed

* SELinux (selinux_linux.go)
  * .\critest.exe -runtime-endpoint $cdep -"ginkgo.v" -"ginkgo.focus" "SELinux"
  * 0/0 passed

* Streaming (streaming.go)
  * .\critest.exe -runtime-endpoint $cdep -"ginkgo.v" -"ginkgo.focus" "Streaming"
  * 0/5 passed