SCOTCHDIR  = %scotch_dir%
ISCOTCH    = -I$(SCOTCHDIR)/include
LSCOTCH    = -L$(SCOTCHDIR)/lib -lptesmumps -lptscotch -lptscotcherr -lscotch

LPORDDIR = $(topdir)/PORD/lib/
IPORD    = -I$(topdir)/PORD/include/
LPORD    = -L$(LPORDDIR) -lpord

LMETISDIR = %metis_dir%/lib
IMETIS    = -I%metis_dir%/include
LMETIS    = -L$(LMETISDIR) -lparmetis -lmetis -lGKlib

ORDERINGSF = -Dscotch -Dmetis -Dpord -Dptscotch -Dparmetis
ORDERINGSC  = $(ORDERINGSF)

LORDERINGS = $(LMETIS) $(LPORD) $(LSCOTCH)
IORDERINGSF = $(ISCOTCH)
IORDERINGSC = $(IMETIS) $(IPORD) $(ISCOTCH)

PLAT    =
LIBEXT  = .a
OUTC    = -o 
OUTF    = -o 
RM = /bin/rm -f
CC = %mpicc%
FC = %mpif90%
FL = %mpif90%
AR = ar vr 
#RANLIB = ranlib
RANLIB  = echo
LAPACK = %lapack_libs%
SCALAP = %scalapack_libs%

LIBPAR = $(SCALAP) $(LAPACK)

INCSEQ = -I$(topdir)/libseq
LIBSEQ  = $(LAPACK) -L$(topdir)/libseq -lmpiseq

LIBBLAS = %blas_libs%
LIBOTHERS = -lpthread

CDEFS   = -DAdd_

OPTF    = %fcflags%
OPTL    = %ldflags%
OPTC    = %cflags%

INCS = $(INCPAR)
LIBS = $(LIBPAR)
LIBSEQNEEDED =
