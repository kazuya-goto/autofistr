include Makefile.in

INTELDIR ?= /opt/intel
NJOBS ?= 1


TOPDIR = $(CURDIR)

$(info COMPILER is $(COMPILER))
$(info MPI is $(MPI))
$(info BLASLAPACK is $(BLASLAPACK))

# detect SYSTEM MPI
ifneq ("$(shell mpicc --showme:version 2> /dev/null | grep 'Open MPI')", "")
  $(info SYSTEM MPI is OpenMPI)
  SYSTEM_MPI = OpenMPI
else
  ifneq ("$(shell mpicc -v 2> /dev/null | grep 'MPICH')", "")
    $(info SYSTEM MPI is MPICH)
    SYSTEM_MPI = MPICH
  else
    $(info SYSTEM MPI is unknown)
    SYSTEM_MPI = unknown
  endif
endif

ifeq ($(MPI), $(SYSTEM_MPI))
  DOWNLOAD_MPI ?= false
else
  DOWNLOAD_MPI = true
endif
$(info DOWNLOAD_MPI is $(DOWNLOAD_MPI))


ifeq ($(COMPILER), FUJITSU)
  PREFIX = $(TOPDIR)/$(COMPILER)
else
  PREFIX = $(TOPDIR)/$(COMPILER)_$(MPI)
endif


OPENMPI   = openmpi-2.1.0
MPICH     = mpich-3.2
OPENBLAS  = OpenBLAS-0.2.19
ATLAS     = atlas3.10.3
SCALAPACK = scalapack-2.0.2
METIS     = metis-5.1.0
PARMETIS  = parmetis-4.0.3
SCOTCH    = scotch_6.0.4
MUMPS     = MUMPS_5.1.1
TRILINOS  = trilinos-12.10.1
FISTR     = FrontISTR


PACKAGES =
PKG_DIRS =
TARGET =

ifeq ($(COMPILER), INTEL)
  CC = icc
  CXX = icpc
  FC = ifort
  CFLAGS = -O3 -xHost
  CXXFLAGS = -O3 -xHost
  FCFLAGS = -O3 -xHost
  OMPFLAGS = -qopenmp
  NOFOR_MAIN = -nofor_main
  ifeq ($(BLASLAPACK), MKL)
    BLASLIB = -lmkl_intel_lp64 -lmkl_intel_thread -lmkl_core -liomp5
    LAPACKLIB = -lmkl_intel_lp64 -lmkl_intel_thread -lmkl_core -liomp5
  else
    ifeq ($(BLASLAPACK), OpenBLAS)
#      $(warning OpenBLAS was specified but forced to use MKL)
#      BLASLAPACK = MKL
      PACKAGES += $(OPENBLAS).tar.gz $(SCALAPACK).tgz
      PKG_DIRS += $(OPENBLAS) $(SCALAPACK)
      TARGET += $(PREFIX)/.openblas $(PREFIX)/.scalapack
      BLASLIB = -L$(PREFIX)/$(OPENBLAS)/lib -lopenblas
      LAPACKLIB = -L$(PREFIX)/$(OPENBLAS)/lib -lopenblas
      SCALAPACKLIB = -L$(PREFIX)/$(SCALAPACK)/lib -lscalapack
    else
      ifeq ($(BLASLAPACK), ATLAS)
