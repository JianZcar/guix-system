(define-module (modules system)
  #:use-module (guix gexp)
  #:use-module (nonguix transformations)
  #:use-module (nongnu packages nvidia)
  #:export (system-hostname
            nonguix-signing-key
            nvidia-transform))

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
