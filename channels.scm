;; Channel versions this channel is built and tested against.
;;
;; Reproduce that environment with, for example:
;;   guix time-machine -C channels.scm -- build -L modules exageostat
;;
;; After a 'guix pull', refresh it with:
;;   guix describe -f channels > channels.scm   (then re-add this header)
(list (channel
       (name 'guix-hpc)
       (url "https://gitlab.inria.fr/guix-hpc/guix-hpc.git")
       (branch "master")
       (commit "736e1e54a455b42633a7aed33b1f9400800493a6"))
      (channel
       (name 'guix-hpc-non-free)
       (url "https://gitlab.inria.fr/guix-hpc/guix-hpc-non-free.git")
       (branch "master")
       (commit "9f297858106ce7f86b0a3849f9dd720a6863a0b4"))
      (channel
       (name 'guix)
       (url "https://git.guix.gnu.org/guix.git")
       (branch "master")
       (commit "3b4550e8de2cf271f1c726ff6681dd1ed5a5bdd5")
       (introduction
        (make-channel-introduction
         "9edb3f66fd807b096b48283debdcddccfea34bad"
         (openpgp-fingerprint
          "BBB0 2DDF 2CEA F6A8 0D1D  E643 A2A0 6DF2 A33A 54FA"))))
      (channel
       (name 'guix-science)
       (url "https://codeberg.org/guix-science/guix-science.git")
       (branch "master")
       (commit "6723020c0afcb91b5b1858500c24b044a4fa449d")
       (introduction
        (make-channel-introduction
         "b1fe5aaff3ab48e798a4cce02f0212bc91f423dc"
         (openpgp-fingerprint
          "CA4F 8CF4 37D7 478F DA05  5FD4 4213 7701 1A37 8446"))))
      (channel
       (name 'guix-science-nonfree)
       (url "https://codeberg.org/guix-science/guix-science-nonfree.git")
       (branch "master")
       (commit "f30ef0318dd1c26bcb9d952a50cfa777429ab4e9")
       (introduction
        (make-channel-introduction
         "58661b110325fd5d9b40e6f0177cc486a615817e"
         (openpgp-fingerprint
          "CA4F 8CF4 37D7 478F DA05  5FD4 4213 7701 1A37 8446"))))
      (channel
       (name 'guix-past)
       (url "https://codeberg.org/guix-science/guix-past.git")
       (branch "master")
       (commit "a0ea643f565d5aaa70e50e6a83865389aa5d80ba")
       (introduction
        (make-channel-introduction
         "0c119db2ea86a389769f4d2b9c6f5c41c027e336"
         (openpgp-fingerprint
          "3CE4 6455 8A84 FDC6 9DB4  0CFB 090B 1199 3D9A EBB5")))))