#        $(warning OpenBLAS was specified but forced to use MKL)
#        BLASLAPACK = MKL
        PACKAGES += $(ATLAS).tar.bz2 $(SCALAPACK).tgz
        PKG_DIRS += $(ATLAS) $(SCALAPACK)
        TARGET += $(PREFIX)/.atlas $(PREFIX)/.scalapack
        BLASLIB = -L$(PREFIX)/$(ATLAS)/lib -lf77blas -lcblas -latlas
        LAPACKLIB = -L$(PREFIX)/$(ATLAS)/lib -llapack -lf77blas -lcblas -latlas
        SCALAPACKLIB = -L$(PREFIX)/$(SCALAPACK)/lib -lscalapack
      else
        $(error unsupported BLASLAPACK: $(BLASLAPACK))
      endif
    endif
  endif
  ifeq ($(MPI), IMPI)
    MPICC = mpiicc
    MPICXX = mpiicpc
    MPIF90 = mpiifort
    MPIEXEC = mpiexec
    ifeq ($(BLASLAPACK), MKL)
      SCALAPACKLIB = -lmkl_scalapack_lp64 -lmkl_blacs_intelmpi_lp64
    endif
  else
    ifeq ($(MPI), OpenMPI)
      MPICC = $(PREFIX)/$(OPENMPI)/bin/mpicc
      MPICXX = $(PREFIX)/$(OPENMPI)/bin/mpicxx
      MPIF90 = $(PREFIX)/$(OPENMPI)/bin/mpif90
      MPIEXEC = $(PREFIX)/$(OPENMPI)/bin/mpiexec
      PACKAGES += $(OPENMPI).tar.bz2
      PKG_DIRS += $(OPENMPI)
      TARGET += $(PREFIX)/.openmpi
      ifeq ($(BLASLAPACK), MKL)
        SCALAPACKLIB = -lmkl_scalapack_lp64 -lmkl_blacs_openmpi_lp64
      endif
    else
      ifeq ($(MPI), MPICH)
        MPICC = $(PREFIX)/$(MPICH)/bin/mpicc
        MPICXX = $(PREFIX)/$(MPICH)/bin/mpicxx
        MPIF90 = $(PREFIX)/$(MPICH)/bin/mpif90
        MPIEXEC = $(PREFIX)/$(MPICH)/bin/mpiexec
        PACKAGES += $(MPICH).tar.gz
        PKG_DIRS += $(MPICH)
        TARGET += $(PREFIX)/.mpich
        ifeq ($(BLASLAPACK), MKL)
          SCALAPACKLIB = -lmkl_scalapack_lp64 -lmkl_blacs_intelmpi_lp64
        endif
      else
        $(error unsupported MPI: $(MPI))
      endif
    endif
  endif
  LIBSTDCXX = -lstdc++
  CLINKER = $(MPICC)
  F90LINKER = $(MPIF90)
  F90FPPFLAG = -fpp
  SCOTCH_MAKEFILE_INC = Makefile.inc.x86-64_pc_linux2.icc
endif
ifeq ($(COMPILER), GCC)
  CC = gcc
  CXX = g++
  FC = gfortran
  CFLAGS = -O3 -march=native
  CXXFLAGS = -O3 -march=native
  FCFLAGS = -O3 -march=native
  OMPFLAGS = -fopenmp
  NOFOR_MAIN =
  ifeq ($(BLASLAPACK), MKL)
