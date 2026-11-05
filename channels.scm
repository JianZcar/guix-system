(list (channel
        (name 'guix)
        (url "https://git.guix.gnu.org/guix.git")
        (branch "master")
        (commit "475be2d55779a4605cf4047de9c02c3e4a1dae2f")
        (introduction
         (make-channel-introduction "9edb3f66fd807b096b48283debdcddccfea34bad"
          (openpgp-fingerprint
           "BBB0 2DDF 2CEA F6A8 0D1D  E643 A2A0 6DF2 A33A 54FA"))))
      (channel
        (name 'nonguix)
        (url "https://gitlab.com/nonguix/nonguix")
        (branch "master")
        (commit "63d83b22615e7a97a4fb0c3d9f6419e9a7fc4fe0")
        (introduction
         (make-channel-introduction "897c1a470da759236cc11798f4e0a5f7d4d59fbc"
          (openpgp-fingerprint
           "2A39 3FFF 68F4 EF7A 3D29  12AF 6F51 20A0 22FB B2D5"))))
      (channel
        (name 'mangowm)
        (url "https://github.com/mangowm/mango.git")
        (branch "main")
        (commit "faaf4a961f943692f2657eb992a8aa90022f921e"))
      (channel
        (name 'noctalia)
        (url "https://github.com/noctalia-dev/noctalia")
        (branch "main")
        (commit "43bfc457421db865961d18526967df7c85465f56"))
      (channel
        (name 'midnight)
        (url "https://codeberg.org/stampede/midnight.git")
        (branch "main")
        (commit "c8dc9adee6d66930a2cac45015eccaae1bc1f6a3")
        (introduction
         (make-channel-introduction "d97d1568954cfcbf543c9fcdfd5771e2b730ae19"
          (openpgp-fingerprint
           "640A 2C3C E948 22D3 394B  40C3 CAFA EECA 00FF 9B1E")))))
