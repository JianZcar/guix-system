(define-module (modules files)
  #:use-module (guix gexp)
  #:use-module (gnu packages linux)
  #:use-module (gnu packages gnome)
  #:export (networkmanager-polkit-rules asound-conf
                                        obs-virtual-camera-conf
                                        greeter-conf
                                        mango-base-config
                                        mango-config
                                        noctalia-config
                                        foot-config
                                        dconf-profile
                                        theme
                                        dconf-local-db
                                        thunar-config
                                        firewall-rules))

; fix for no generated resolv.conf
; sudo rm /etc/resolv.conf
; sudo nmcli general reload dns-rc
(define networkmanager-polkit-rules
  (file-union "networkmanager-polkit-rules"
              `(("share/polkit-1/rules.d/10-networkmanager.rules" ,(local-file
                                                                    "../configs/polkit/10-networkmanager.rules")))))
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
  (local-file "../configs/greetd/greeter.toml"))

(define mango-base-config
  (local-file "../configs/mango/base.conf"))

(define mango-config
  (local-file "../configs/mango/config.conf"))

(define noctalia-config
  (local-file "../configs/noctalia/config.toml"))

(define foot-config
  (local-file "../configs/foot/foot.ini"))

(define dconf-profile
  (local-file "../configs/dconf/user"))

(define theme
  (local-file "../configs/dconf/00-theme"))

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

(define thunar-config
  (local-file "../configs/thunar/thunar.xml"))

(define firewall-rules
  (local-file "../configs/firewall/nftables.conf"))
