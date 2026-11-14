;; Indicate which modules to import to access the variables
;; used in this configuration.
(add-to-load-path (dirname (current-filename)))

(use-modules (guix gexp)
             (guix packages)
             (gnu)
             (gnu packages linux)
             (gnu system privilege)
             (nongnu packages linux)
             (modules desktop)
             (modules packages)
             (modules services)
             (modules system)
             (modules users))

(nvidia-transform (operating-system
                    (locale "en_PH.utf8")
                    (timezone "Asia/Manila")
                    (keyboard-layout (keyboard-layout "us"))
                    (host-name system-hostname)

                    ;; The list of user accounts ('root' is implicit).
                    (users (cons* user-jian %base-user-accounts))
                    (kernel linux)
                    (kernel-loadable-modules (list v4l2loopback-linux-module))
                    (firmware (cons* linux-firmware %base-firmware))
                    (packages (append (list mangowm-patch thunar-patch
                                            btop-patch desktop-session-tools)
                                      (specifications->packages packages-list)
                                      %base-packages))

                    (privileged-programs (cons (privileged-program
                                                 (program (file-append
                                                           btop-patch
                                                           "/bin/btop"))
                                                 (capabilities
                                                  "cap_perfmon=ep"))
                                               %default-privileged-programs))

                    ;; Below is the list of system services.  To search for available
                    ;; services, run 'guix system search KEYWORD' in a terminal.
                    (services
                     services-list)

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
                                            "compress=zstd:3,space_cache=v2,commit=120")
                                           (dependencies mapped-devices))
                                          (file-system
                                            (mount-point "/boot/efi")
                                            (device (uuid "A604-A46D"
                                                          'fat32))
                                            (type "vfat")) %base-file-systems))))
