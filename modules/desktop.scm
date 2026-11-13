(define-module (modules desktop)
  #:use-module (guix gexp)
  #:use-module (guix packages)
  #:use-module (guix utils)
  #:use-module (guix build-system trivial)
  #:use-module (gnu packages admin)
  #:use-module (gnu packages bash)
  #:use-module (gnu packages freedesktop)
  #:use-module (gnu packages linux)
  #:use-module (gnu packages ssh)
  #:use-module (gnu packages terminals)
  #:export (mango-session mangowm-patch desktop-shepherd
                          desktop-shepherd-autostart desktop-session-tools
                          xdg-desktop-portal-wlr-patch))

(define mango-session-script
  (local-file "../scripts/mango-session"))

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

(define xterm-wrapper
  (program-file "xterm"
                #~(apply execl
                         #$(file-append foot "/bin/footclient") "footclient"
                         (cdr (command-line)))))

(define desktop-herd
  (program-file "desktop-herd"
                #~(let* ((runtime (or (getenv "XDG_RUNTIME_DIR")
                                      (string-append "/run/user/"
                                                     (number->string (getuid)))))
                         (socket (string-append runtime
                                                "/desktop-shepherd.socket"))
                         (herd #$(file-append shepherd "/bin/herd")))
                    (apply execl
                           herd
                           "herd"
                           "-s"
                           socket
                           (cdr (command-line))))))

(define nv-script
  (local-file "../scripts/nv"))

(define nv
  (program-file "nv"
                #~(let ((status (apply system*
                                       #$(file-append bash "/bin/bash")
                                       #$nv-script
                                       (cdr (command-line)))))
                    (primitive-exit status))))

(define game-run-script
  (local-file "../scripts/game-run"))

(define game-run
  (program-file "game-run"
                #~(let ((status (apply system*
                                       #$(file-append bash "/bin/bash")
                                       #$game-run-script
                                       (cdr (command-line)))))
                    (primitive-exit status))))

(define desktop-session-tools
  (package
    (name "desktop-session-tools")
    (version "1.0")
    (source
     #f)
    (build-system trivial-build-system)
    (arguments
     (list
      #:modules '((guix build utils))
      #:builder
      #~(begin
          (use-modules (guix build utils))

          (mkdir-p (string-append #$output "/bin"))

          (symlink #$xterm-wrapper
                   (string-append #$output "/bin/xterm"))

          (symlink #$desktop-herd
                   (string-append #$output "/bin/desktop-herd"))

          (symlink #$nv
                   (string-append #$output "/bin/nv"))

          (symlink #$game-run
                   (string-append #$output "/bin/game-run")))))

    (inputs (list foot shepherd))
    (synopsis "Desktop session integration utilities")
    (description "Provides helper utilities for improved desktop experience,
application integration, and session management.")
    (home-page "https://github.com/JianZcar/guix-system")
    (license #f)))

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