#    $(error MKL not supported with GCC)
    MKLROOT = $(INTELDIR)/mkl
    BLASLIB = -Wl,--start-group ${MKLROOT}/lib/intel64/libmkl_gf_lp64.a ${MKLROOT}/lib/intel64/libmkl_gnu_thread.a ${MKLROOT}/lib/intel64/libmkl_core.a -Wl,--end-group -lgomp
    LAPACKLIB =${MKLROOT}/lib/intel64/libmkl_scalapack_lp64.a -Wl,--start-group ${MKLROOT}/lib/intel64/libmkl_gf_lp64.a ${MKLROOT}/lib/intel64/libmkl_gnu_thread.a ${MKLROOT}/lib/intel64/libmkl_core.a ${MKLROOT}/lib/intel64/libmkl_blacs_openmpi_lp64.a -Wl,--end-group -lgomp
  else
    ifeq ($(BLASLAPACK), OpenBLAS)
      PACKAGES += $(OPENBLAS).tar.gz $(SCALAPACK).tgz
      PKG_DIRS += $(OPENBLAS) $(SCALAPACK)
      TARGET += $(PREFIX)/.openblas $(PREFIX)/.scalapack
      BLASLIB = -L$(PREFIX)/$(OPENBLAS)/lib -lopenblas
      LAPACKLIB = -L$(PREFIX)/$(OPENBLAS)/lib -lopenblas
      SCALAPACKLIB = -L$(PREFIX)/$(SCALAPACK)/lib -lscalapack
    else
      ifeq ($(BLASLAPACK), ATLAS)
        PACKAGES += $(ATLAS).tar.bz2 $(SCALAPACK).tgz
        PKG_DIRS += $(ATLAS) $(SCALAPACK)
        TARGET += $(PREFIX)/.atlas $(PREFIX)/.scalapack
        BLASLIB = -L$(PREFIX)/$(ATLAS)/lib -lf77blas -lcblas -latlas
        LAPACKLIB = -L$(PREFIX)/$(ATLAS)/lib -llapack -lf77blas -lcblas -latlas
        SCALAPACKLIB = -L$(PREFIX)/$(SCALAPACK)/lib -lscalapack
      else
        $(error unsupported BLASLAPACK: $(BLASLAPACK))
      endif
    endif
  endif
  ifeq ($(MPI), IMPI)
    $(error Intel MPI not supported with GCC)
  else
    ifeq ($(MPI), OpenMPI)
      ifeq ($(DOWNLOAD_MPI), true)
        MPICC = $(PREFIX)/$(OPENMPI)/bin/mpicc
        MPICXX = $(PREFIX)/$(OPENMPI)/bin/mpicxx
        MPIF90 = $(PREFIX)/$(OPENMPI)/bin/mpif90
        MPIEXEC = $(PREFIX)/$(OPENMPI)/bin/mpiexec
        PACKAGES += $(OPENMPI).tar.bz2
        PKG_DIRS += $(OPENMPI)
        TARGET += $(PREFIX)/.openmpi
      else
        ifeq ("$(shell mpicc --showme:version 2> /dev/null | grep 'Open MPI')", "")
          $(error mpicc in the path is not OpenMPI)
        endif
        MPICC = mpicc
        MPICXX = mpicxx
        MPIF90 = mpif90
        MPIEXEC = mpiexec
      endif
      ifeq ($(BLASLAPACK), MKL)
        SCALAPACKLIB = ${MKLROOT}/lib/intel64/libmkl_scalapack_lp64.a ${MKLROOT}/lib/intel64/libmkl_blacs_openmpi_lp64.a
      endif
    else
      ifeq ($(MPI), MPICH)
        ifeq ($(DOWNLOAD_MPI), true)
          MPICC = $(PREFIX)/$(MPICH)/bin/mpicc
          MPICXX = $(PREFIX)/$(MPICH)/bin/mpicxx
          MPIF90 = $(PREFIX)/$(MPICH)/bin/mpif90
          MPIEXEC = $(PREFIX)/$(MPICH)/bin/mpiexec
          PACKAGES += $(MPICH).tar.gz
          PKG_DIRS += $(MPICH)
          TARGET += $(PREFIX)/.mpich
        else
          ifeq ("$(shell mpicc -v 2> /dev/null | grep 'MPICH')", "")
            $(error mpicc in the path is not MPICH)
          endif
          MPICC = mpicc
          MPICXX = mpicxx
          MPIF90 = mpif90
          MPIEXEC = mpiexec
        endif
        ifeq ($(BLASLAPACK), MKL)
          SCALAPACKLIB = ${MKLROOT}/lib/intel64/libmkl_scalapack_lp64.a ${MKLROOT}/lib/intel64/libmkl_blacs_intelmpi_lp64.a
        endif
      else
        $(error unsupported MPI: $(MPI))
      endif
    endif
  endif
  LIBSTDCXX = -lstdc++
  CLINKER = $(MPICC)
  F90LINKER = $(MPIF90)
  F90FPPFLAG = -cpp
  SCOTCH_MAKEFILE_INC = Makefile.inc.x86-64_pc_linux2
