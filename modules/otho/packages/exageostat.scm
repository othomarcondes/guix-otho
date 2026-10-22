;;; Guix package definitions for ExaGeoStat.
;;;
;;; Build with:  guix build exageostat        (MPI)
;;;              guix build exageostat-cuda   (MPI + CUDA)
;;; Dev shell:   guix shell -D exageostat
;;;
;;; With the channel pulled; otherwise add '-L ~/dev/guix-otho/modules'.
;;;
;;; At run time, set OMP_NUM_THREADS=1: OpenBLAS is built with OpenMP and
;;; every StarPU worker would otherwise start its own thread team.  On a
;;; foreign distro, the CUDA variant also needs the host's libcuda.so.1 on
;;; LD_LIBRARY_PATH.
;;;
;;; Requires the guix-science (Chameleon, StarPU), guix-science-nonfree
;;; (CUDA variants) and guix-hpc (StarPU 1.3) channels.

(define-module (otho packages exageostat)
  #:use-module (guix)
  #:use-module (guix git-download)
  #:use-module (guix build-system cmake)
  #:use-module ((guix licenses) #:prefix license:)
  #:use-module (gnu packages linux)
  #:use-module (gnu packages maths)
  #:use-module (gnu packages pkg-config)
  #:use-module (gnu packages python)
  #:use-module (guix-science packages algebra)
  #:use-module (guix-science packages hpc-runtime)
  #:use-module (guix-science-nonfree packages algebra)
  #:use-module (guix-science-nonfree packages cuda)
  #:use-module (guix-science-nonfree packages hpc-runtime)
  #:use-module (inria storm))

;; The 'cmake_modules/ecrc' submodule.
(define ecrc-cmake
  (origin
    (method git-fetch)
    (uri (git-reference
          (url "https://github.com/ecrc/ecrc_cmake")
          (commit "559ed181ed2f895a11c881cc712ec0481a9e16af")))
    (file-name "ecrc-cmake-559ed18-checkout")
    (sha256
     (base32 "0l7yrcgzyfbf6mg7cajc7pfaa35a95n4ksls3jfp9i3m9z5d28p5"))))

(define-public exageostat
  (let ((commit "ee4a82bd5b9bf99089b76dc11d288c24c6da58e0")
        (revision "0"))
    (package
      (name "exageostat")
      (version (git-version "1.2.2" revision commit))
      (source
       (origin
         (method git-fetch)
         (uri (git-reference
               (url "https://github.com/ecrc/exageostat")
               (commit commit)))
         (file-name (git-file-name name version))
         (sha256
          (base32 "0gdlaa7b53z1d1yq29lcy6i8ifl5ildaxykr457chpalriiv6xgs"))))
      (build-system cmake-build-system)
      (arguments
       (list
        #:configure-flags
        #~(list "-DBUILD_SHARED_LIBS=ON"
                "-DEXAGEOSTAT_SCHED_STARPU=ON"
                ;; Chameleon is built with MPI, so StarPU-MPI is used too.
                "-DEXAGEOSTAT_USE_MPI=ON"
                "-DEXAGEOSTAT_USE_HICMA=OFF"
                "-DEXAGEOSTAT_USE_NETCDF=OFF"
                "-DEXAGEOSTAT_INSTALL_DEPS=OFF"
                "-DEXAGEOSTAT_ENABLE_DOCS=OFF"
                ;; The sources rely on tentative definitions, and on
                ;; diagnostics that GCC 14 turned into errors.
                "-DCMAKE_C_FLAGS=-fcommon -fpermissive"
                (string-append "-DNUMBER_OF_CPU="
                               (number->string (parallel-job-count))))
        ;; Each test starts one StarPU worker per core.
        #:parallel-tests? #f
        #:phases
        #~(modify-phases %standard-phases
            (add-after 'unpack 'add-ecrc-cmake
              (lambda _
                (copy-recursively #$ecrc-cmake "cmake_modules/ecrc")))
            (add-after 'unpack 'adapt-to-chameleon
              (lambda _
                ;; include/descriptor.h is a copy of Chameleon 1.1's internal
                ;; control/descriptor.h, which clashes with Chameleon 1.4.
                ;; Use the one matching the Chameleon we build against.
                (for-each (lambda (file)
                            (install-file
                             (string-append #$(package-source chameleon)
                                            "/control/" file)
                             "include/control"))
                          '("descriptor.h" "auxiliary.h"))
                (call-with-output-file "include/descriptor.h"
                  (lambda (port)
                    (display "#include \"control/descriptor.h\"
#ifndef BLKLDD
#define BLKLDD(A, k) A->get_blkldd( A, k )
#endif
" port)))
                ;; CHAMELEON_Desc_Create_User gained a 'get_rankof_arg'
                ;; parameter in Chameleon 1.2.
                (substitute* "misc/include/MLE_misc.h"
                  (("(chameleon_getrankof_2d(_diag)?) \\);" _ fn)
                   (string-append fn ", NULL );")))))
            (add-after 'unpack 'install-examples
              (lambda _
                ;; The examples are the only command-line drivers.
                (let ((port (open-file "examples/CMakeLists.txt" "a")))
                  (display "install(TARGETS ${exe_names} DESTINATION bin)\n"
                           port)
                  (close-port port))))
            (add-after 'unpack 'skip-test-data-download
              (lambda _
                ;; These archives are only used by the real_* examples,
                ;; which are not registered as tests.
                (substitute* "examples/CMakeLists.txt"
                  (("^file\\(DOWNLOAD.*") "")
                  (("COMMAND cmake -E tar zxf .*") ""))))
            (add-before 'check 'prepare-test-environment
              (lambda _
                ;; StarPU writes performance models under $HOME.
                (setenv "HOME" (getcwd))
                (setenv "OMPI_MCA_rmaps_base_oversubscribe" "1")
                ;; StarPU workers need sequential BLAS.  OpenBLAS is built
                ;; with OpenMP, so OPENBLAS_NUM_THREADS alone is ignored and
                ;; every worker would spawn its own OpenMP thread team.
                (setenv "OMP_NUM_THREADS" "1")
                (setenv "OPENBLAS_NUM_THREADS" "1"))))))
      (inputs (list chameleon gsl nlopt openblas starpu))
      (native-inputs (list numactl pkg-config python))
      (home-page "https://github.com/ecrc/exageostat")
      (synopsis "Parallel framework for large-scale geostatistics")
      (description
       "ExaGeoStat (Exascale GeoStatistics) computes Gaussian maximum
likelihood estimation and prediction for large spatial and spatio-temporal
datasets.  It expresses its algorithms as tasks scheduled by the StarPU
runtime system through the Chameleon dense linear algebra library, and
supports exact dense computations as well as diagonal super-tile and
mixed-precision approximations, on shared and distributed memory.")
      (license license:bsd-3))))

;; Building the ld.so cache scans the large CUDA libraries and needs over
;; 9 GiB of memory, enough to get the build OOM-killed on a 16 GiB machine.
;; The cache only speeds up program startup.
(define (without-ld-cache p)
  (package/inherit p
    (arguments
     (substitute-keyword-arguments (package-arguments p)
       ((#:phases phases #~%standard-phases)
        #~(modify-phases #$phases
            (delete 'make-dynamic-linker-cache)))))))

(define-public exageostat-cuda
  (let ((base (package/inherit exageostat
                (arguments
                 (substitute-keyword-arguments (package-arguments exageostat)
                   ((#:configure-flags flags)
                    ;; ExaGeoStat's CUDA codelets pass a cuBLAS handle, as
                    ;; Chameleon expects, only under this macro.  Chameleon
                    ;; 1.1 defined it by default; later releases always use
                    ;; cuBLAS v2 and no longer define it.
                    #~(map (lambda (flag)
                             (if (string-prefix? "-DCMAKE_C_FLAGS=" flag)
                                 (string-append flag
                                                " -DCHAMELEON_USE_CUBLAS_V2")
                                 flag))
                           #$flags))
                   ((#:phases phases)
                    #~(modify-phases #$phases
                        (add-after 'unpack 'adapt-to-cuda
                          (lambda _
                            ;; FindCUDA takes the host '-fPIC' flag and the
                            ;; object suffix from the C++ toolchain settings.
                            (substitute* "CMakeLists.txt"
                              (("^project\\(EXAGEOSTAT C\\)")
                               "project(EXAGEOSTAT C CXX)"))
                            ;; CUDA refuses cublas_v2.h after cublas.h, and
                            ;; Chameleon's headers include cublas_v2.h.
                            (substitute* '("include/common.h"
                                           "include/chameleon_starpu.h"
                                           "exageostat_exact/cuda_core/compute/cuda_conv.cu"
                                           "exageostat_exact/cuda_core/compute/cuda_zcmg.cu")
                              (("#include <cublas\\.h>")
                               "#include <cublas_v2.h>"))
                            ;; The kernels are compiled as C++ and only need
                            ;; CUDA types; the C headers this pulled in
                            ;; (cudablas.h is gpucublas.h since Chameleon
                            ;; 1.2) are not valid C++.
                            (substitute*
                                "exageostat_exact/cuda_core/include/exageostatcudacore.h"
                              (("#include \"cudablas\\.h\"")
                               "#include <cuda_runtime.h>\n#include <cublas_v2.h>")
                              (("#include \"(lapacke|misc/include/MLE_misc|misc/include/flat_file)\\.h\"\n")
                               ""))))
                        (delete 'make-dynamic-linker-cache)))))
                (inputs (modify-inputs (package-inputs exageostat)
                          (replace "chameleon"
                                   (without-ld-cache chameleon-cuda))
                          (replace "starpu" starpu-cuda))))))
    (cuda-enabled-package base
                          #:extra-configure-flags
                          #~(list "-DEXAGEOSTAT_USE_CUDA=ON"))))

;; Chameleon 1.1.0 is the version pinned by ExaGeoStat's 'chameleon'
;; submodule.  It does not build against the StarPU 1.4 data interface API,
;; hence StarPU 1.3.
(define-public chameleon-1.1
  (package/inherit chameleon
    (version "1.1.0")
    (source
     (origin
       (inherit (package-source chameleon))
       (uri (git-reference
             (url "https://gitlab.inria.fr/solverstack/chameleon")
             (commit (string-append "v" version))
             (recursive? #t)))
       (file-name (string-append "chameleon-" version "-checkout"))
       (sha256
        (base32 "0mpnacmkn1287c003a6n3c4r0n395l6fnjilzi7z53lb34s8kaap"))))
    (arguments
     (substitute-keyword-arguments (package-arguments chameleon)
       ;; The test exclusion list of the parent targets 1.4.0.
       ((#:tests? _ #t) #f)))
    (inputs (modify-inputs (package-inputs chameleon)
              (replace "starpu" starpu-1.3)))))

;; ExaGeoStat built against the dependency versions it was developed with,
;; for comparison.
(define-public exageostat-chameleon-1.1
  (package/inherit exageostat
    (name "exageostat-chameleon-1.1")
    (arguments
     (substitute-keyword-arguments (package-arguments exageostat)
       ((#:phases phases)
        #~(modify-phases #$phases
            (replace 'adapt-to-chameleon
              (lambda _
                ;; These point into the 'chameleon' submodule checkout.
                (substitute* "include/descriptor.h"
                  (("chameleon/include/chameleon/") "chameleon/"))))))))
    (inputs (modify-inputs (package-inputs exageostat)
              (replace "chameleon" chameleon-1.1)
              (replace "starpu" starpu-1.3)))))
