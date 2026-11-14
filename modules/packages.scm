(define-module (modules packages)
  #:use-module (guix gexp)
  #:use-module (guix packages)
  #:use-module (guix utils)
  #:use-module (gnu packages admin)
  #:use-module (gnu packages elf)
  #:use-module (nongnu packages nvidia)
  #:export (thunar-patch btop-patch packages-list))

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

(define btop-patch
  (package
    (inherit btop)
    (name "btop-patch")
    (native-inputs (modify-inputs (package-native-inputs btop)
                     (append patchelf)))
    (arguments
     (substitute-keyword-arguments (package-arguments btop)
       ((#:phases phases
         #~%standard-phases)
        #~(modify-phases #$phases
            (add-after 'unpack 'patch-theme-dir
              (lambda* (#:key outputs #:allow-other-keys)
                (substitute* "src/btop.cpp"
                  (("\"\\.\\./share/btop/themes\"")
                   (string-append "\""
                                  (assoc-ref outputs "out")
                                  "/share/btop/themes\"")))))
            (add-after 'install 'add-nvidia-runpath
              (lambda* (#:key outputs #:allow-other-keys)
                (let ((binary (string-append (assoc-ref outputs "out")
                                             "/bin/btop")))
                  (invoke "patchelf" "--add-rpath"
                          (string-append #$nvda-595 "/lib") binary))))
            (add-after 'install 'patch-desktop-entry
              (lambda* (#:key outputs #:allow-other-keys)
                (let ((desktop (string-append (assoc-ref outputs "out")
                                "/share/applications/btop.desktop")))
                  (when (file-exists? desktop)
                    (substitute* desktop
                      (("Exec=btop")
                       "Exec=/run/privileged/bin/btop"))))))))))))

(define packages-list
  '( ;System utilities
     "acpi"
    "coreutils"
    "bash"
    "curl"
    "dbus"
    "glib:bin"
    "jq"
    "fzf"
    "ripgrep"
    "libcap"
    "ncurses"
    "btrfs-progs"
    "unzip"
    "unrar"
    "7zip"
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