endif
ifeq ($(COMPILER), FUJITSU)
  CC = fcc
  CXX = FCC
  FC = frt
  CFLAGS = -Kfast -Xg
  CXXFLAGS = -Kfast -Xg
  FCFLAGS = -Kfast -Xg
  OMPFLAGS = -Kopenmp
  NOFOR_MAIN =
  BLASLIB = -SSL2BLAMP
  LAPACKLIB = -SSL2BLAMP
  ifneq ($(MPI), FUJITSU)
    $(warning forced to use FUJITSU MPI)
    MPI = FUJITSU
  endif
  MPICC = mpifcc
  MPICXX = mpiFCC
  MPIF90 = mpifrt
  MPIEXEC = mpiexec
  LIBSTDCXX =
  CLINKER = $(MPICXX)
  F90LINKER = $(MPICXX) --linkfortran
  F90FPPFLAG = -fpp
  SCALAPACKLIB = -SCALAPACK
  SCOTCH_MAKEFILE_INC = Makefile.inc.x86-64_pc_linux2
endif


PACKAGES += $(METIS).tar.gz $(PARMETIS).tar.gz $(SCOTCH).tar.gz $(MUMPS).tar.gz $(TRILINOS)-Source.tar.bz2
PKG_DIRS += $(METIS) $(PARMETIS) $(SCOTCH) $(MUMPS) $(TRILINOS)-Source $(FISTR)
TARGET += $(PREFIX)/.metis $(PREFIX)/.parmetis $(PREFIX)/.scotch $(PREFIX)/.mumps $(PREFIX)/.trilinos $(PREFIX)/.frontistr


.PHONY: all download extract openmpi mpich openblas atlas scalapack metis parmetis scotch mumps trilinos frontistr clean distclean


all: $(TARGET)

download: $(PACKAGES)

extract: $(PKG_DIRS)


$(OPENMPI).tar.bz2:
	wget https://www.open-mpi.org/software/ompi/v2.1/downloads/$(OPENMPI).tar.bz2

$(OPENMPI): $(OPENMPI).tar.bz2
	tar jxvf $(OPENMPI).tar.bz2

$(PREFIX)/.openmpi: $(OPENMPI)
	(cd $(OPENMPI); mkdir build; cd build; \
	../configure CC=$(CC) CXX=$(CXX) F77=$(FC) FC=$(FC) \
	CFLAGS="$(CFLAGS)" CXXFLAGS="$(CXXFLAGS)" FFLAGS="$(FCFLAGS)" FCFLAGS="$(FCFLAGS)" \
	--prefix=$(PREFIX)/$(OPENMPI); \
	make -j $(NJOBS); make install)
	touch $@

openmpi: $(PREFIX)/.openmpi


$(MPICH).tar.gz:
	wget http://www.mpich.org/static/downloads/3.2/$(MPICH).tar.gz

$(MPICH): $(MPICH).tar.gz
	tar zxvf $(MPICH).tar.gz

$(PREFIX)/.mpich: $(MPICH)
	(cd $(MPICH); mkdir build; cd build; \
	../configure CC=$(CC) CXX=$(CXX) F77=$(FC) FC=$(FC) --enable-fast=all \
	MPICHLIB_CFLAGS="$(CFLAGS)" MPICHLIB_FFLAGS="$(FCFLAGS)" \
	MPICHLIB_CXXFLAGS="$(CXXFLAGS)" MPICHLIB_FCFLAGS="$(FCFLAGS)" \
	-prefix=$(PREFIX)/$(MPICH); \
	make -j $(NJOBS); make install)
	touch $@

mpich: $(PREFIX)/.mpich


$(OPENBLAS).tar.gz:
	wget http://github.com/xianyi/OpenBLAS/archive/v0.2.19.tar.gz
	mv v0.2.19.tar.gz $@

$(OPENBLAS): $(OPENBLAS).tar.gz
	tar zxvf $(OPENBLAS).tar.gz

$(PREFIX)/.openblas: $(OPENBLAS)
	(cd $(OPENBLAS); make USE_OPENMP=1; make install PREFIX=$(PREFIX)/$(OPENBLAS))
	touch $@

