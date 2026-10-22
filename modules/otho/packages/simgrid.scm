;;; StarPU and Chameleon variants for SimGrid simulation, with FxT
;;; tracing.

(define-module (otho packages simgrid)
  #:use-module (guix)
  #:use-module (guix git-download)
  #:use-module (guix-hpc packages solverstack)
  #:use-module (inria storm)
  #:use-module (inria eztrace)
  #:use-module (guix utils)
  #:use-module (srfi srfi-1)
  #:use-module (guix-science packages simulation)
  #:use-module (guix-science packages hpc-runtime))

(define-public chameleon+simgrid+static
  (package
    (inherit chameleon+simgrid)
    (name "chameleon-simgrid-static")
    (arguments
     (substitute-keyword-arguments
         (package-arguments chameleon+simgrid)
       ((#:configure-flags flags #~'())
        #~(cons "-DBUILD_SHARED_LIBS=OFF"
                 (delete "-DBUILD_SHARED_LIBS=ON"
                         #$flags)))))))

(define-public starpu+simgrid+fxt
  (package/inherit starpu+fxt
    (name "starpu-simgrid-fxt")
    (inputs (modify-inputs (package-inputs starpu+fxt)
              (prepend simgrid)))
    (propagated-inputs (modify-inputs (package-propagated-inputs starpu+fxt)
                         (delete "openmpi")))
    (synopsis
     "Run-time system for heterogeneous computing (simgrid support)")))

(define-public chameleon-simgrid-nosmpi-fxt
  (package
    (inherit chameleon+simgrid+nosmpi)
    (name "chameleon-simgrid-nosmpi-fxt")
    (inputs (modify-inputs (package-inputs chameleon+simgrid+nosmpi)
              (delete "starpu-simgrid" )
              (prepend starpu+simgrid+fxt)))
    (synopsis
     "Dense linear algebra solver with simgrid and fxt (no MPI)")))

(define-public starpu+simgrid+mpi+fxt
  (package/inherit starpu+simgrid+mpi
    (name "starpu-simgrid-mpi-fxt")
    (inputs (modify-inputs (package-inputs starpu+simgrid+mpi)
              (prepend fxt+static)))
    (synopsis
     "Run-time system for heterogeneous computing (simgrid+mpi support)")))

(define-public chameleon-simgrid-fxt
  (package
    (inherit chameleon+simgrid+static)
    (name "chameleon-simgrid-fxt")
    (inputs (modify-inputs (package-inputs chameleon+simgrid+static)
              (delete "starpu-simgrid-mpi" )
              (prepend starpu+simgrid+mpi+fxt)))
    (synopsis
     "Dense linear algebra solver with simgrid, fxt and MPI")))

;; ============================================================================
;; starpu-simgrid-mpi-fxt-fixed
;; ----------------------------------------------------------------------------
;; O pacote starpu-simgrid-mpi-fxt do canal do grupo ADICIONA a entrada
;; fxt-static, mas o StarPU acaba compilado SEM FxT (STARPU_USE_FXT indefinido),
;; entao nenhum arquivo de rastro (prof_file_*) e gerado, mesmo com
;; STARPU_FXT_TRACE=1 e chameleon --trace.
;;
;; Motivo: o canal (inria storm) so injeta --with-fxt no configure do StarPU
;; quando existe uma entrada cujo NOME de pacote e exatamente "fxt":
;;     #$@(if (lookup-package-input this-package "fxt") '("--with-fxt") '())
;; Como a entrada usada e o pacote "fxt-static" (nome != "fxt"), o lookup falha
;; e --with-fxt nunca e passado. As variantes simgrid/mpi do canal funcionam
;; por late-binding de this-package (so mexem em inputs), mas aqui o nome da
;; entrada nao bate.
;;
;; Correcao: passamos --with-fxt explicitamente, preservando os demais flags do
;; pai (o gexp herdado ainda resolve simgrid/mpi via this-package). Mantemos a
;; entrada fxt-static (linkagem estatica para o binario SMPI); o pkg-config
;; ainda expoe o modulo "fxt", entao --with-fxt o encontra.
;; ============================================================================
(define-public starpu-simgrid-mpi-fxt-fixed
  (package/inherit starpu+simgrid+mpi+fxt
    (name "starpu-simgrid-mpi-fxt-fixed")
    (arguments
     (substitute-keyword-arguments (package-arguments starpu+simgrid+mpi+fxt)
       ((#:configure-flags flags #~'())
        #~(cons "--with-fxt" #$flags))))))

;; ============================================================================
;; chameleon-simgrid-v130-fixed
;; ----------------------------------------------------------------------------
;; Chameleon v1.3.0 (SimGrid + MPI/SMPI + FxT, estatico) compilado contra o
;; StarPU 1.4.12 fixado no canal do grupo -- SEM trocar o StarPU (requisito de
;; comparabilidade dos experimentos).
;;
;; Este pacote e AUTOCONTIDO: a fonte esta fixada na tag v1.3.0 aqui embaixo,
;; entao nao precisa de --with-commit. Basta:
;;   export GUIX_PACKAGE_PATH=<dir-deste-arquivo>:/home/share/ojsmarcondes/guix/otho
;;   guix time-machine -C /home/share/ojsmarcondes/guix/channels.scm -- \
;;     shell chameleon-simgrid-v130-fixed starpu-simgrid-mpi-fxt -- bash
;;
;; Por que v1.3.0 e nao a v1.4.0 (padrao do canal): a v1.4.0 usa a API MPI de
;; "task exchange" per-handle do StarPU que so existe no branch master do StarPU
;; (nunca liberada em release), entao nao compila com a 1.4.12. A v1.3.0 (tag
;; 2025-02-17) e anterior a essa API e usa a API antiga (per-task), presente na
;; 1.4.12.
;;
;; A v1.3.0 precisa de 2 backports minimos para compilar contra a 1.4.12 em
;; modo simgrid (corrigidos so ate a v1.4.0):
;;  1) starpu_mpi_data_register e uma MACRO no StarPU 1.4.12; o CMake da v1.3.0
;;     nao detecta a macro e compila uma inline propria que colide. Desativamos
;;     a inline (#if 0) para usar a macro do StarPU.
;;  2) Os codelets ipiv_allreduce chamam cblas_*copy sem incluir o header
;;     <coreblas/cblas_wrapper.h> (adicionado so na v1.4.0). Inserimos o include.
;; ============================================================================
(define-public chameleon-simgrid-v130-fixed
  (package
    (inherit chameleon-simgrid-fxt)
    (name "chameleon-simgrid-v130-fixed")
    (version "1.3.0")
    (source
     (origin
       (inherit (package-source chameleon-simgrid-fxt))
       (uri (git-reference
             (url "https://gitlab.inria.fr/solverstack/chameleon")
             (commit "v1.3.0")
             (recursive? #t)))
       (file-name "chameleon-1.3.0-checkout")
       (sha256
        (base32 "07xiq64ss4762v5fpcn9bd8x8l8xrq9b1hasnrxml0ffcx5q4bxi"))))
    ;; Usa o StarPU corrigido (com FxT de fato habilitado) no lugar do
    ;; starpu-simgrid-mpi-fxt do canal, que compila sem FxT.
    (inputs
     (modify-inputs (package-inputs chameleon-simgrid-fxt)
       (delete "starpu-simgrid-mpi-fxt")
       (prepend starpu-simgrid-mpi-fxt-fixed)))
    (arguments
     (substitute-keyword-arguments (package-arguments chameleon-simgrid-fxt)
       ((#:phases phases #~%standard-phases)
        #~(modify-phases #$phases
            (add-after (quote unpack) (quote fix-v130-against-starpu-1412)
              (lambda _
                ;; (1) evita a colisao com a macro starpu_mpi_data_register
                (substitute* "runtime/starpu/include/runtime_mpi.h"
                  (("#if !defined\\(HAVE_STARPU_MPI_DATA_REGISTER\\)")
                   "#if 0"))
                ;; (2) inclui o cblas nos codelets ipiv_allreduce
                (substitute* "runtime/starpu/codelets/codelet_zipiv_allreduce.c"
                  (("#include \"runtime_codelet_z.h\"")
                   "#include \"runtime_codelet_z.h\"\n#include <coreblas/cblas_wrapper.h>"))))))))))
