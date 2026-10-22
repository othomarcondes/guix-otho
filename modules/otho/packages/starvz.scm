;;; Trace analysis: PajeNG and StarVZ.

(define-module (otho packages starvz)
  #:use-module (guix)
  #:use-module (guix git-download)
  #:use-module ((guix licenses) #:prefix license:)
  #:use-module (guix build-system cmake)
  #:use-module (guix build-system r)
  #:use-module (gnu packages base)
  #:use-module (gnu packages bash)
  #:use-module (gnu packages bison)
  #:use-module (gnu packages boost)
  #:use-module (gnu packages commencement)
  #:use-module (gnu packages compression)
  #:use-module (gnu packages cran)
  #:use-module (gnu packages databases)
  #:use-module (gnu packages documentation)
  #:use-module (gnu packages flex)
  #:use-module (gnu packages gawk)
  #:use-module (gnu packages statistics)
  #:use-module (gnu packages perl)
  #:use-module (srfi srfi-1)
  #:use-module (gnu packages pretty-print)
  #:use-module (otho packages energy))

(define-public pajeng
  (package
    (name "pajeng")
    (version "1.3.6")
    (home-page "https://github.com/schnorr/pajeng")
    (source
     (origin
       (method git-fetch)
       (uri
        (git-reference
          (url home-page)
          (commit "e8d14fcc7a5fbec28d7458e8b856a45c545cb9be")
          (recursive? #f)))
       (file-name (git-file-name name version))
       (sha256
        (base32
         "0q0i120852kl2fh9gn88k38ylvfbbai7p4lb96hiadyf6vaaqyxk"))))
    (build-system cmake-build-system)
    (arguments
     (list
      #:tests? #t
      #:configure-flags
      #~(list (string-append "-DCMAKE_EXE_LINKER_FLAGS="
                             "-Wl,-rpath="
                             (assoc-ref %outputs "out")
                             "/lib"))
      #:phases
      #~(modify-phases %standard-phases
          (add-before 'check 'copy-trace-files-for-testing
            (lambda _
              (copy-recursively "../source/traces"
                                "../traces"))))))
    (inputs
     (list boost
           fmt
           r
           recutils))
    (native-inputs
     (list asciidoc
           bison
           flex
           perl))
    (synopsis "PajeNG trace visualization and trace manipulation tools")
    (description
     "PajeNG is a reimplementation in C++ of the traditional Paje
trace visualization infrastructure.  It provides the libpaje library
and several tools to manipulate traces in the Paje file format,
including pj_dump, pj_dump_csv, pj_equals, and pj_validate.")
    (license license:gpl3+)))

;; 0k4px6r134pk4wwxhb5frk02pml9zs0dhvr33z67924wyks45dhr
(define-public r-starvz
  (package
   (name "r-starvz")
   (version "0.7.1")
   (home-page "https://github.com/schnorr/starvz")
   (source
    (origin
     (method git-fetch)
     (uri (git-reference
           (url home-page)
           (commit "61d521d45ac93df6dd13aae845d0f6f95f8568a5")
           (recursive? #f)))
     (file-name (string-append name "-" version "-checkout"))
     (sha256
      (base32
       "0k4px6r134pk4wwxhb5frk02pml9zs0dhvr33z67924wyks45dhr")
      )))
   (properties
    `((upstream-name . "starvz")))
   (build-system r-build-system)
   (propagated-inputs
    (list gawk
          bash
          coreutils
          gcc-toolchain
          grep
          gzip
          pajeng
        ;;  pmtool MAYBE ACTIVATE LATER
	  r
	  r-tidyverse
          r-arrow
          r-bh
          r-car
          r-data-tree
          r-dplyr
          r-flexmix
          r-ggplot2
          r-gtools
          r-lpsolve
          r-magrittr
          r-patchwork
          r-purrr
          r-rcolorbrewer
          r-rcpp
          r-readr
          r-rlang
          r-stringr
          r-tibble
          r-tidyr
          r-yaml
          r-zoo
	  r-testthat
	  apache-arrow
          recutils
          sed
          starpu-energy
          which))
   (synopsis
    "R-Based Visualization Techniques for Task-Based Applications")
   (description
    "Performance analysis workflow that combines the power of the R
language (and the tidyverse realm) and many auxiliary tools to provide a
consistent, flexible, extensible, fast, and versatile framework for the
performance analysis of task-based applications that run on top of the StarPU
runtime (with its MPI (Message Passing Interface) layer for multi-node support).
Its goal is to provide a fruitful prototypical environment to conduct
performance analysis hypothesis-checking for task-based applications that run on
heterogeneous (multi-GPU, multi-core) multi-node HPC (High-performance
computing) platforms.")
   (license license:gpl3)))
