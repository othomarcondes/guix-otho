;;; Energy measurement: energy-reader, energy-solver, PAPI with NVML,
;;; and StarPU/Chameleon variants built with energy-reader.

(define-module (otho packages energy)
  #:use-module (guix)
  #:use-module (guix git-download)
  #:use-module ((guix licenses) #:prefix license:)
  #:use-module (guix build-system cmake)
  #:use-module (gnu packages databases)
  #:use-module (gnu packages mpi)
  #:use-module (gnu packages pkg-config)
  #:use-module (gnu packages python-xyz)
  #:use-module (gnu packages statistics)
  #:use-module (inria storm)
  #:use-module (guix utils)
  #:use-module (srfi srfi-1)
  #:use-module (guix build-system python)
  #:use-module (gnu packages profiling)
  #:use-module (guix-science-nonfree packages cuda)
  #:use-module (guix-science-nonfree packages hpc-runtime)
  #:use-module (guix-science packages performance-monitoring)
  #:use-module (guix-science-nonfree packages algebra)
  #:use-module (guix-science packages algebra)
  #:use-module (gnu packages python-science)
  #:use-module (gnu packages machine-learning)
  #:use-module (gnu packages python-web)
  #:use-module (gnu packages web)
  #:use-module (gnu packages python-build))

(define-public papi-custom
  (package
    (inherit papi)
    (name "papi-custom")
    (arguments
     (substitute-keyword-arguments (package-arguments papi)
       ((#:configure-flags flags)
        #~(map (lambda (f)
                 (if (string-prefix? "--with-components=" f)
                     (string-append f " nvml")
                     f))
               #$flags)))
     )))

;; ENERGY PACKAGES
(define-public energy-reader
  (package
  (name "energy-reader")
    (version "1.0")
    (source
      (origin
        (method git-fetch)
        (uri (git-reference
              (url "https://gitlab.com/JulesRisse/energy-reader")
              (commit "170c7328c2dd8b963a6d8b192de75d0208354423")))
        (file-name (git-file-name name version))
        (sha256 (base32 "1ywiz4x0md3c7ay14ajxk3f2fanq1yf6zzckcz33jsad82s398ng"))))
    (native-inputs (list pkg-config))
    (propagated-inputs (list `(,hwloc "lib")))
    (build-system cmake-build-system)
    (arguments (list 
                     #:tests? #f
                     #:build-type "Release"))
    (home-page "https://gitlab.com/JulesRisse/energy-reader")
    (synopsis "High-performance C library and tools for reading energy from multiple backends on 
    a variety of hardware devices.")
    (description "energy-reader allows reading energy consumption counters values from Intel and 
    AMD CPUs, Nvidia and AMD GPUs, as well as HPE clusters.")
    (license license:gpl3+)))

(define-public energy-reader-nvml
  (package
    (inherit energy-reader)
    (name "energy-reader-nvml")
    (inputs
     (modify-inputs (package-inputs energy-reader)
       (prepend cuda)))
    (arguments
     (substitute-keyword-arguments (package-arguments energy-reader)
       ((#:configure-flags flags
         '())
        #~(append (list "-DENABLE_NVML=ON")))
	((#:tests? #f #f) #f)
	((#:validate-runpath? #f #f)
                 ;; RUNPATH validation fails since libnvml.so.1 is not present at build time
                  #f)

       )

     )))

(define-public energy-solver
  (package
  (name "energy-solver")
    (version "0.0.1")
    (home-page "https://gitlab.com/JulesRisse/energy-solver")
    (source
      (origin
        (method git-fetch)
        (uri (git-reference
          (url home-page)
          (commit "0233641e354b60eb8196662929e63db2edea5d18")))
        (file-name (git-file-name name version))
        (sha256 (base32 "17734mryn2ss7jd3i2k56sqqqvzzm28iw0j311hbgkmvi952dlqk"))))
    (build-system python-build-system)
    (arguments
	 (list
	  #:tests? #f
	  #:phases
	  #~(modify-phases %standard-phases
	      (delete 'sanity-check))))     
    (propagated-inputs
	 (list
	  python-bokeh
	  python-flask
	  python-joblib
	  python-numpy
	  python-pandas
	  python-polars
	  python-scikit-learn
	  python-scipy
	  python-setuptools
	  python-sqlalchemy-2
	  python-statsmodels
	  jq))
    (synopsis "Solving overdetermined energy systems")
    (description "energy-solver generates and solve energy systems from starpu-energy traces")
    (license license:gpl3+)))

;; STARPU
(define-public starpu-energy
  (package
    (inherit starpu+fxt)
    (name "starpu-energy")
    (source (origin
              (inherit (package-source starpu+fxt))
              (uri (git-reference
                    (url (git-reference-url (origin-uri (package-source starpu+fxt))))
                    (commit "919c107f6bcf5179d0d6727a0361f5c40ab664fe")))
              (sha256 (base32 "1mffpz07r3mwv0hbnxgcmm3i4aixgsa1nsw8xl8gc0a97a6xsd9k"))))
    (inputs
      (modify-inputs (package-inputs starpu+fxt)
        (append energy-reader)))
    (arguments
      (substitute-keyword-arguments (package-arguments starpu+fxt)
        ((#:configure-flags flags '())
         #~(append (list "--enable-energyreader" "--disable-opencl" "--with-hwloc")
            #$flags))))
    (synopsis
     "Run-time system for heterogeneous computing, with energy-reader support")))

(define-public starpu-cuda-energy
  (package
    (inherit starpu-cuda)
    (name "starpu-cuda-energy")
    (source (origin
              (inherit (package-source starpu-cuda))
              (uri (git-reference
                    (url (git-reference-url (origin-uri (package-source starpu-cuda))))
                    (commit "919c107f6bcf5179d0d6727a0361f5c40ab664fe")))
              (sha256 (base32 "1mffpz07r3mwv0hbnxgcmm3i4aixgsa1nsw8xl8gc0a97a6xsd9k"))))
    (inputs
      (modify-inputs (package-inputs starpu-cuda)
        (prepend fxt energy-reader-nvml)))
    (arguments
      (substitute-keyword-arguments (package-arguments starpu-cuda)
        ((#:configure-flags flags '())
         #~(append (list "--enable-energyreader" "--with-fxt" "--disable-opencl" "--with-hwloc") 
            #$flags))))
    (synopsis
     "Run-time system for heterogeneous computing, with energy-reader and CUDA support")))

;; CHAMELEON
(define-public chameleon-energy
  (package
    (inherit chameleon)
    (name "chameleon-energy")
    (inputs
      (modify-inputs (package-inputs chameleon)
        (delete "starpu")
        (prepend starpu-energy)))
    (arguments
      (substitute-keyword-arguments (package-arguments chameleon)
        ((#:configure-flags flags '())
          #~(append (list "-DCHAMELEON_USE_CUDA=OFF") #$flags))))
    (synopsis
     "Dense linear algebra solver using starpu-energy")))

(define-public chameleon-cuda-energy
  (package
    (inherit chameleon-cuda)
    (name "chameleon-cuda-energy")
    (inputs (modify-inputs (package-inputs chameleon-cuda)
              (delete "starpu-cuda" )
              (prepend starpu-cuda-energy energy-reader-nvml)
	      ))
    (synopsis
     "Dense linear algebra solver using starpu-cuda-energy")))

(define-public chameleon-mkl-energy
  (package
    (inherit chameleon-mkl)
    (name "chameleon-mkl-energy")
    (inputs
      (modify-inputs (package-inputs chameleon-mkl)
        (delete "starpu")
        (prepend starpu-energy)))
    (arguments
      (substitute-keyword-arguments (package-arguments chameleon-mkl)
        ((#:configure-flags flags '())
          #~(append (list "-DCHAMELEON_USE_CUDA=OFF") #$flags))))
    (synopsis
     "Dense linear algebra solver using starpu-energy and Intel mkl")))

(define-public chameleon-cuda-mkl-energy
  (package
    (inherit chameleon-cuda-mkl)
    (name "chameleon-cuda-mkl-energy")
    (inputs (modify-inputs (package-inputs chameleon-cuda-mkl)
              (delete "starpu-cuda" )
              (prepend starpu-cuda-energy)))
    (synopsis
     "Dense linear algebra solver using starpu-cuda-energy and the mkl")))
