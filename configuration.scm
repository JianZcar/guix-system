;; Indicate which modules to import to access the variables
;; used in this configuration.
(use-modules (guix utils)
             (guix packages)
             (guix channels)
             (gnu)
             (gnu services pm)
             (gnu packages ssh)
             (gnu packages elf)
             (gnu services dbus)
             (gnu packages bash)
             (gnu packages linux)
             (gnu services linux)
             (gnu packages admin)
             (gnu packages gnome)
             (gnu system accounts)
             (gnu system privilege)
             (gnu services desktop)
             (gnu packages terminals)
             (gnu services containers)
             (gnu services networking)
             (gnu packages freedesktop)
             (gnu packages password-utils)
             (gnu services virtualization)
             (nonguix)
             (nongnu packages nvidia)
             (nonguix transformations)
             (rosenthal services networking)
             (midnight services noctalia-greeter))

(define system-hostname
  "zena")

(define nonguix-signing-key
  (plain-file "nonguix.pub"
   "(public-key (ecc (curve Ed25519) (q #C1FD53E5D4CE971933EC50C9F307AE2171A2D3B52C804642A7A35F84F3A4EA98#)))"))

(define nvidia-transform
  (nonguix-transformation-nvidia #:driver nvda-595
                                 #:open-source-kernel-module? #t
                                 #:kernel-mode-setting? #t
                                 #:dynamic-boost? #t))

;; Compatibility for using nvidia inside distrobox
;; Mount volume /gnu:/gnu:ro for it to work
(define nvidia-compatibility
  #~(begin
      (use-modules (guix build utils)
                   (ice-9 ftw)
                   (ice-9 exceptions)
                   (srfi srfi-13))

      (let* ((driver #$nvda-595)
             (driver-libdir (string-append driver "/lib"))
             (driver-share (string-append driver "/share"))

             (egl-dir "/usr/share/glvnd/egl_vendor.d")
             (egl-platform-dir "/usr/share/egl/egl_external_platform.d")
             (vulkan-dir "/usr/share/vulkan/icd.d")
             (vulkan-layer-dir "/usr/share/vulkan/implicit_layer.d"))
        
        ;; Replace existing files and symlinks safely.
        (define (install-link source target)
          (unless (file-exists? source)
            (error "Source file does not exist" source))

          (let ((existing (false-if-exception (lstat target))))
            (when existing
              (when (eq? 'directory
                         (stat:type existing))
                (error "Refusing to overwrite directory" target))
              (delete-file target)))

          (symlink source target))

        ;; Create destination directories.
        (for-each mkdir-p
                  (list "/usr/lib64" egl-dir egl-platform-dir vulkan-dir
                        vulkan-layer-dir))

        ;; NVIDIA shared libraries.
        ;; Absolute source paths resolve through /gnu/store.
        (for-each (lambda (name)
                    (install-link (string-append driver-libdir "/" name)
                                  (string-append "/usr/lib64/" name)))
                  (scandir driver-libdir
                           (lambda (name)
                             (string-contains name ".so"))))

        ;; EGL vendor configuration.
        (install-link (string-append driver-share
                       "/glvnd/egl_vendor.d/10_nvidia.x86_64.json")
                      (string-append egl-dir "/10_nvidia.x86_64.json"))

        ;; EGL external platform configuration.
        (let ((source-dir (string-append driver-share
                                         "/egl/egl_external_platform.d")))
          
          (when (file-exists? source-dir)
            (for-each (lambda (name)
                        (install-link (string-append source-dir "/" name)
                                      (string-append egl-platform-dir "/" name)))
                      (scandir source-dir
                               (lambda (name)
                                 (string-suffix? ".json" name))))))

        ;; Vulkan ICD.
        (install-link (string-append driver-share
                                     "/vulkan/icd.d/nvidia_icd.x86_64.json")
                      (string-append vulkan-dir "/nvidia_icd.x86_64.json"))

        ;; Vulkan implicit layer.
        (install-link (string-append driver-share
                       "/vulkan/implicit_layer.d/nvidia_layers.x86_64.json")
                      (string-append vulkan-layer-dir
                                     "/nvidia_layers.x86_64.json")))))

(define btop-patch
  (package
    (inherit btop)
    (name "btop-patch")

    ;; patchelf is needed during the build.
    (native-inputs (modify-inputs (package-native-inputs btop)
                     (append patchelf)))

    (arguments
     (substitute-keyword-arguments (package-arguments btop)
       ((#:phases phases
         #~%standard-phases)
        #~(modify-phases #$phases
            (add-after 'install 'add-nvidia-runpath
              (lambda* (#:key outputs #:allow-other-keys)
                (let ((binary (string-append (assoc-ref outputs "out")
                                             "/bin/btop")))
                  (invoke "patchelf" "--add-rpath"
                          (string-append #$nvda-595 "/lib") binary))))))))))

; fix for no generated resolv.conf
; sudo rm /etc/resolv.conf
; sudo nmcli general reload dns-rc
(define networkmanager-polkit-rules
  (file-union "networkmanager-polkit-rules"
              `(("share/polkit-1/rules.d/10-networkmanager.rules" ,(local-file
                                                                    "./config/polkit/10-networkmanager.rules")))))
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

(define obs-virtual-camera-conf
  (plain-file "v4l2loopback.conf"
   "options v4l2loopback devices=1 video_nr=10 card_label=\"OBS Virtual Camera\" exclusive_caps=1
"))

(define greeter-conf
  (local-file "./config/greetd/greeter.toml"))

(define mango-session-script
  (local-file "./script/mango-session"))

(define xdg-desktop-portal-wlr-patch
  (package
    (inherit xdg-desktop-portal-wlr)
    (name "xdg-desktop-portal-wlr-patch")
    (arguments
     (substitute-keyword-arguments (package-arguments xdg-desktop-portal-wlr)
       ((#:phases phases
         #~%standard-phases)
        #~(modify-phases #$phases
            (add-after 'install 'patch-wlr-portal
              (lambda* (#:key outputs #:allow-other-keys)
                (let ((portal (string-append (assoc-ref outputs "out")
                               "/share/xdg-desktop-portal/portals/wlr.portal")))
                  (substitute* portal
                    (("UseIn=(.*)" all desktops)
                     (string-append all ";mango"))))))))))))

(define desktop-shepherd-conf
  (scheme-file "desktop-shepherd.scm"
               #~(begin
                   (use-modules (shepherd service))

                   (define (log-file name)
                     (string-append (or (getenv "XDG_STATE_HOME")
                                        (string-append (getenv "HOME")
                                                       "/.local/state"))
                                    "/desktop-shepherd/" name ".log"))

                   (register-services (list (service '(ssh-agent)
                                                     #:start (make-forkexec-constructor
                                                              (list #$(file-append
                                                                       openssh
                                                                       "/bin/ssh-agent")
                                                                    "-D" "-a"
                                                                    (getenv
                                                                     "SSH_AUTH_SOCK"))
                                                              #:log-file (log-file
                                                                          "ssh-agent"))
                                                     #:stop (make-kill-destructor)
                                                     #:respawn? #t
                                                     #:respawn-delay 1
                                                     #:respawn-limit '(5 . 30))

                                            (service '(foot-server)
                                                     #:start (make-forkexec-constructor
                                                              (list #$(file-append
                                                                       foot
                                                                       "/bin/foot")
                                                               "--server")
                                                              #:log-file (log-file
                                                                          "foot-server"))
                                                     #:stop (make-kill-destructor)
                                                     #:respawn? #t
                                                     #:respawn-delay 1
                                                     #:respawn-limit '(5 . 30))

                                            (service '(pipewire)
                                                     #:start (make-forkexec-constructor
                                                              (list #$(file-append
                                                                       pipewire
                                                                       "/bin/pipewire"))
                                                              #:log-file (log-file
                                                                          "pipewire"))
                                                     #:stop (make-kill-destructor)
                                                     #:respawn? #t
                                                     #:respawn-delay 1
                                                     #:respawn-limit '(5 . 30))

                                            (service '(wireplumber)
                                                     #:requirement '(pipewire)
                                                     #:start (make-forkexec-constructor
                                                              (list #$(file-append
                                                                       wireplumber
                                                                       "/bin/wireplumber"))
                                                              #:log-file (log-file
                                                                          "wireplumber"))
                                                     #:stop (make-kill-destructor)
                                                     #:respawn? #t
                                                     #:respawn-delay 1
                                                     #:respawn-limit '(5 . 30))

                                            (service '(pipewire-pulse)
                                                     #:requirement '(pipewire)
                                                     #:start (make-forkexec-constructor
                                                              (list #$(file-append
                                                                       pipewire
                                                                       "/bin/pipewire-pulse"))
                                                              #:log-file (log-file
                                                                          "pipewire-pulse"))
                                                     #:stop (make-kill-destructor)
                                                     #:respawn? #t
                                                     #:respawn-delay 1
                                                     #:respawn-limit '(5 . 30))

                                            (service '(xdg-desktop-portal-wlr)
                                                     #:requirement '(pipewire)
                                                     #:start (make-forkexec-constructor
                                                              (list #$(file-append
                                                                       xdg-desktop-portal-wlr
                                                                       "/libexec/xdg-desktop-portal-wlr"))
                                                              #:log-file (log-file
                                                                          "xdg-desktop-portal-wlr"))
                                                     #:stop (make-kill-destructor)
                                                     #:respawn? #t
                                                     #:respawn-delay 1
                                                     #:respawn-limit '(5 . 30))

                                            ;; workaround fix for screencapture
                                            (service '(restart-xdg-desktop-portal)
                                                     #:requirement '(xdg-desktop-portal-wlr)
                                                     #:start (make-forkexec-constructor
                                                              (list #$(file-append
                                                                       bash
                                                                       "/bin/bash")
                                                                    "-c"
                                                                    (string-append
                                                                     "sleep 1; "
                                                                     "pkill -f '^"
                                                                     #$(file-append
                                                                        xdg-desktop-portal
                                                                        "/libexec/xdg-desktop-portal")
                                                                     "$' 2>/dev/null")))
                                                     #:stop (make-kill-destructor)
                                                     #:one-shot? #t
                                                     #:respawn? #f)

                                            (service '(noctalia)
                                                     #:requirement '(pipewire
                                                                     wireplumber
                                                                     pipewire-pulse)
                                                     #:start (make-forkexec-constructor
                                                              (list #$(file-append
                                                                       (@ (noctalia)
                                                                        noctalia-git)
                                                                       "/bin/noctalia"))
                                                              #:log-file (log-file
                                                                          "noctalia"))
                                                     #:stop (make-kill-destructor)
                                                     #:respawn? #t
                                                     #:respawn-delay 1
                                                     #:respawn-limit '(5 . 30))))

                   (start-in-the-background '(ssh-agent foot-server
                                              pipewire
                                              wireplumber
                                              pipewire-pulse
                                              xdg-desktop-portal-wlr
                                              restart-xdg-desktop-portal
                                              noctalia)))))

(define desktop-shepherd
  (program-file "desktop-shepherd"
                #~(begin
                    (let* ((runtime (or (getenv "XDG_RUNTIME_DIR")
                                        (string-append "/run/user/"
                                                       (number->string (getuid)))))
                           (state (or (getenv "XDG_STATE_HOME")
                                      (string-append (getenv "HOME")
                                                     "/.local/state")))
                           (socket (string-append runtime
                                                  "/desktop-shepherd.socket"))
                           (pidfile (string-append runtime
                                                   "/desktop-shepherd.pid"))
                           (logdir (string-append state "/desktop-shepherd")))
                      (system* #$(file-append (@ (gnu packages base) coreutils)
                                              "/bin/mkdir") "-p" logdir)
                      (false-if-exception (delete-file socket))
                      (false-if-exception (delete-file pidfile))
                      (execl #$(file-append (@ (gnu packages admin) shepherd)
                                            "/bin/shepherd")
                             "shepherd"
                             "--silent"
                             (string-append "--socket=" socket)
                             (string-append "--pid=" pidfile)
                             (string-append "--logfile=" logdir
                                            "/desktop-shepherd.log")
                             (string-append "--config="
                                            #$desktop-shepherd-conf))))))

(define desktop-shepherd-autostart
  (mixed-text-file "desktop-shepherd.desktop"
                   "[Desktop Entry]\n"
                   "Type=Application\n"
                   "Name=Desktop Shepherd\n"
                   "Exec="
                   (file-append desktop-shepherd)
                   "\n"
                   "Terminal=false\n"))

(define mango-session
  (program-file "mango-session"
                #~(let ((status (system* #$(file-append bash "/bin/bash")
                                         #$mango-session-script)))
                    (primitive-exit status))))

(define mangowm-patch
  (package
    (inherit (@ (mangowm) mangowm-git))
    (name "mangowm-patch")
    (arguments
     (substitute-keyword-arguments (package-arguments (@ (mangowm) mangowm-git))
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
                       (string-append "Exec=sh -c \"exec "
                                      #$mango-session " >/dev/null 2>&1\"")))))))))))))

(define mango-base-config
  (local-file "./config/mango/base.conf"))

(define mango-config
  (local-file "./config/mango/config.conf"))

(define noctalia-config
  (local-file "./config/noctalia/config.toml"))

(define foot-config
  (local-file "./config/foot/foot.ini"))

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
  '( ;System utilities
     "acpi"
    "bash"
    "curl"
    "dbus"
    "glib:bin"
    "jq"
    "ncurses"
    "btrfs-progs"
    "cryptsetup"
    "libsecret"
    "keepassxc"

    ;; Networking
    "openssh"
    "openvpn"
    "network-manager-openvpn"

    ;; Version control
    "git"
    "git-lfs"

    ;; Graphics and video
    "libva-utils"
    "vulkan-tools"
    "intel-media-driver"

    ;; Audio
    "alsa-lib"
    "alsa-utils"
    "alsa-plugins"
    "libcanberra"
    "pipewire"
    "wireplumber"
    "playerctl"

    ;; Containers & Virtualization
    "podman"
    "podman-compose"
    "distrobox"
    "qemu"
    "libvirt"
    "virt-manager"
    "virt-viewer"
    "dnsmasq"

    ;; Python and machine learning
    "python"
    "python-numpy"
    "python-pillow"
    "onnxruntime:python"

    ;; Desktop integration
    "gtk+"
    "gtk"
    "gsettings-desktop-schemas"
    "xdg-utils"
    "xdg-user-dirs"
    "xdg-desktop-portal"
    "xdg-desktop-portal-gtk"
    "xdg-desktop-portal-wlr"
    "gvfs"
    "dex"
    "flatpak"
    "gnome-software"

    ;; Wayland
    "wlr-randr"
    "wdisplays"
    "wl-mirror"
    "wl-clipboard"

    ;; Desktop environment
    "noctalia-git"
    "xfconf"
    "foot"

    ;; Themes and icons
    "yaru-theme"
    "adw-gtk3-theme"
    "adwaita-icon-theme"
    "papirus-icon-theme"

    ;; Fonts
    "fontconfig"
    "font-adwaita"
    "font-dejavu"
    "font-gnu-unifont"
    "font-nerd-jetbrains-mono"
    "font-nerd-symbols"
    "font-google-noto-sans-cjk"
    "font-google-noto-serif-cjk"
    "font-google-noto-emoji"
    "font-adobe-source-han-sans"

    ;; Localization
    "glibc-locales"

    ;; File manager
    "tumbler"
    "thunar-volman"

    ;; Editors
    "neovim"
    "emacs"

    ;; Desktop apps
    "loupe"
    "vlc"
    "snapshot"
    "decibels"
    "gnome-calculator"
    "ungoogled-chromium"
    "obs-nvidia"
    "obs-wlrobs"
    "v4l-utils"
    "fuzzel"

    ;; Gaming
    "mangohud"
    "gamemode"
    "cartridges"
    "steam-nvidia"
    "heroic-nvidia"
    "protonup"))

(define user-jian
  (user-account
    (name "jian")
    (comment "Jian Zcar")
    (group "users")
    (home-directory "/home/jian")
    (supplementary-groups '("wheel" "netdev" "audio" "video" "kvm" "libvirt"))))

(define podman-subids
  (map (lambda (user)
         (subid-range (name user)))
       '("jian")))

(define firewall-rules
  (local-file "./config/firewall/nftables.conf"))

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

                (simple-service 'nvidia-compatibility activation-service-type
                                nvidia-compatibility)

                (service zram-device-service-type
                         (zram-device-configuration (size "64G")
                                                    (compression-algorithm 'zstd)
                                                    (priority 100)))

                (service earlyoom-service-type
                         (earlyoom-configuration (minimum-available-memory 10)
                                                 (minimum-free-swap 10)
                                                 (avoid-regexp
                                                  "mango|pipewire|wireplumber|noctalia")))

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
                    (packages (append (list mangowm-patch thunar-patch)
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
                                            "compress=zstd:3,space_cache=v2")
                                           (dependencies mapped-devices))
                                         (file-system
                                           (mount-point "/boot/efi")
                                           (device (uuid "A604-A46D"
                                                         'fat32))
                                           (type "vfat")) %base-file-systems))))
