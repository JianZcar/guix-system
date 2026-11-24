(define-module (modules users)
  #:use-module (gnu system accounts)
  #:export (user-accounts podman-subids passwordless-sync-users))

(define user-accounts
  (list (user-account
          (name "jian")
          (comment "Jian Zcar")
          (group "users")
          (home-directory "/home/jian")
          (supplementary-groups '("wheel" "netdev"
                                  "input"
                                  "audio"
                                  "video"
                                  "i2c"
                                  "kvm"
                                  "libvirt")))))

(define passwordless-sync-users
  (map user-account-name user-accounts))

(define podman-subids
  (map (lambda (user)
         (subid-range (name (user-account-name user)))) user-accounts))
