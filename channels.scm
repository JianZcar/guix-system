(list (channel
       (name 'guix)
       (url "https://git.guix.gnu.org/guix.git")
       (branch "master")
       (commit "fa73e816fdeadfc29c388b7892f7ce41028dd56e")
       (introduction
        (make-channel-introduction
         "9edb3f66fd807b096b48283debdcddccfea34bad"
         (openpgp-fingerprint
          "BBB0 2DDF 2CEA F6A8 0D1D  E643 A2A0 6DF2 A33A 54FA"))))
      (channel
       (name 'nonguix)
       (url "https://gitlab.com/nonguix/nonguix")
       (branch "master")
       (commit "c241d19ff840dc75556f722b231760d119b6adea")
       (introduction
        (make-channel-introduction
         "897c1a470da759236cc11798f4e0a5f7d4d59fbc"
         (openpgp-fingerprint
          "2A39 3FFF 68F4 EF7A 3D29  12AF 6F51 20A0 22FB B2D5"))))
      (channel
       (name 'midnight)
       (url "https://codeberg.org/stampede/midnight.git")
       (branch "main")
       (commit "1fa1a052d690186510549f315a80807eecc9d4c6")
       (introduction
        (make-channel-introduction
         "d97d1568954cfcbf543c9fcdfd5771e2b730ae19"
         (openpgp-fingerprint
          "640A 2C3C E948 22D3 394B  40C3 CAFA EECA 00FF 9B1E")))))
