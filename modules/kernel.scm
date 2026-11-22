(define-module (modules kernel)
  #:use-module (guix gexp)
  #:use-module (guix download)
  #:use-module (guix packages)
  #:use-module (guix utils)
  #:use-module (gnu packages cpio)
  #:use-module (gnu packages compression)
  #:use-module (gnu packages linux)
  #:use-module (nongnu packages linux)
  #:use-module (nongnu packages nvidia)
  #:export (linux-cachyos-bore-intel nvidia-module-580-cachyos
                                     v4l2loopback-linux-module-cachyos))

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
    (patches (list cachyos-bore-patch))))

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
    "CONFIG_RUST_OVERFLOW_CHECKS"))

(define cachyos-base
  (customize-linux #:name "linux-cachyos-bore-intel"
                   #:linux linux-libre
                   #:source cachyos-source
                   #:defconfig "cachyos_defconfig"
                   #:extra-version "cachyos-bore-intel"
                   #:configs cachyos-configs))

(define linux-cachyos-bore-intel
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
                (copy-file #$cachyos-config ".config")
                (invoke "make" "olddefconfig")
                (invoke "make" "savedefconfig")
                (rename-file "defconfig" "arch/x86/configs/cachyos_defconfig")))))))
    (native-inputs (modify-inputs (package-native-inputs cachyos-base)
                     (prepend cpio zstd)))
    (home-page "https://github.com/CachyOS/linux")
    (synopsis "CachyOS BORE kernel optimized for x86-64")
    (description
     "CachyOS Linux kernel with BORE scheduler, CachyOS configuration, and native x86-64 CPU tuning.")))

(define nvidia-module-580-cachyos
  (package
    (inherit nvidia-module-580)
    (name "nvidia-module-580-cachyos")
    (arguments
     (substitute-keyword-arguments (package-arguments nvidia-module-580)
       ((#:linux linux #f)
        linux-cachyos-bore-intel)))))

(define v4l2loopback-linux-module-cachyos
  (package
    (inherit v4l2loopback-linux-module)
    (name "v4l2loopback-linux-module-cachyos")
    (arguments
     (substitute-keyword-arguments (package-arguments
                                    v4l2loopback-linux-module)
       ((#:linux linux #f)
        linux-cachyos-bore-intel)))))
