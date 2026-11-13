(define-module (modules users)
  #:use-module (gnu system accounts)
  #:export (user-jian podman-subids))

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
