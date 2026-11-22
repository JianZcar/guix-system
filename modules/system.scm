(define-module (modules system)
  #:use-module (guix gexp)
  #:use-module (guix packages)
  #:use-module (gnu services)
  #:use-module (gnu system)
  #:use-module (nonguix transformations)
  #:use-module (nongnu packages nvidia)
  #:use-module (nongnu services nvidia)
  #:use-module (modules kernel)
  #:export (system-hostname nonguix-signing-key nvidia-transform))

(define system-hostname
  "zena")

(define nonguix-signing-key
  (plain-file "nonguix.pub"
   "(public-key (ecc (curve Ed25519) (q #C1FD53E5D4CE971933EC50C9F307AE2171A2D3B52C804642A7A35F84F3A4EA98#)))"))

(define base-nvidia-transform
  (nonguix-transformation-nvidia #:driver nvda-580
                                 #:open-source-kernel-module? #f
                                 #:kernel-mode-setting? #t
                                 #:dynamic-boost? #t))

(define (nvidia-transform os)
  (let ((transformed (base-nvidia-transform os)))
    (operating-system
      (inherit transformed)
      (services
       (modify-services (operating-system-user-services transformed)
         (nvidia-service-type config =>
                              (nvidia-configuration (inherit config)
                                                    (module
                                                     nvidia-module-580-cachyos))))))))
