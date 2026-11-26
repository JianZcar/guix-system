(define-module (modules nvidia)
  #:use-module (guix gexp)
  #:use-module (guix packages)
  #:use-module (gnu services)
  #:use-module (gnu system)
  #:use-module (nonguix transformations)
  #:use-module (nongnu packages nvidia)
  #:use-module (nongnu services nvidia)
  #:export (nvidia-package nvidia-transform))

(define (nvidia-package prefix version)
  (module-ref (resolve-module '(nongnu packages nvidia))
              (string->symbol (string-append prefix "-" version))))

(define* (nvidia-transform enable-nvidia? os
                           #:key nvidia-module version)
  (if enable-nvidia?
      (let ((transformed ((nonguix-transformation-nvidia #:driver (nvidia-package
                                                                   "nvda"
                                                                   version)
                                                         #:open-source-kernel-module?
                                                         #t
                                                         #:kernel-mode-setting?
                                                         #t
                                                         #:dynamic-boost? #t)
                          os)))
        (operating-system
          (inherit transformed)
          (services
           (modify-services (operating-system-user-services transformed)
             (nvidia-service-type config =>
                                  (nvidia-configuration (inherit config)
                                                        (module nvidia-module)))))))
      os))