openblas: $(PREFIX)/.openblas


$(ATLAS).tar.bz2:
	wget https://downloads.sourceforge.net/project/math-atlas/Stable/3.10.3/$(ATLAS).tar.bz2

lapack-3.7.0.tgz:
	wget http://www.netlib.org/lapack/lapack-3.7.0.tgz

$(ATLAS): $(ATLAS).tar.bz2
	tar jxvf $(ATLAS).tar.bz2
	mv ATLAS $@

$(PREFIX)/.atlas: $(ATLAS) lapack-3.7.0.tgz
	(cd $(ATLAS); mkdir build; cd build; \
	../configure --with-netlib-lapack-tarfile=$(TOPDIR)/lapack-3.7.0.tgz \
	-Si omp 1 -F alg -fopenmp --prefix=$(PREFIX)/$(ATLAS); \
	make build; make install)
	touch $@

atlas: $(PREFIX)/.atlas


$(SCALAPACK).tgz:
	wget http://www.netlib.org/scalapack/$(SCALAPACK).tgz

$(SCALAPACK): $(SCALAPACK).tgz
	tar zxvf $(SCALAPACK).tgz

SCALAPACK_CMAKE_OPTS = \
	-D CMAKE_C_COMPILER=$(CC) \
	-D CMAKE_Fortran_COMPILER=$(FC) \
	-D MPI_C_COMPILER=$(MPICC) \
	-D MPI_Fortran_COMPILER=$(MPIF90) \
	-D CMAKE_INSTALL_PREFIX=$(PREFIX)/$(SCALAPACK)

ifeq ($(BLASLAPACK), OpenBLAS)
SCALAPACK_CMAKE_OPTS += \
	-D BLAS_goto2_LIBRARY:FILEPATH=$(PREFIX)/$(OPENBLAS)/lib/libopenblas.so \
	-D LAPACK_goto2_LIBRARY:FILEPATH=$(PREFIX)/$(OPENBLAS)/lib/libopenblas.so
else
SCALAPACK_CMAKE_OPTS += \
	-D BLAS_atlas_LIBRARY:FILEPATH=$(PREFIX)/$(ATLAS)/lib/libatlas.so \
	-D BLAS_f77blas_LIBRARY:FILEPATH=$(PREFIX)/$(ATLAS)/lib/libf77blas.so \
	-D LAPACK_LA_ACK_LIBRARY:FILEPATH=$(PREFIX)/$(ATLAS)/liblapack_atlas.so
endif

$(PREFIX)/.scalapack: $(SCALAPACK)
	(cd $(SCALAPACK); mkdir build; cd build; \
	cmake $(SCALAPACK_CMAKE_OPTS) ..; \
	make -j $(NJOBS); \
	make install)
	touch $@

scalapack: $(PREFIX)/.scalapack


$(METIS).tar.gz:
	wget http://glaros.dtc.umn.edu/gkhome/fetch/sw/metis/$(METIS).tar.gz

$(METIS): $(METIS).tar.gz
	tar zxvf $(METIS).tar.gz

$(PREFIX)/.metis: $(METIS)
	(cd $(METIS) && make config prefix=$(PREFIX)/$(PARMETIS) cc=$(CC) && \
	make --no-print-directory -j $(NJOBS) install)
	touch $@

metis: $(PREFIX)/.metis


$(PARMETIS).tar.gz:
	wget http://glaros.dtc.umn.edu/gkhome/fetch/sw/parmetis/$(PARMETIS).tar.gz

$(PARMETIS): $(PARMETIS).tar.gz
	tar zxvf $(PARMETIS).tar.gz

$(PREFIX)/.parmetis: $(PARMETIS)
	(cd $(PARMETIS) && make config prefix=$(PREFIX)/$(PARMETIS) cc=$(MPICC) cxx=$(MPICXX) && \
	make --no-print-directory -j $(NJOBS) install)
	touch $@

parmetis: $(PREFIX)/.parmetis


