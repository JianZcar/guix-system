(define-module (modules kernel)
  #:use-module (guix gexp)
  #:use-module (guix download)
  #:use-module (guix packages)
  #:use-module (guix utils)
  #:use-module (gnu packages cpio)
  #:use-module (gnu packages compression)
  #:use-module (gnu packages gcc)
  #:use-module (gnu packages llvm)
  #:use-module (gnu packages linux)
  #:use-module (nongnu packages linux)
  #:use-module (nongnu packages nvidia)
  #:export (kernel-cachyos nvidia-module-cachyos))

(define kernel-cachyos-version
  "7.3.5-2")

(define kernel-cachyos-tarball
  (origin
    (method url-fetch)
    (uri (string-append
          "https://github.com/CachyOS/linux/releases/download/cachyos-"
          kernel-cachyos-version "/cachyos-" kernel-cachyos-version ".tar.gz"))
    (file-name (string-append "cachyos-" kernel-cachyos-version ".tar.gz"))
    (sha256 (base32 "01rf14wk74nl5blly025q1s7ndirhdpkcwdb7f4awbq4w6css8mv"))))

(define kernel-cachyos-bore-patch
  (origin
    (method url-fetch)
    (uri
     "https://raw.githubusercontent.com/cachyos/kernel-patches/master/7.3/sched/0001-bore-cachy.patch")
    (file-name "0001-bore-cachy.patch")
    (sha256 (base32 "1d3k47f8mbvv6q0kgachix06a2n3gmx472sg63xnpxgivglaisnj"))))

(define kernel-cachyos-dkms-clang-patch
  (origin
    (method url-fetch)
    (uri
     "https://raw.githubusercontent.com/CachyOS/kernel-patches/master/7.3/misc/dkms-clang.patch")
    (file-name "dkms-clang.patch")
    (sha256 (base32 "0jrbf6vghqdw7wrq55qz2f577g8acfqfzgxdzf42wya1704fyibg"))))

(define kernel-cachyos-config
  (origin
    (method url-fetch)
    (uri
     "https://raw.githubusercontent.com/CachyOS/linux-cachyos/master/linux-cachyos-bore/config")
    (file-name "cachyos-bore.config")
    (sha256 (base32 "1s1xggyr82n6ycxbwzif8rwsnpr69aj8xsyxjkz7xgyv3lq66nb4"))))

(define kernel-cachyos-source
  (origin
    (inherit kernel-cachyos-tarball)
    (patches (list kernel-cachyos-bore-patch kernel-cachyos-dkms-clang-patch))))

(define kernel-cachyos-configs
  '("CONFIG_CACHY=y" "CONFIG_SCHED_BORE=y"
    "CONFIG_HZ_1000=y"
    "# CONFIG_HZ_100 is not set"
    "# CONFIG_HZ_250 is not set"
    "# CONFIG_HZ_300 is not set"
    "# CONFIG_HZ_500 is not set"
    "# CONFIG_HZ_600 is not set"
    "# CONFIG_HZ_750 is not set"
    "CONFIG_HZ=1000"
    "CONFIG_X86_NATIVE_CPU=y"
    "# CONFIG_GENERIC_CPU is not set"
    "# CONFIG_MZEN4 is not set"
    "# CONFIG_X86_64_VERSION is not set"
    "CONFIG_CC_OPTIMIZE_FOR_PERFORMANCE_O3=y"
    "# CONFIG_CC_OPTIMIZE_FOR_PERFORMANCE is not set"
    "CONFIG_MEDIA_SUPPORT=y"
    "CONFIG_VIDEO_DEV=y"
    "CONFIG_V4L2_LOOPBACK=y"
    "CONFIG_LTO_CLANG_THIN=y"
    "# CONFIG_LTO_NONE is not set"
    "# CONFIG_LTO_CLANG_FULL is not set"
    "# CONFIG_LTO_CLANG_THIN_DIST is not set"
    "CONFIG_DEBUG_INFO_NONE=y"
    "# CONFIG_DEBUG_INFO is not set"
    "# CONFIG_DEBUG_INFO_DWARF_TOOLCHAIN_DEFAULT is not set"
    "# CONFIG_DEBUG_INFO_DWARF4 is not set"
    "# CONFIG_DEBUG_INFO_DWARF5 is not set"
    "# CONFIG_DEBUG_INFO_BTF is not set"
    "# CONFIG_DEBUG_INFO_BTF_MODULES is not set"
    "# CONFIG_SCHED_CLASS_EXT is not set"
    "# CONFIG_BINFMT_MISC_BPF is not set"
    "# CONFIG_NET_SCH_BPF is not set"
    "# CONFIG_GDB_SCRIPTS is not set"
    "# CONFIG_RUST is not set"
    "# CONFIG_RUST_FW_LOADER_ABSTRACTIONS is not set"
    "# CONFIG_RUST_SERIAL_DEV_BUS_ABSTRACTIONS is not set"
    "# CONFIG_ANDROID_BINDER_IPC_RUST is not set"
    "# CONFIG_RUST_OVERFLOW_CHECKS is not set"))

(define kernel-cachyos-base
  (customize-linux #:name "kernel-cachyos"
                   #:linux linux-libre
                   #:source kernel-cachyos-source
                   #:defconfig "cachyos_defconfig"
                   #:extra-version "kernel-cachyos"
                   #:configs kernel-cachyos-configs))

(define kernel-cachyos
  (package
    (inherit kernel-cachyos-base)
    (version kernel-cachyos-version)
    (supported-systems '("x86_64-linux"))
    (arguments
     (substitute-keyword-arguments (package-arguments kernel-cachyos-base)
       ((#:phases phases)
        #~(modify-phases #$phases
            (add-before 'configure 'prepare-cachyos-defconfig
              (lambda _
                (setenv "LLVM" "1")
                (setenv "LLVM_IAS" "1")
                (setenv "CC" "clang")
                (setenv "LD" "ld.lld")
                (copy-file #$kernel-cachyos-config ".config")
                (invoke "make" "olddefconfig")
                (invoke "make" "savedefconfig")
                (rename-file "defconfig" "arch/x86/configs/cachyos_defconfig")))
            (add-before 'build 'set-libgcc-path
              (lambda* (#:key inputs #:allow-other-keys)
                (setenv "LD_LIBRARY_PATH"
                        (string-append (assoc-ref inputs "gcc") "/lib"))))))
       ((#:make-flags flags
         #~(list))
        #~(append #$flags
                  '("LLVM=1" "LLVM_IAS=1" "CC=clang" "LD=ld.lld")))))
    (native-inputs (modify-inputs (package-native-inputs kernel-cachyos-base)
                     (prepend cpio
                              zstd
                              clang
                              llvm
                              lld-wrapper
                              (list gcc "lib"))))
    (home-page "https://github.com/CachyOS/linux")
    (synopsis "CachyOS Linux kernel")
    (description
     "CachyOS Linux kernel built with the BORE scheduler, Clang/LLVM ThinLTO, native x86-64 CPU tuning, and the CachyOS configuration.")))

(define nvidia-module-cachyos
  (package
    (inherit nvidia-module-580)
    (name "nvidia-module-cachyos")
    (arguments
     (substitute-keyword-arguments (package-arguments nvidia-module-580)
       ((#:linux linux #f)
        kernel-cachyos)
       ((#:make-flags flags
         #~(list))
        #~(list "CC=clang" "LLVM=1" "LLVM_IAS=1" "LD=ld.lld"))))
    (native-inputs (modify-inputs (package-native-inputs nvidia-module-580)
                     (prepend clang llvm lld-wrapper
                              (list gcc "lib"))))))
