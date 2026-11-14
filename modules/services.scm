(define-module (modules services)
  #:use-module (guix utils)
  #:use-module (guix packages)
  #:use-module (guix channels)
  #:use-module (guix gexp)
  #:use-module (guix build-system trivial)
  #:use-module (gnu)
  #:use-module (gnu services pm)
  #:use-module (gnu services dbus)
  #:use-module (gnu services linux)
  #:use-module (gnu services desktop)
  #:use-module (gnu services containers)
  #:use-module (gnu services networking)
  #:use-module (gnu services virtualization)
  #:use-module (gnu system accounts)
  #:use-module (gnu system privilege)
  #:use-module (gnu packages ssh)
  #:use-module (gnu packages elf)
  #:use-module (gnu packages bash)
  #:use-module (gnu packages linux)
  #:use-module (gnu packages admin)
  #:use-module (gnu packages gnome)
  #:use-module (gnu services sysctl)
  #:use-module (gnu packages terminals)
  #:use-module (gnu packages freedesktop)
  #:use-module (gnu packages password-utils)
  #:use-module (nonguix)
  #:use-module (nongnu packages nvidia)
  #:use-module (rosenthal services networking)
  #:use-module (midnight services noctalia-greeter)
  #:use-module (modules desktop)
  #:use-module (modules files)
  #:use-module (modules system)
  #:use-module (modules users)
  #:export (services-list))

(define services-list
  (append (list ;Use substitutes from Nonguix.
                (simple-service 'substitute-servers guix-service-type
                                (guix-extension (substitute-urls (list
                                                                  "https://substitutes.nonguix.org"))
                                                (authorized-keys (list
                                                                  nonguix-signing-key))))
                ;; Use substitutes from Guix Moe
                (simple-service 'guix-moe guix-service-type
                                (guix-extension (substitute-urls '("https://cache-cdn.guix.moe"))
                                                (authorized-keys (list
                                                                  nonguix-signing-key))))

                (service thermald-service-type)

                (service zram-device-service-type
                         (zram-device-configuration (size "64G")
                                                    (compression-algorithm 'lz4)
                                                    (priority 100)))

                (simple-service 'zram-sysctl sysctl-service-type
                                '(("vm.swappiness" . "180")
                                  ("vm.watermark_boost_factor" . "0")
                                  ("vm.watermark_scale_factor" . "125")
                                  ("vm.page-cluster" . "0")))

                (service earlyoom-service-type
                         (earlyoom-configuration (minimum-available-memory 10)
                                                 (minimum-free-swap 10)
                                                 (avoid-regexp
                                                  "mango|pipewire|wireplumber|noctalia|dbus-daemon|elogind|shepherd|Xwayland")))

                (service fstrim-service-type)
                (service polkit-service-type
                         (polkit-configuration (actions (list
                                                         networkmanager-polkit-rules
                                                         keepassxc gamemode))))
                (service elogind-service-type)

                (service upower-service-type)
                (service power-profiles-daemon-service-type)

                (service udisks-service-type)

                (service bluetooth-service-type
                         (bluetooth-configuration (name system-hostname)))

                ;; Networking
                (service wpa-supplicant-service-type)
                (service network-manager-service-type)
                (service tailscale-service-type)

                (service nftables-service-type
                         (nftables-configuration (ruleset firewall-rules)))

                (service ntp-service-type)

                (service kernel-module-loader-service-type
                         '("v4l2loopback"))

                (simple-service 'obs-virtual-camera-config etc-service-type
                                (list `("modprobe.d/v4l2loopback.conf" ,obs-virtual-camera-conf)))

                ;; Sound
                (service rtkit-service-type)
                (simple-service 'asound-conf etc-service-type
                                (list `("asound.conf" ,asound-conf)))

                (service rootless-podman-service-type
                         (rootless-podman-configuration (subuids podman-subids)
                                                        (subgids podman-subids)))
                (service libvirt-service-type
                         (libvirt-configuration (unix-sock-group "libvirt")))

                (service virtlog-service-type)

                (service noctalia-greeter-service-type
                         (noctalia-greeter-configuration (cursor (noctalia-greeter-cursor-configuration
                                                                  (theme
                                                                   "Adwaita")

                                                                  (size 24)))
                                                         (config-file (list
                                                                       greeter-conf))
                                                         (passwordless-sync-users '
                                                          ("jian"))))
                (service greetd-service-type
                         (greetd-configuration (greeter-supplementary-groups '
                                                                             ("video"
                                                                              "input"))
                                               (terminals (cons (greetd-terminal-configuration
                                                                 (extra-shepherd-requirement '
                                                                  (elogind))
                                                                 (terminal-vt
                                                                  "1")
                                                                 (terminal-switch
                                                                  #t)
                                                                 (default-session-command
                                                                  (greetd-noctalia-greeter-session)))
                                                                (map (lambda (vt)
                                                                       (greetd-terminal-configuration
                                                                        (terminal-vt
                                                                         (number->string
                                                                          vt))))
                                                                     '(2 3 4 5
                                                                       6))))))

                (simple-service 'mango-base-config etc-service-type
                                (list `("xdg/mango/base.conf" ,mango-base-config)))
                (simple-service 'mango-config etc-service-type
                                (list `("xdg/mango/config.conf" ,mango-config)))
                (simple-service 'desktop-shepherd etc-service-type
                                (list `("xdg/autostart/desktop-shepherd.desktop" ,desktop-shepherd-autostart)))
                (simple-service 'noctalia-config etc-service-type
                                (list `("xdg/noctalia/config.toml" ,noctalia-config)))
                (simple-service 'foot-config etc-service-type
                                (list `("xdg/foot/foot.ini" ,foot-config)))
                (simple-service 'dconf-configuration etc-service-type
                                (list `("dconf/profile/user" ,dconf-profile)
                                      `("dconf/db/local" ,dconf-local-db)))
                (simple-service 'dconf-update activation-service-type
                                #~(invoke #$(file-append dconf "/bin/dconf")
                                          "update"))
                (simple-service 'thunar-config etc-service-type
                                (list `("xdg/xfce4/xfconf/xfce-perchannel-xml/thunar.xml" ,thunar-config))))

          ;; This is the default list of services we
          ;; are appending to.
          (modify-services %base-services
            (delete mingetty-service-type))))
