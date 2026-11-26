(add-to-load-path (dirname (current-filename)))

(use-modules (guix gexp)
             (guix packages)
             (gnu)
             (gnu packages linux)
             (gnu system accounts)
             (gnu system privilege)
             (nongnu packages linux)
             (nongnu system linux-initrd)
             (modules desktop)
             (modules kernel)
             (modules nvidia)
             (modules packages)
             (modules services))

(define locale
  "en_PH.utf8")

(define timezone
  "Asia/Manila")

(define keyboard
  "us")

(define host-name
  "zena")

(define users
  (list (user-account
          (name "jian")
          (comment "Jian Zcar")
          (group "users")
          (home-directory "/home/jian")
          (supplementary-groups '("wheel" "netdev"
                                  "input"
                                  "audio"
                                  "video"
                                  "i2c"
                                  "kvm"
                                  "libvirt")))))

(define kernel-cachyos
  (make-kernel-cachyos #:series "7.3"
                       #:release "5-2"))

(define kernel-arguments
  '("zswap.enabled=0" "transparent_hugepage=madvise"))

(define enable-nvidia?
  #t)

(define nvidia-version
  "580")

(define enable-luks?
  #t)

(define luks-partition-uuid
  "324ed28c-917e-4e21-9f01-ee863599bd13")

(define root-partition-uuid
  "REPLACE-WITH-UNENCRYPTED-ROOT-UUID")

(define efi-partition-uuid
  "A604-A46D")

(nvidia-transform enable-nvidia?
                  (operating-system
                    (initrd microcode-initrd)
                    (kernel kernel-cachyos)
                    (kernel-arguments (append kernel-arguments
                                              '("v4l2loopback.devices=1"
                                                "v4l2loopback.video_nr=10"
                                                "v4l2loopback.card_label=OBS-Virtual-Camera"
                                                "v4l2loopback.exclusive_caps=1")))

                    (firmware (cons* linux-firmware %base-firmware))
                    (locale locale)
                    (timezone timezone)
                    (keyboard-layout (keyboard-layout keyboard))
                    (host-name host-name)
                    (users (append users %base-user-accounts))
                    (packages (append (patch-packages enable-nvidia?
                                                      #:version nvidia-version)
                                      (specifications->packages (packages
                                                                 enable-nvidia?
                                                                 #:version
                                                                 nvidia-version))
                                      %base-packages))
                    (privileged-programs (privileged-programs enable-nvidia?
                                                              #:version
                                                              nvidia-version))
                    (services
                     (make-services #:host-name host-name
                                    #:users users))

                    (bootloader (bootloader-configuration
                                  (bootloader grub-efi-bootloader)
                                  (targets (list "/boot/efi"))
                                  (keyboard-layout keyboard-layout)
                                  (theme (grub-theme (inherit (grub-theme))
                                                     (image (local-file
                                                             "./wallpapers/guix-dark.png"))))))

                    (mapped-devices (if enable-luks?
                                        (list (mapped-device
                                                (source (uuid
                                                         luks-partition-uuid))
                                                (target "cryptroot")
                                                (type luks-device-mapping)))
                                        '()))

                    (file-systems (cons* (file-system
                                           (mount-point "/")
                                           (device (if enable-luks?
                                                    "/dev/mapper/cryptroot"
                                                    (uuid root-partition-uuid)))
                                           (type "btrfs")
                                           (flags '(no-atime))
                                           (options
                                            "compress=zstd:3,space_cache=v2")
                                           (dependencies mapped-devices))
                                         (file-system
                                           (mount-point "/boot/efi")
                                           (device (uuid efi-partition-uuid
                                                         'fat32))
                                           (type "vfat")) %base-file-systems)))
                   #:nvidia-module (and enable-nvidia?
                                         (make-nvidia-module-cachyos
                                          kernel-cachyos
                                          #:version nvidia-version))
                  #:version nvidia-version)
