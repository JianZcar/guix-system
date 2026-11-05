;; Indicate which modules to import to access the variables
;; used in this configuration.
(use-modules (gnu)
             (guix utils)
             (guix packages)
             (guix channels)
             (gnu packages gl)
             (gnu services pm)
             (gnu packages ssh)
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
             (gnu system accounts)
             (gnu services desktop)
             (gnu packages terminals)
             (gnu services containers)
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

(define mango-session-script
  (local-file "./script/mango-session"))

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

                                            (service '(noctalia)
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
                                                     #:respawn-limit '(5 . 30)
                                                     #:requirement '(pipewire
                                                                     wireplumber
                                                                     pipewire-pulse))))

                   (start-in-the-background '(ssh-agent foot-server pipewire
                                                        wireplumber
                                                        pipewire-pulse
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
  (local-file "./config/autostart/desktop-shepherd.desktop"))

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
                       (string-append "Exec="
                                      #$mango-session)))))))))))))

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
    "cryptsetup"
    "dbus"
    "glib:bin"
    "ncurses"
    "curl"
    "jq"
    "git"
    "git-lfs"
    "openssh"
    "btop"

    ;; Graphics, GPU and video
    "libva-utils"
    "vulkan-tools"
    "intel-media-driver"

    ;; Audio
    "pipewire"
    "wireplumber"
    "alsa-lib"
    "alsa-utils"
    "alsa-plugins"
    "libcanberra"

    ;; Containers
    "podman"

    ;; Python and machine learning
    "python"
    "python-numpy"
    "python-pillow"
    "onnxruntime:python"

    ;; XDG and desktop integration
    "xdg-utils"
    "xdg-user-dirs"
    "xdg-desktop-portal"
    "xdg-desktop-portal-gtk"
    "xdg-desktop-portal-wlr"
    "gvfs"
    "dex"
    "flatpak"
    "gnome-software"

    ;; Wayland utilities
    "wlr-randr"
    "wdisplays"
    "wl-mirror"
    "wl-clipboard"

    ;; Desktop environment
    "noctalia-git"
    "xfconf"
    "foot"
    "playerctl"

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

    ;; Internationalization
    "glibc-locales"

    ;; File manager and thumbnails
    "tumbler"
    "thunar-volman"

    ;; Browser
    "icecat"

    ;; Editors
    "neovim"
    "emacs"))

(define user-jian
  (user-account
    (name "jian")
    (comment "Jian Zcar")
    (group "users")
    (home-directory "/home/jian")
    (supplementary-groups '("wheel" "netdev" "audio" "video"))))

(define podman-subids
  (map (lambda (user)
         (subid-range (name user)))
       '("jian")))

(define firewall-rules
  (plain-file "nftables.conf"
              "
flush ruleset

table inet filter {
  chain input {
    type filter hook input priority filter;
    policy drop;

    # Allow loopback
    iifname \"lo\" accept

    # Allow established connections and replies
    ct state established,related accept

    # Allow IPv6 neighbor discovery and router advertisements
    meta l4proto ipv6-icmp accept

    # Allow ping
    ip protocol icmp accept
  }

  chain forward {
    type filter hook forward priority filter;
    policy drop;
  }

  chain output {
    type filter hook output priority filter;
    policy accept;
  }
}
"))

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

                (service nftables-service-type
                         (nftables-configuration (ruleset firewall-rules)))

                (service ntp-service-type)
                (service cups-service-type)

                ;; Sound
                (service rtkit-service-type)
                (simple-service 'asound-conf etc-service-type
                                (list `("asound.conf" ,asound-conf)))

                (service rootless-podman-service-type
                         (rootless-podman-configuration (subuids podman-subids)
                                                        (subgids podman-subids)))

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

                (simple-service 'mango-base-config etc-service-type
                                (list `("xdg/mango/base.conf" ,mango-base-config)))
                (simple-service 'mango-config etc-service-type
                                (list `("xdg/mango/config.conf" ,mango-config)))
                (simple-service 'desktop-shepherd etc-service-type
                                (list `("xdg/desktop-shepherd" ,desktop-shepherd)
                                      `("xdg/autostart/desktop-shepherd.desktop" ,desktop-shepherd-autostart)))
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
                    (host-name "rena")

                    ;; The list of user accounts ('root' is implicit).
                    (users (cons* user-jian %base-user-accounts))
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
                                                     "b4a9f8bc-2b2e-46ac-a8ff-0c50cb88efe3"))
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
