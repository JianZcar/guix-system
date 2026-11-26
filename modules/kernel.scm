(define-module (modules kernel)
  #:use-module (guix gexp)
  #:use-module (guix git)
  #:use-module (guix packages)
  #:use-module (guix utils)
  #:use-module (gnu packages cpio)
  #:use-module (gnu packages compression)
  #:use-module (gnu packages gcc)
  #:use-module (gnu packages llvm)
  #:use-module (gnu packages linux)
  #:use-module (nongnu packages linux)
  #:use-module (nongnu packages nvidia)
  #:use-module (modules nvidia)
  #:export (make-kernel-cachyos make-nvidia-module-cachyos))

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

(define* (make-kernel-cachyos #:key series release)
  (let* ((version (string-append series "." release))
         (source (git-checkout (url "https://github.com/CachyOS/linux")
                               (commit (string-append "cachyos-" version))
                               (recursive? #t)))
         (config-source (git-checkout (url
                                       "https://github.com/CachyOS/linux-cachyos")
                                      (branch "master")
                                      (recursive? #t)))
         (patches-source (git-checkout (url
                                        "https://github.com/CachyOS/kernel-patches")
                                       (branch "master")
                                       (recursive? #t)))
         (bore-patch (file-append patches-source "/" series
                                  "/sched/0001-bore-cachy.patch"))
         (dkms-clang-patch (file-append patches-source "/" series
                                        "/misc/dkms-clang.patch"))
         (config (file-append config-source "/linux-cachyos-bore/config"))
         (base (customize-linux #:name "linux-cachyos"
                                #:linux linux-libre
                                #:source source
                                #:defconfig "cachyos_defconfig"
                                #:extra-version "kernel-cachyos"
                                #:configs kernel-cachyos-configs)))
    (package
      (inherit base)
      (version version)
      (supported-systems '("x86_64-linux"))

      (arguments
       (substitute-keyword-arguments (package-arguments base)
         ((#:phases phases)
          #~(modify-phases #$phases
              (add-after 'unpack 'apply-cachyos-patches
                (lambda _
                  (invoke "patch"
                          "--batch"
                          "--forward"
                          "-p1"
                          "-i"
                          #$bore-patch)
                  (invoke "patch"
                          "--batch"
                          "--forward"
                          "-p1"
                          "-i"
                          #$dkms-clang-patch)))

              (add-before 'configure 'prepare-cachyos-defconfig
                (lambda _
                  (setenv "LLVM" "1")
                  (setenv "LLVM_IAS" "1")
                  (setenv "CC" "clang")
                  (setenv "LD" "ld.lld")
                  (copy-file #$config ".config")
                  (invoke "make" "olddefconfig")
                  (invoke "make" "savedefconfig")
                  (rename-file "defconfig"
                               "arch/x86/configs/cachyos_defconfig")))

              (add-before 'build 'set-libgcc-path
                (lambda* (#:key inputs #:allow-other-keys)
                  (setenv "LD_LIBRARY_PATH"
                          (string-append (assoc-ref inputs "gcc") "/lib"))))))

         ((#:make-flags flags
           #~(list))
          #~(append #$flags
                    '("LLVM=1" "LLVM_IAS=1" "CC=clang" "LD=ld.lld")))))

      (native-inputs (modify-inputs (package-native-inputs base)
                       (prepend cpio
                                zstd
                                clang
                                llvm
                                lld-wrapper
                                (list gcc "lib"))))

      (home-page "https://github.com/CachyOS/linux")
      (synopsis "CachyOS Linux kernel")
      (description
       "CachyOS Linux kernel built with the BORE scheduler, Clang/LLVM ThinLTO, native x86-64 CPU tuning."))))

(define* (make-nvidia-module-cachyos kernel
                                     #:key version)
  (let ((nvidia-module (nvidia-package "nvidia-module" version)))
    (package
      (inherit nvidia-module)
      (name "nvidia-module-cachyos")
      (arguments
       (substitute-keyword-arguments (package-arguments nvidia-module)
         ((#:linux linux #f)
          kernel)
         ((#:make-flags flags
           #~(list))
          #~(list "CC=clang" "LLVM=1" "LLVM_IAS=1" "LD=ld.lld"))))
      (native-inputs (modify-inputs (package-native-inputs nvidia-module)
                       (prepend clang llvm lld-wrapper
                                (list gcc "lib")))))))
