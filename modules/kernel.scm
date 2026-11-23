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
  #:export (linux-cachyos-bore-clang-lto nvidia-module-580-cachyos-clang-lto
            v4l2loopback-linux-module-cachyos-clang-lto))

(define cachyos-version
  "7.3.5-2")

(define cachyos-tarball
  (origin
    (method url-fetch)
    (uri (string-append
          "https://github.com/CachyOS/linux/releases/download/cachyos-"
          cachyos-version "/cachyos-" cachyos-version ".tar.gz"))
    (file-name (string-append "cachyos-" cachyos-version ".tar.gz"))
    (sha256 (base32 "01rf14wk74nl5blly025q1s7ndirhdpkcwdb7f4awbq4w6css8mv"))))

(define cachyos-bore-patch
  (origin
    (method url-fetch)
    (uri
     "https://raw.githubusercontent.com/cachyos/kernel-patches/master/7.3/sched/0001-bore-cachy.patch")
    (file-name "0001-bore-cachy.patch")
    (sha256 (base32 "1d3k47f8mbvv6q0kgachix06a2n3gmx472sg63xnpxgivglaisnj"))))

(define cachyos-dkms-clang-patch
  (origin
    (method url-fetch)
    (uri
     "https://raw.githubusercontent.com/CachyOS/kernel-patches/master/7.3/misc/dkms-clang.patch")
    (file-name "dkms-clang.patch")
    (sha256 (base32 "0jrbf6vghqdw7wrq55qz2f577g8acfqfzgxdzf42wya1704fyibg"))))

(define cachyos-config
  (origin
    (method url-fetch)
    (uri
     "https://raw.githubusercontent.com/CachyOS/linux-cachyos/master/linux-cachyos-bore/config")
    (file-name "cachyos-bore.config")
    (sha256 (base32 "1s1xggyr82n6ycxbwzif8rwsnpr69aj8xsyxjkz7xgyv3lq66nb4"))))

(define cachyos-source
  (origin
    (inherit cachyos-tarball)
    (patches (list cachyos-bore-patch cachyos-dkms-clang-patch))))

(define cachyos-configs
  '("CONFIG_SCHED_BORE=y" "CONFIG_HZ_1000=y"
    "CONFIG_HZ=1000"
    "CONFIG_HZ_100"
    "CONFIG_HZ_250"
    "CONFIG_HZ_300"
    "CONFIG_HZ_500"
    "CONFIG_HZ_600"
    "CONFIG_HZ_750"
    "CONFIG_X86_NATIVE_CPU=y"
    "CONFIG_GENERIC_CPU"
    "CONFIG_MZEN4"
    "CONFIG_X86_64_VERSION"
    "CONFIG_CC_OPTIMIZE_FOR_PERFORMANCE_O3=y"
    "CONFIG_CC_OPTIMIZE_FOR_PERFORMANCE"
    "CONFIG_V4L2_LOOPBACK"
    "CONFIG_RUST"
    "CONFIG_RUST_FW_LOADER_ABSTRACTIONS"
    "CONFIG_RUST_SERIAL_DEV_BUS_ABSTRACTIONS"
    "CONFIG_ANDROID_BINDER_IPC_RUST"
    "CONFIG_RUST_OVERFLOW_CHECKS"
    "CONFIG_LTO_CLANG_THIN=y"
    "# CONFIG_LTO_NONE is not set"
    "# CONFIG_LTO_CLANG_FULL is not set"
    "# CONFIG_LTO_CLANG_THIN_DIST is not set"))

(define cachyos-base
  (customize-linux #:name "linux-cachyos-bore-clang-lto"
                   #:linux linux-libre
                   #:source cachyos-source
                   #:defconfig "cachyos_defconfig"
                   #:extra-version "cachyos-bore-clang-lto"
                   #:configs cachyos-configs))

(define linux-cachyos-bore-clang-lto
  (package
    (inherit cachyos-base)
    (version cachyos-version)
    (supported-systems '("x86_64-linux"))
    (arguments
     (substitute-keyword-arguments (package-arguments cachyos-base)
       ((#:phases phases)
        #~(modify-phases #$phases
            (add-before 'configure 'prepare-cachyos-defconfig
              (lambda _
                (setenv "LLVM" "1")
                (setenv "LLVM_IAS" "1")
                (setenv "CC" "clang")
                (setenv "LD" "ld.lld")
                (copy-file #$cachyos-config ".config")
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
    (native-inputs (modify-inputs (package-native-inputs cachyos-base)
                     (prepend cpio
                              zstd
                              clang
                              llvm
                              lld-wrapper
                              (list gcc "lib"))))
    (home-page "https://github.com/CachyOS/linux")
    (synopsis "CachyOS BORE kernel built with Clang ThinLTO")
    (description
     "CachyOS Linux kernel with BORE scheduler, Clang ThinLTO, CachyOS configuration, and native x86-64 CPU tuning.")))

(define nvidia-module-580-cachyos-clang-lto
  (package
    (inherit nvidia-module-580)
    (name "nvidia-module-580-cachyos-clang-lto")
    (arguments
     (substitute-keyword-arguments (package-arguments nvidia-module-580)
       ((#:linux linux #f)
        linux-cachyos-bore-clang-lto)
       ((#:make-flags flags
         #~(list))
        #~(list "CC=clang" "LLVM=1" "LLVM_IAS=1" "LD=ld.lld"))))
    (native-inputs (modify-inputs (package-native-inputs nvidia-module-580)
                     (prepend clang llvm lld-wrapper
                              (list gcc "lib"))))))

(define v4l2loopback-linux-module-cachyos-clang-lto
  (package
    (inherit v4l2loopback-linux-module)
    (name "v4l2loopback-linux-module-cachyos-clang-lto")
    (arguments
     (substitute-keyword-arguments (package-arguments
                                    v4l2loopback-linux-module)
       ((#:linux linux #f)
        linux-cachyos-bore-clang-lto)
       ((#:make-flags flags
         #~(list))
        #~(append #$flags
                  '("CC=clang" "LLVM=1" "LLVM_IAS=1" "LD=ld.lld")))))
    (native-inputs (modify-inputs (package-native-inputs
                                   v4l2loopback-linux-module)
                     (prepend clang llvm lld-wrapper
                              (list gcc "lib"))))))
