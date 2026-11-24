(add-to-load-path (dirname (current-filename)))

(use-modules (guix gexp)
             (guix packages)
             (gnu)
             (gnu packages linux)
             (gnu system privilege)
             (nongnu packages linux)
             (nongnu system linux-initrd)
             (modules desktop)
             (modules kernel)
             (modules packages)
             (modules services)
             (modules system)
             (modules users))

(define enable-nvidia? #t)

(define (add-services os)
  (operating-system
    (inherit os)
    (services (make-services os))))

(nvidia-transform enable-nvidia? (add-services (operating-system
                    (initrd microcode-initrd)
                    (kernel kernel-cachyos)
                    (kernel-arguments '("zswap.enabled=0"
                                        "transparent_hugepage=madvise"
                                        "v4l2loopback.devices=1"
                                        "v4l2loopback.video_nr=10"
                                        "v4l2loopback.card_label=OBS-Virtual-Camera"
                                        "v4l2loopback.exclusive_caps=1"))

                    (firmware (cons* linux-firmware %base-firmware))

                    (locale "en_PH.utf8")
                    (timezone "Asia/Manila")
                    (keyboard-layout (keyboard-layout "us"))
                    (host-name "zena")

                    (users (append user-accounts %base-user-accounts))

                    (packages (append (patch-packages enable-nvidia?)
                                      (specifications->packages
                                        (packages enable-nvidia?))
                                      %base-packages))
                    (privileged-programs (privileged-programs enable-nvidia?))

                    (services '())

                    (bootloader (bootloader-configuration
                                  (bootloader grub-efi-bootloader)
                                  (targets (list "/boot/efi"))
                                  (keyboard-layout keyboard-layout)))

                    (mapped-devices (list (mapped-device
                                            (source (uuid
                                                     "324ed28c-917e-4e21-9f01-ee863599bd13"))
                                            (target "cryptroot")
                                            (type luks-device-mapping))))

                    ;; The list of file systems that get "mounted".  The unique
                    ;; file system identifiers there ("UUIDs") can be obtained
                    ;; by running 'blkid' in a terminal.
                    (file-systems (cons* (file-system
                                           (mount-point "/")
                                           (device "/dev/mapper/cryptroot")
                                           (type "btrfs")
                                           (flags '(no-atime))
                                           (options
                                            "compress=zstd:3,space_cache=v2")
                                           (dependencies mapped-devices))
                                          (file-system
                                            (mount-point "/boot/efi")
                                            (device (uuid "A604-A46D"
                                                          'fat32))
                                            (type "vfat")) %base-file-systems)))))