$(SCOTCH).tar.gz:
	wget https://gforge.inria.fr/frs/download.php/file/34618/$(SCOTCH).tar.gz

$(SCOTCH): $(SCOTCH).tar.gz
	tar zxvf $(SCOTCH).tar.gz

$(PREFIX)/.scotch: $(SCOTCH)
	perl -pe \
	"if(/^CCS/){s!= .*!= $(CC)!;} \
	elsif(/^CCP/){s!= .*!= $(MPICC)!;} \
	elsif(/^CCD/){s!= .*!= $(MPICC)!;}" \
	$(SCOTCH)/src/Make.inc/$(SCOTCH_MAKEFILE_INC) > $(SCOTCH)/src/Makefile.inc
	(cd $(SCOTCH)/src && \
	make -j $(NJOBS) scotch && \
	make -j $(NJOBS) ptscotch && \
	make esmumps && \
	make ptesmumps && \
	if [ ! -d $(PREFIX)/$(SCOTCH) ]; then mkdir $(PREFIX)/$(SCOTCH); fi && \
	make prefix=$(PREFIX)/$(SCOTCH) install && \
	cp -f ../lib/*esmumps*.a $(PREFIX)/$(SCOTCH)/lib)
	touch $@

scotch: $(PREFIX)/.scotch


$(MUMPS).tar.gz:
	wget http://mumps.enseeiht.fr/$(MUMPS).tar.gz

$(MUMPS): $(MUMPS).tar.gz
	tar zxvf $(MUMPS).tar.gz

$(PREFIX)/.mumps: $(MUMPS)
	perl -pe \
	"s!%scotch_dir%!$(PREFIX)/$(SCOTCH)!; \
	s!%metis_dir%!$(PREFIX)/$(PARMETIS)!; \
	s!%mpicc%!$(MPICC)!; \
	s!%mpif90%!$(MPIF90)!; \
	s!%lapack_libs%!$(LAPACKLIB)!; \
	s!%scalapack_libs%!$(SCALAPACKLIB)!; \
	s!%blas_libs%!$(BLASLIB)!; \
	s!%fcflags%!$(FCFLAGS) $(NOFOR_MAIN) $(OMPFLAGS)!; \
	s!%ldflags%!$(FCFLAGS) $(NOFOR_MAIN) $(OMPFLAGS)!; \
	s!%cflags%!$(CFLAGS) $(OMPFLAGS)!;" \
	MUMPS_Makefile.inc > $(MUMPS)/Makefile.inc  ### to be fixed
	(cd $(MUMPS) && make && \
	if [ ! -d $(PREFIX)/$(MUMPS) ]; then mkdir $(PREFIX)/$(MUMPS); fi && \
	cp -r lib include $(PREFIX)/$(MUMPS)/.)
	touch $@

mumps: $(PREFIX)/.mumps


$(TRILINOS)-Source.tar.bz2:
	wget http://trilinos.csbsju.edu/download/files/$(TRILINOS)-Source.tar.bz2

$(TRILINOS)-Source: $(TRILINOS)-Source.tar.bz2
	tar jxvf $(TRILINOS)-Source.tar.bz2

TRILINOS_CMAKE_OPTS = \
	-D Trilinos_ENABLE_ALL_OPTIONAL_PACKAGES=OFF \
	-D CMAKE_BUILD_TYPE=RELEASE \
	-D CMAKE_C_COMPILER=$(MPICC) \
	-D CMAKE_C_FLAGS="$(CFLAGS)" \
	-D CMAKE_CXX_COMPILER=$(MPICXX) \
	-D CMAKE_CXX_FLAGS="$(CFLAGS)" \
	-D TPL_ENABLE_MPI=ON \
	-D MPI_EXEC=$(MPIEXEC) \
	-D Trilinos_ENABLE_CXX11=OFF \
	-D Trilinos_ENABLE_Fortran:BOOL=OFF \
	-D Trilinos_ENABLE_OpenMP:BOOL=ON \
	-D OpenMP_C_FLAGS=$(OMPFLAGS) \
	-D OpenMP_CXX_FLAGS=$(OMPFLAGS) \
	-D Trilinos_ENABLE_Epetra=ON \
	-D Trilinos_ENABLE_Zoltan=ON \
	-D Trilinos_ENABLE_Amesos=ON \
	-D Trilinos_ENABLE_ML=ON \
	-D ML_ENABLE_Amesos=ON \
	-D TPL_ENABLE_ParMETIS=ON \
	-D ParMETIS_INCLUDE_DIRS=$(PREFIX)/$(PARMETIS)/include \
	-D ParMETIS_LIBRARY_DIRS=$(PREFIX)/$(PARMETIS)/lib \
	-D TPL_ENABLE_MUMPS=ON \
	-D MUMPS_INCLUDE_DIRS=$(PREFIX)/$(MUMPS)/include \
	-D MUMPS_LIBRARY_DIRS=$(PREFIX)/$(MUMPS)/lib \
	-D TPL_ENABLE_Scotch=ON \
	-D Scotch_INCLUDE_DIRS=$(PREFIX)/$(SCOTCH)/include \
	-D Scotch_LIBRARY_DIRS=$(PREFIX)/$(SCOTCH)/lib \
	-D TPL_ENABLE_BLAS=ON \
	-D TPL_ENABLE_LAPACK=ON \
	-D CMAKE_INSTALL_PREFIX=$(PREFIX)/$(TRILINOS)

ifeq ($(BLASLAPACK), OpenBLAS)
TRILINOS_CMAKE_OPTS += \
	-D BLAS_INCLUDE_DIRS:PATH=$(PREFIX)/$(OPENBLAS)/include \
	-D BLAS_LIBRARY_DIRS:PATH=$(PREFIX)/$(OPENBLAS)/lib \
	-D BLAS_LIBRARY_NAMES:STRING="openblas" \
	-D LAPACK_LIBRARY_DIRS:PATH=$(PREFIX)/$(OPENBLAS)/lib \
	-D LAPACK_LIBRARY_NAMES:STRING="openblas"
else
  ifeq ($(BLASLAPACK), ATLAS)
TRILINOS_CMAKE_OPTS += \
	-D BLAS_INCLUDE_DIRS:PATH=$(PREFIX)/$(ATLAS)/include \
	-D BLAS_LIBRARY_DIRS:PATH=$(PREFIX)/$(ATLAS)/lib \
	-D BLAS_LIBRARY_NAMES:STRING="f77blas;cblas;atlas" \
	-D LAPACK_LIBRARY_DIRS:PATH=$(PREFIX)/$(ATLAS)/lib \
	-D LAPACK_LIBRARY_NAMES:STRING="lapack;f77blas;cblas;atlas"
  else
    ifeq ($(BLASLAPACK), MKL)
TRILINOS_CMAKE_OPTS += \
	-D BLAS_INCLUDE_DIRS:PATH=$(INTELDIR)/mkl/include \
	-D BLAS_LIBRARY_DIRS:PATH="$(INTELDIR)/mkl/lib/intel64;$(INTELDIR)/lib/intel64" \
	-D BLAS_LIBRARY_NAMES:STRING="mkl_intel_lp64;mkl_intel_thread;mkl_core;iomp5" \
	-D LAPACK_LIBRARY_DIRS:PATH="$(INTELDIR)/mkl/lib/intel64;$(INTELDIR)/lib/intel64" \
	-D LAPACK_LIBRARY_NAMES:STRING="mkl_intel_lp64;mkl_intel_thread;mkl_core;iomp5"
    endif
  endif
endif

$(PREFIX)/.trilinos: $(TRILINOS)-Source
	(cd $(TRILINOS)-Source; mkdir build; cd build; \
	cmake $(TRILINOS_CMAKE_OPTS) ..; \
	make -j $(NJOBS); \
	make install)
	touch $@

trilinos: $(PREFIX)/.trilinos


$(FISTR):
	if [ ! -d $(FISTR) ]; then \
		git clone https://github.com/FrontISTR/FrontISTR.git $(FISTR); \
	fi

SCOTCH_LIBS = -L$(PREFIX)/$(SCOTCH)/lib -lptesmumps -lptscotch -lscotch -lptscotcherr
F90LDFLAGS = $(SCOTCH_LIBS) $(SCALAPACKLIB) $(LAPACKLIB) $(BLASLIB) $(OMPFLAGS) $(LIBSTDCXX)

$(PREFIX)/.frontistr: $(FISTR)
	(cd $(FISTR); git checkout -B next origin/next)
	perl get_ml_libs.pl $(PREFIX)/$(TRILINOS)/lib/cmake/ML/MLConfig.cmake > $(PREFIX)/.ml_libs
	perl -pe \
	"s!%metis_dir%!$(PREFIX)/$(PARMETIS)!; \
	s!%refiner_dir%!$(PREFIX)/$(REFINER)!; \
	s!%coupler_dir%!$(PREFIX)/$(COUPLER)!; \
	s!%mumps_dir%!$(PREFIX)/$(MUMPS)!; \
	s!%trilinos_dir%!$(PREFIX)/$(TRILINOS)!; \
	s!%ml_libs%!`cat $(PREFIX)/.ml_libs`!; \
	s!%mpicc%!$(MPICC)!; \
	s!%cflags%!$(OMPFLAGS)!; \
	s!%ldflags%!$(OMPFLAGS) $(LIBSTDCXX)!; \
	s!%coptflags%!$(CFLAGS)!; \
	s!%clinker%!$(CLINKER)!; \
	s!%mpicxx%!$(MPICXX)!; \
	s!%mpif90%!$(MPIF90)!; \
	s!%f90ldflags%!$(F90LDFLAGS)!; \
	s!%f90flags%!$(OMPFLAGS)!; \
	s!%f90optflags%!$(FCFLAGS)!; \
	s!%fpp%!$(F90FPPFLAG)!; \
	s!%f90linker%!$(F90LINKER)!;" \
	FrontISTR_Makefile.conf > $(FISTR)/Makefile.conf
	(cd $(FISTR) && \
	./setup.sh -p --with-tools --with-metis --with-parmetis --with-mumps --with-ml --with-lapack && \
	(cd hecmw1 && make) && (cd fistr1 && make) && \
	if [ ! -d $(PREFIX)/$(FISTR)/bin ]; then mkdir -p $(PREFIX)/$(FISTR)/bin; fi && \
	cp hecmw1/bin/* fistr1/bin/* $(PREFIX)/$(FISTR)/bin/.)
	touch $@

frontistr: $(PREFIX)/.frontistr


clean:
	rm -f $(TARGET)
	if [ -d $(OPENMPI) ]; then \
		rm -rf $(OPENMPI)/build; \
	fi
	if [ -d $(MPICH) ]; then \
		rm -rf $(MPICH)/build; \
	fi
	if [ -d $(OPENBLAS) ]; then \
		(cd $(OPENBLAS) && make clean); \
	fi
	if [ -d $(ATLAS) ]; then \
		rm -rf $(ATLAS)/build; \
	fi
	if [ -d $(SCALAPACK) ]; then \
		rm -rf $(SCALAPACK)/build; \
	fi
	if [ -d $(METIS) ]; then \
		(cd $(METIS) && make distclean); \
	fi
	if [ -d $(PARMETIS) ]; then \
		(cd $(PARMETIS) && make distclean); \
	fi
	if [ -d $(SCOTCH) ]; then \
		(cd $(SCOTCH)/src && make clean); \
	fi
	if [ -d $(MUMPS) ]; then \
		(cd $(MUMPS) && make clean); \
	fi
	if [ -d $(TRILINOS)-Source ]; then \
		rm -rf $(TRILINOS)-Source/build; \
	fi

distclean:
	rm -f $(PKG_DIRS)
	rm -rf $(PREFIX)
