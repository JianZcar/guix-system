;; Indicate which modules to import to access the variables
;; used in this configuration.
(use-modules (gnu)
             (guix utils)
             (guix packages)
             (guix channels)
             (gnu packages gl)
             (gnu services pm)
             (gnu services ssh)
             (gnu packages bash)
             (gnu packages curl)
             (gnu services dbus)
             (gnu services cups)
             (gnu services xorg)
             (gnu packages linux)
             (gnu services linux)
             (gnu services audio)
             (gnu services sound)
             (gnu packages gnome)
             (gnu services desktop)
             (gnu services networking)
             (nonguix)
             (nongnu packages nvidia)
             (nonguix transformations)
             (midnight services noctalia-greeter))

(define nonguix-signing-key
  (plain-file "nonguix.pub"
   "(public-key (ecc (curve Ed25519) (q #C1FD53E5D4CE971933EC50C9F307AE2171A2D3B52C804642A7A35F84F3A4EA98#)))"))

(define nvidia-transform
  (nonguix-transformation-nvidia #:driver nvda-595
                                 #:open-source-kernel-module? #t
                                 #:kernel-mode-setting? #t
                                 #:dynamic-boost? #t))

(define audio-session
  (local-file "./config/autostart/audio-session.desktop"))

(define asound-conf
  (mixed-text-file "asound.conf"
                   "pcm_type.pipewire {\n"
                   "  lib \""
                   (file-append pipewire
                    "/lib/alsa-lib/libasound_module_pcm_pipewire.so")
                   "\"\n"
                   "}\n"
                   "ctl_type.pipewire {\n"
                   "  lib \""
                   (file-append pipewire
                    "/lib/alsa-lib/libasound_module_ctl_pipewire.so")
                   "\"\n"
                   "}\n"
                   "pcm.!default { type pipewire }\n"
                   "ctl.!default { type pipewire }\n"))

(define greeter-conf
  (local-file "./config/greetd/greeter.toml"))

(define mangowm-script
  (local-file "./script/run-mangowm"))

(define run-mangowm
  (program-file "run-mangowm"
                #~(let ((status (system* #$(file-append bash "/bin/bash")
                                         #$mangowm-script)))
                    (primitive-exit status))))

(define mangowm-patch
  (package
    (inherit (@ (gnu packages window-management) mangowm))
    (name "mangowm-patch")
    (arguments
     (substitute-keyword-arguments (package-arguments (@ (gnu packages
                                                          window-management)
                                                         mangowm))
       ((#:phases phases
         #~%standard-phases)
        #~(modify-phases #$phases
            (add-after 'install 'patch-mango-desktop
              (lambda* (#:key outputs #:allow-other-keys)
                (let ((desktop (string-append (assoc-ref outputs "out")
                                "/share/wayland-sessions/mango.desktop")))
                  (when (file-exists? desktop)
                    (substitute* desktop
                      (("Exec=mango")
                       (string-append "Exec="
                                      #$run-mangowm)))))))))))))

(define mangowm-config
  (local-file "./config/mango/config.conf"))

(define noctalia-session
  (local-file "./config/autostart/noctalia-session.desktop"))

(define dconf-profile
  (local-file "./config/dconf/user"))

(define theme
  (local-file "./config/dconf/00-theme"))

(define dconf-local-db
  (computed-file "dconf-local-db"
                 (with-imported-modules '((guix build utils))
                                        #~(begin
                                            (use-modules (guix build utils))
                                            (mkdir-p "keyfiles/local.d")
                                            (copy-file #$theme
                                             "keyfiles/local.d/00-theme")
                                            (invoke #$(file-append dconf
                                                       "/bin/dconf") "compile"
                                                    #$output
                                                    "keyfiles/local.d")))))

(define thunar-patch
  (package
    (inherit (@ (gnu packages xfce) thunar))
    (name "thunar-patch")
    (arguments
     (substitute-keyword-arguments (package-arguments (@ (gnu packages xfce)
                                                         thunar))
       ((#:phases phases
         #~%standard-phases)
        #~(modify-phases #$phases
            (add-after 'install 'patch-thunar-uca
              (lambda* (#:key outputs #:allow-other-keys)
                (let ((uca (string-append (assoc-ref outputs "out")
                                          "/etc/xdg/Thunar/uca.xml")))
                  (when (file-exists? uca)
                    (substitute* uca
                      (("exo-open --working-directory %f --launch TerminalEmulator")
                       "xterm"))))))))))))

(define thunar-config
  (local-file "./config/thunar/thunar.xml"))

(define packages-list
  '("acpi" "dbus"
    "cryptsetup"
    "dex"
    "pipewire"
    "wireplumber"
    "alsa-lib"
    "alsa-utils"
    "alsa-plugins"
    "xdg-utils"
    "xdg-user-dirs"
    "xdg-desktop-portal"
    "xdg-desktop-portal-gtk"
    "glib:bin"
    "gvfs"
    "mangowm"
    "noctalia-shell"
    "playerctl"
    "fontconfig"
    "yaru-theme"
    "adw-gtk3-theme"
    "adwaita-icon-theme"
    "papirus-icon-theme"
    "font-adwaita"
    "font-nerd-jetbrains-mono"
    "font-nerd-symbols"
    "wl-clipboard"
    "flatpak"
    "ncurses"
    "curl"
    "git"
    "btop"
    "neovim"
    "emacs"
    "foot"
    "xfconf"
    "icecat"
    "nwg-look"
    "gnome-software"))

(define services-list
  (append (list (service polkit-service-type)
                (service elogind-service-type)

                (service upower-service-type)
                (service power-profiles-daemon-service-type)

                (service udisks-service-type)
                (service zram-device-service-type
                         (zram-device-configuration (size "12G")
                                                    (compression-algorithm 'zstd)
                                                    (priority 100)))

                (service bluetooth-service-type)

                ;; Networking
                (service wpa-supplicant-service-type)
                (service network-manager-service-type)
                (simple-service 'resolv-conf etc-service-type
                                (list `("resolv.conf" ,(plain-file
                                                        "resolv.conf"
                                                        "nameserver 1.1.1.1\nnameserver 8.8.8.8\n"))))

                ;; To configure OpenSSH, pass an 'openssh-configuration'
                ;; record as a second argument to 'service' below.
                (service openssh-service-type)
                (service tor-service-type)

                (service ntp-service-type)
                (service cups-service-type)

                ;; Sound
                (service rtkit-service-type)
                (simple-service 'asound-conf etc-service-type
                                (list `("asound.conf" ,asound-conf)))
                (simple-service 'audio-session etc-service-type
                                (list `("xdg/autostart/audio-session.desktop" ,audio-session)))

                ;; Use substitutes from Nonguix.
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

                (simple-service 'mangowm-config etc-service-type
                                (list `("xdg/mango/config.conf" ,mangowm-config)))
                (simple-service 'noctalia-session etc-service-type
                                (list `("xdg/autostart/noctalia-session.desktop" ,noctalia-session)))
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

(nvidia-transform (operating-system
                    (locale "en_PH.utf8")
                    (timezone "Asia/Manila")
                    (keyboard-layout (keyboard-layout "us"))
                    (host-name "rena")

                    ;; The list of user accounts ('root' is implicit).
                    (users (cons* (user-account
                                    (name "jian")
                                    (comment "Jian Zcar")
                                    (group "users")
                                    (home-directory "/home/jian")
                                    (supplementary-groups '("wheel" "netdev"
                                                            "audio" "video")))
                                  %base-user-accounts))
                    (kernel linux)
                    (firmware (cons* linux-firmware %base-firmware))
                    (packages (append (list mangowm-patch thunar-patch)
                                      (specifications->packages packages-list)
                                      %base-packages))

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
                                                     "b34ddaca-8a19-425a-9661-83e387300a18"))
                                            (target "cryptroot")
                                            (type luks-device-mapping))))

                    ;; The list of file systems that get "mounted".  The unique
                    ;; file system identifiers there ("UUIDs") can be obtained
                    ;; by running 'blkid' in a terminal.
                    (file-systems (cons* (file-system
                                           (mount-point "/")
                                           (device "/dev/mapper/cryptroot")
                                           (type "btrfs")
                                           (dependencies mapped-devices))
                                         (file-system
                                           (mount-point "/boot/efi")
                                           (device (uuid "2AA5-39A9"
                                                         'fat32))
                                           (type "vfat")) %base-file-systems))))
