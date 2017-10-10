include Makefile.in

BUILD_TYPE ?= RELEASE
INTELDIR ?= /opt/intel
NJOBS ?= 1


TOPDIR = $(CURDIR)

$(info COMPILER is $(COMPILER))
$(info MPI is $(MPI))
$(info BLASLAPACK is $(BLASLAPACK))


CMAKE     = cmake-3.9.1
OPENMPI   = openmpi-2.1.0
MPICH     = mpich-3.2
OPENBLAS  = OpenBLAS-0.2.19
ATLAS     = atlas3.10.3
SCALAPACK = scalapack-2.0.2
METIS     = metis-5.1.0
PARMETIS  = parmetis-4.0.3
SCOTCH    = scotch_6.0.4
MUMPS     = MUMPS_5.1.1
ifeq ($(COMPILER), FUJITSU)
  TRILINOS  = trilinos-12.6.4
else
  TRILINOS  = trilinos-12.10.1
endif
FISTR     = FrontISTR


PACKAGES =
PKG_DIRS =
TARGET =


# set PREFIX
ifeq ($(COMPILER), FUJITSU)
  PREFIX = $(TOPDIR)/$(COMPILER)
else
  # detect SYSTEM MPI
  ifneq ("$(shell mpicc -v 2> /dev/null | grep 'Intel(R) MPI')", "")
    $(info SYSTEM MPI is IntelMPI)
    SYSTEM_MPI = IMPI
  else
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
  endif

  ifeq ($(MPI), $(SYSTEM_MPI))
    DOWNLOAD_MPI ?= false
  else
    ifeq ($(MPI), IMPI)
      $(error Intel MPI not found in PATH)
    else
      DOWNLOAD_MPI = true
    endif
  endif
  $(info DOWNLOAD_MPI is $(DOWNLOAD_MPI))

  PREFIX = $(TOPDIR)/$(COMPILER)_$(MPI)
endif


# detect SYSTEM CMAKE
CMAKE_MINVER_MAJOR = 2
CMAKE_MINVER_MINOR = 8

export PATH := $(PREFIX)/$(CMAKE)/bin:$(PATH)

CMAKE_VER_MAJOR = $(shell PATH=$(PATH) cmake --version | perl -ne 'if(/cmake version/){s/cmake version //; s/\.\d+\.\d+.*//;print;}')
CMAKE_VER_MINOR = $(shell PATH=$(PATH) cmake --version | perl -ne 'if(/cmake version/){s/cmake version \d+\.//; s/\.\d+.*//;print;}')
CMAKE_VER_PATCH = $(shell PATH=$(PATH) cmake --version | perl -ne 'if(/cmake version/){s/cmake version \d+\.\d+\.//; print;}')

DOWNLOAD_CMAKE = true
ifneq ($(CMAKE_VER_MAJOR), "")
  $(info cmake-$(CMAKE_VER_MAJOR).$(CMAKE_VER_MINOR).$(CMAKE_VER_PATCH) detected)
  ifeq ("$(shell [ $(CMAKE_VER_MAJOR) -eq $(CMAKE_MINVER_MAJOR) ] && echo true)", "true")
    ifeq ("$(shell [ $(CMAKE_VER_MINOR) -ge $(CMAKE_MINVER_MINOR) ] && echo true)", "true")
      $(info SYSTEM CMAKE satisfies minimum required version $(CMAKE_MINVER_MAJOR).$(CMAKE_MINVER_MINOR))
      DOWNLOAD_CMAKE = false
    endif
  endif
  ifeq ("$(shell [ $(CMAKE_VER_MAJOR) -gt $(CMAKE_MINVER_MAJOR) ] && echo true)", "true")
    $(info SYSTEM CMAKE satisfies minimum required version $(CMAKE_MINVER_MAJOR).$(CMAKE_MINVER_MINOR))
    DOWNLOAD_CMAKE = false
  endif
endif
$(info DOWNLOAD_CMAKE is $(DOWNLOAD_CMAKE))
ifeq ($(DOWNLOAD_CMAKE), true)
  $(info SYSTEM CMAKE is older than minimum required version $(CMAKE_MINVER_MAJOR).$(CMAKE_MINVER_MINOR))
  PACKAGES = $(CMAKE).tar.gz
  PKG_DIRS = $(CMAKE)
  TARGET = $(PREFIX)/.cmake
endif


ifeq ($(COMPILER), INTEL)
  CC = icc
  CXX = icpc
  FC = ifort
  ifeq ($(BUILD_TYPE), RELEASE)
    CFLAGS = -O3 -xHost
    CXXFLAGS = -O3 -xHost
    FCFLAGS = -O3 -xHost
  else
    CFLAGS = -O0 -g -traceback
    CXXFLAGS = -O0 -g -traceback
    FCFLAGS = -O0 -g -CB -CU -traceback
  endif
  OMPFLAGS = -qopenmp
  NOFOR_MAIN = -nofor_main
  ifeq ($(BLASLAPACK), MKL)
    BLASLIB = -lmkl_intel_lp64 -lmkl_intel_thread -lmkl_core -liomp5
    LAPACKLIB = -lmkl_intel_lp64 -lmkl_intel_thread -lmkl_core -liomp5
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
        ifeq ($(BLASLAPACK), SYSTEM)
          BLASLIB ?= -lblas
          LAPACKLIB ?= -llapack
          SCALAPACKLIB ?= -lscalapack
        else
          $(error unsupported BLASLAPACK: $(BLASLAPACK))
        endif
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
      MPI_INST = $(PREFIX)/.openmpi
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
      LIBSTDCXX = -lmpi_cxx
    else
      ifeq ($(MPI), MPICH)
        MPI_INST = $(PREFIX)/.mpich
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
  LIBSTDCXX += -lstdc++
  CLINKER = $(MPICC)
  F90LINKER = $(MPIF90)
  F90FPPFLAG = -fpp
  SCOTCH_MAKEFILE_INC = Makefile.inc.x86-64_pc_linux2.icc
endif
ifeq ($(COMPILER), GCC)
  CC = gcc
  CXX = g++
  FC = gfortran
  ifeq ($(BUILD_TYPE), RELEASE)
    CFLAGS = -O3 -mtune=native
    CXXFLAGS = -O3 -mtune=native
    FCFLAGS = -O3 -mtune=native
  else
    CFLAGS = -O0 -g
    CXXFLAGS = -O0 -g
    FCFLAGS = -O0 -g
  endif
  OMPFLAGS = -fopenmp
  NOFOR_MAIN =
  ifeq ($(BLASLAPACK), MKL)
    MKLROOT = $(INTELDIR)/mkl
    BLASLIB = -Wl,--start-group \
	${MKLROOT}/lib/intel64/libmkl_gf_lp64.a \
	${MKLROOT}/lib/intel64/libmkl_gnu_thread.a \
	${MKLROOT}/lib/intel64/libmkl_core.a \
	-Wl,--end-group -lgomp -ldl
    LAPACKLIB = -Wl,--start-group \
	${MKLROOT}/lib/intel64/libmkl_gf_lp64.a \
	${MKLROOT}/lib/intel64/libmkl_gnu_thread.a \
	${MKLROOT}/lib/intel64/libmkl_core.a \
	${MKLROOT}/lib/intel64/libmkl_blacs_openmpi_lp64.a \
	-Wl,--end-group -lgomp -ldl
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
        ifeq ($(BLASLAPACK), SYSTEM)
          BLASLIB ?= -lblas
          LAPACKLIB ?= -llapack
          SCALAPACKLIB ?= -lscalapack
        else
          $(error unsupported BLASLAPACK: $(BLASLAPACK))
        endif
      endif
    endif
  endif
  MPICC = mpicc
  MPICXX = mpicxx
  MPIF90 = mpif90
  MPIEXEC = mpiexec
  ifeq ($(MPI), IMPI)
    ifeq ($(BLASLAPACK), MKL)
      SCALAPACKLIB = \
	${MKLROOT}/lib/intel64/libmkl_scalapack_lp64.a \
	${MKLROOT}/lib/intel64/libmkl_blacs_intelmpi_lp64.a
    endif
  else
    ifeq ($(MPI), OpenMPI)
      ifeq ($(DOWNLOAD_MPI), true)
        MPI_INST = $(PREFIX)/.openmpi
        MPICC = $(PREFIX)/$(OPENMPI)/bin/mpicc
        MPICXX = $(PREFIX)/$(OPENMPI)/bin/mpicxx
        MPIF90 = $(PREFIX)/$(OPENMPI)/bin/mpif90
        MPIEXEC = $(PREFIX)/$(OPENMPI)/bin/mpiexec
        PACKAGES += $(OPENMPI).tar.bz2
        PKG_DIRS += $(OPENMPI)
        TARGET += $(PREFIX)/.openmpi
      endif
      ifeq ($(BLASLAPACK), MKL)
        SCALAPACKLIB = \
		${MKLROOT}/lib/intel64/libmkl_scalapack_lp64.a \
		${MKLROOT}/lib/intel64/libmkl_blacs_openmpi_lp64.a
      endif
      LIBSTDCXX = -lmpi_cxx
    else
      ifeq ($(MPI), MPICH)
        ifeq ($(DOWNLOAD_MPI), true)
          MPI_INST = $(PREFIX)/.mpich
          MPICC = $(PREFIX)/$(MPICH)/bin/mpicc
          MPICXX = $(PREFIX)/$(MPICH)/bin/mpicxx
          MPIF90 = $(PREFIX)/$(MPICH)/bin/mpif90
          MPIEXEC = $(PREFIX)/$(MPICH)/bin/mpiexec
          PACKAGES += $(MPICH).tar.gz
          PKG_DIRS += $(MPICH)
          TARGET += $(PREFIX)/.mpich
        endif
        ifeq ($(BLASLAPACK), MKL)
          SCALAPACKLIB = \
		${MKLROOT}/lib/intel64/libmkl_scalapack_lp64.a \
		${MKLROOT}/lib/intel64/libmkl_blacs_intelmpi_lp64.a
        endif
      else
        $(error unsupported MPI: $(MPI))
      endif
    endif
  endif
  LIBSTDCXX += -lstdc++
  CLINKER = $(MPICC)
  F90LINKER = $(MPIF90)
  F90FPPFLAG = -cpp
  SCOTCH_MAKEFILE_INC = Makefile.inc.x86-64_pc_linux2
endif
ifeq ($(COMPILER), FUJITSU)
  CC = fcc
  CXX = FCC
  FC = frt
  ifeq ($(BUILD_TYPE), RELEASE)
    CFLAGS = -Kfast -Xg
    CXXFLAGS = -Kfast -Xg
    FCFLAGS = -Kfast
  else
    CFLAGS = -O0 -Xg
    CXXFLAGS = -O0 -Xg
    FCFLAGS = -O0 -Xg
  endif
  OMPFLAGS = -Kopenmp
  #NOFOR_MAIN = -mlcmain=main
  NOFOR_MAIN =
  NOFOR_MAIN_C = -DMAIN_COMP
  ifneq ($(BLASLAPACK), FUJITSU)
    $(warning forced to use FUJITSU BLASLAPACK)
    BLASLAPACK = FUJITSU
  endif
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
  F90FPPFLAG = -Cpp -Cfpp
  SCALAPACKLIB = -SCALAPACK
  SCOTCH_MAKEFILE_INC = Makefile.inc.x86-64_pc_linux2
endif

ifeq ("$(shell uname)", "Darwin")
  SCOTCH_MAKEFILE_INC = Makefile.inc.i686_mac_darwin10
endif

PACKAGES += $(METIS).tar.gz $(PARMETIS).tar.gz $(SCOTCH).tar.gz $(MUMPS).tar.gz $(TRILINOS)-Source.tar.bz2
PKG_DIRS += $(METIS) $(PARMETIS) $(SCOTCH) $(MUMPS) $(TRILINOS)-Source
TARGET += $(PREFIX) $(PREFIX)/.metis $(PREFIX)/.parmetis $(PREFIX)/.scotch $(PREFIX)/.mumps $(PREFIX)/.trilinos $(PREFIX)/.frontistr

$(info TARGET is $(TARGET))

all: $(TARGET)
.PHONY: all

download: $(PACKAGES)
.PHONY: download

extract: $(PKG_DIRS)
.PHONY: extract


$(PREFIX):
	if [ ! -d $(PREFIX) ]; then mkdir -p $(PREFIX); fi


$(CMAKE).tar.gz:
	wget https://cmake.org/files/v3.9/$(CMAKE).tar.gz

$(CMAKE): $(CMAKE).tar.gz
	rm -rf $@
	tar zxvf $(CMAKE).tar.gz
	touch $@

$(PREFIX)/.cmake: $(CMAKE)
	(cd $(CMAKE) && ./bootstrap --parallel=$(NJOBS) --prefix=$(PREFIX)/$(CMAKE) && make -j $(NJOBS) && make install)

cmake: $(PREFIX)/.cmake
.PHONY: cmake


$(OPENMPI).tar.bz2:
	wget https://www.open-mpi.org/software/ompi/v2.1/downloads/$(OPENMPI).tar.bz2

$(OPENMPI): $(OPENMPI).tar.bz2
	rm -rf $@
	tar jxvf $(OPENMPI).tar.bz2
	touch $@

$(PREFIX)/.openmpi: $(OPENMPI)
	(cd $(OPENMPI); mkdir build; cd build; \
	../configure CC=$(CC) CXX=$(CXX) F77=$(FC) FC=$(FC) \
	CFLAGS="$(CFLAGS)" CXXFLAGS="$(CXXFLAGS)" FFLAGS="$(FCFLAGS)" FCFLAGS="$(FCFLAGS)" \
	--prefix=$(PREFIX)/$(OPENMPI); \
	make -j $(NJOBS); make install)
	touch $@

openmpi: $(PREFIX)/.openmpi
.PHONY: openmpi


$(MPICH).tar.gz:
	wget http://www.mpich.org/static/downloads/3.2/$(MPICH).tar.gz

$(MPICH): $(MPICH).tar.gz
	rm -rf $@
	tar zxvf $(MPICH).tar.gz
	touch $@

$(PREFIX)/.mpich: $(MPICH)
	(cd $(MPICH); mkdir build; cd build; \
	../configure CC=$(CC) CXX=$(CXX) F77=$(FC) FC=$(FC) --enable-fast=all \
	MPICHLIB_CFLAGS="$(CFLAGS)" MPICHLIB_FFLAGS="$(FCFLAGS)" \
	MPICHLIB_CXXFLAGS="$(CXXFLAGS)" MPICHLIB_FCFLAGS="$(FCFLAGS)" \
	-prefix=$(PREFIX)/$(MPICH); \
	make -j $(NJOBS); make install)
	touch $@

mpich: $(PREFIX)/.mpich
.PHONY: mpich


$(OPENBLAS).tar.gz:
	wget http://github.com/xianyi/OpenBLAS/archive/v0.2.19.tar.gz
	mv v0.2.19.tar.gz $@

$(OPENBLAS): $(OPENBLAS).tar.gz
	rm -rf $@
	tar zxvf $(OPENBLAS).tar.gz
	touch $@

$(PREFIX)/.openblas: $(OPENBLAS)
	(cd $(OPENBLAS); make USE_OPENMP=1 NO_SHARED=1 CC=$(CC) FC=$(FC); make install NO_SHARED=1 PREFIX=$(PREFIX)/$(OPENBLAS))
	touch $@

openblas: $(PREFIX)/.openblas
.PHONY: openblas


$(ATLAS).tar.bz2:
	wget https://downloads.sourceforge.net/project/math-atlas/Stable/3.10.3/$(ATLAS).tar.bz2

lapack-3.7.0.tgz:
	wget http://www.netlib.org/lapack/lapack-3.7.0.tgz

$(ATLAS): $(ATLAS).tar.bz2
	rm -rf $@
	tar jxvf $(ATLAS).tar.bz2
	mv ATLAS $@
	touch $@

$(PREFIX)/.atlas: $(ATLAS) lapack-3.7.0.tgz
	(cd $(ATLAS); mkdir build; cd build; \
	../configure --with-netlib-lapack-tarfile=$(TOPDIR)/lapack-3.7.0.tgz \
	-Si omp 1 -F alg $(OMPFLAGS) --prefix=$(PREFIX)/$(ATLAS); \
	make build; make install)
	touch $@

# to force change compiler, add the following to configure option
#	-C ac $(CC) -C if $(FC) \
# to force change compiler flags, add the following to configure option
#	-F ac "$(CFLAGS)" -F if "$(FCFLAGS)" \

atlas: $(PREFIX)/.atlas
.PHONY: atlas


$(SCALAPACK).tgz:
	wget http://www.netlib.org/scalapack/$(SCALAPACK).tgz

$(SCALAPACK): $(SCALAPACK).tgz
	rm -rf $@
	tar zxvf $(SCALAPACK).tgz
	touch $@

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

$(PREFIX)/.scalapack: $(SCALAPACK) $(MPI_INST)
	(cd $(SCALAPACK); mkdir build; cd build; \
	cmake $(SCALAPACK_CMAKE_OPTS) ..; \
	make -j $(NJOBS); \
	make install)
	touch $@

scalapack: $(PREFIX)/.scalapack
.PHONY: scalapack


$(METIS).tar.gz:
	wget http://glaros.dtc.umn.edu/gkhome/fetch/sw/metis/$(METIS).tar.gz

$(METIS): $(METIS).tar.gz
	rm -rf $@
	tar zxvf $(METIS).tar.gz
	touch $@

$(PREFIX)/.metis: $(METIS)
	(cd $(METIS) && make config prefix=$(PREFIX)/$(PARMETIS) cc=$(CC) && \
	make --no-print-directory -j $(NJOBS) install)
	touch $@

metis: $(PREFIX)/.metis
.PHONY: metis


$(PARMETIS).tar.gz:
	wget http://glaros.dtc.umn.edu/gkhome/fetch/sw/parmetis/$(PARMETIS).tar.gz

$(PARMETIS): $(PARMETIS).tar.gz
	rm -rf $@
	tar zxvf $(PARMETIS).tar.gz
	touch $@

$(PREFIX)/.parmetis: $(PARMETIS) $(MPI_INST)
	(cd $(PARMETIS) && make config prefix=$(PREFIX)/$(PARMETIS) cc=$(MPICC) cxx=$(MPICXX) && \
	make --no-print-directory -j $(NJOBS) install)
	touch $@

parmetis: $(PREFIX)/.parmetis
.PHONY: parmetis


$(SCOTCH).tar.gz:
	wget https://gforge.inria.fr/frs/download.php/file/34618/$(SCOTCH).tar.gz

$(SCOTCH): $(SCOTCH).tar.gz
	rm -rf $@
	tar zxvf $(SCOTCH).tar.gz
	touch $@

$(PREFIX)/.scotch: $(SCOTCH) $(MPI_INST)
	perl -pe \
	"if(/^CCS/){s!= .*!= $(CC)!;} \
	elsif(/^CCP/){s!= .*!= $(MPICC)!;} \
	elsif(/^CCD/){s!= .*!= $(MPICC)!;} \
	elsif(/^CFLAGS/){s!-O3!$(CFLAGS)!; s!-DSCOTCH_PTHREAD!!;}" \
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
.PHONY: scotch


$(MUMPS).tar.gz:
	wget http://mumps.enseeiht.fr/$(MUMPS).tar.gz

$(MUMPS): $(MUMPS).tar.gz
	rm -rf $@
	tar zxvf $(MUMPS).tar.gz
	touch $@

MUMPS_DEPS = $(MUMPS) $(PREFIX)/.metis $(PREFIX)/.parmetis $(PREFIX)/.scotch
ifeq ($(BLASLAPACK), OpenBLAS)
MUMPS_DEPS += $(PREFIX)/.scalapack
endif
ifeq ($(BLASLAPACK), ATLAS)
MUMPS_DEPS += $(PREFIX)/.scalapack
endif

$(PREFIX)/.mumps: $(MUMPS_DEPS)
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
	s!%cflags%!$(CFLAGS) $(NOFOR_MAIN_C) $(OMPFLAGS)!;" \
	MUMPS_Makefile.inc > $(MUMPS)/Makefile.inc  ### to be fixed
	(cd $(MUMPS) && make -j $(NJOBS) && \
	if [ ! -d $(PREFIX)/$(MUMPS) ]; then mkdir $(PREFIX)/$(MUMPS); fi && \
	cp -r lib include $(PREFIX)/$(MUMPS)/.)
	touch $@


mumps: $(PREFIX)/.mumps
.PHONY: mumps


$(TRILINOS)-Source.tar.bz2:
	wget http://trilinos.csbsju.edu/download/files/$(TRILINOS)-Source.tar.bz2

$(TRILINOS)-Source: $(TRILINOS)-Source.tar.bz2
	rm -rf $@
	tar jxvf $(TRILINOS)-Source.tar.bz2
	touch $@

TRILINOS_CMAKE_OPTS = \
	-D Trilinos_ENABLE_ALL_OPTIONAL_PACKAGES=OFF \
	-D CMAKE_BUILD_TYPE=$(BUILD_TYPE) \
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
    else
      ifeq ($(BLASLAPACK), FUJITSU)
TRILINOS_CMAKE_OPTS += \
	-D TPL_BLAS_LIBRARIES:STRING="-SSL2" \
	-D TPL_LAPACK_LIBRARIES:STRING="-SSL2"
      endif
    endif
  endif
endif

$(PREFIX)/.trilinos: $(TRILINOS)-Source $(PREFIX)/.metis $(PREFIX)/.parmetis $(PREFIX)/.scotch $(PREFIX)/.mumps
	(cd $(TRILINOS)-Source; mkdir build; cd build; \
	cmake $(TRILINOS_CMAKE_OPTS) ..; \
	make -j $(NJOBS); \
	make install)
	touch $@

trilinos: $(PREFIX)/.trilinos
.PHONY: trilinos


$(FISTR):
	if [ ! -d $(FISTR) ]; then \
		git clone https://github.com/FrontISTR/FrontISTR.git $(FISTR); \
	fi

SCOTCH_LIBS = -L$(PREFIX)/$(SCOTCH)/lib -lptesmumps -lptscotch -lscotch -lptscotcherr
F90LDFLAGS = $(SCOTCH_LIBS) $(SCALAPACKLIB) $(LAPACKLIB) $(BLASLIB) $(OMPFLAGS) $(LIBSTDCXX)

ifeq ($(fistrbuild), old)
$(PREFIX)/.frontistr: $(FISTR) $(PREFIX)/.metis $(PREFIX)/.parmetis $(PREFIX)/.mumps $(PREFIX)/.trilinos
	perl -pe \
	"s!%metis_dir%!$(PREFIX)/$(PARMETIS)!; \
	s!%refiner_dir%!$(PREFIX)/$(REFINER)!; \
	s!%coupler_dir%!$(PREFIX)/$(COUPLER)!; \
	s!%mumps_dir%!$(PREFIX)/$(MUMPS)!; \
	s!%trilinos_dir%!$(PREFIX)/$(TRILINOS)!; \
	s!%ml_libs%!`perl get_ml_libs.pl $(PREFIX)/$(TRILINOS)/lib/cmake/ML/MLConfig.cmake`!; \
	s!%mpicc%!$(MPICC)!; \
	s!%cflags%!$(OMPFLAGS)!; \
	s!%ldflags%!$(OMPFLAGS) -lm $(LIBSTDCXX)!; \
	s!%coptflags%!$(CFLAGS)!; \
	s!%clinker%!$(CLINKER)!; \
	s!%mpicxx%!$(MPICXX)!; \
	s!%mpif90%!$(MPIF90)!; \
	s!%f90ldflags%!$(F90LDFLAGS)!; \
	s!%f90flags%!$(OMPFLAGS) $(NOFOR_MAIN)!; \
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
	echo Build completed.
	echo Commands (fistr1, hecmw_part1, etc.) are located in $(PREFIX)/$(FISTR)/bin.
	echo Please add $(PREFIX)/$(FISTR)/bin to your PATH environment variable (or copy files in $(PREFIX)/$(FISTR)/bin to one of the directories in your PATH environment variable).
else
FISTR_CMAKE_OPTS = \
	-D CMAKE_BUILD_TYPE=$(BUILD_TYPE) \
	-D CMAKE_C_COMPILER=$(MPICC) \
	-D CMAKE_C_FLAGS="$(CFLAGS)" \
	-D CMAKE_CXX_COMPILER=$(MPICXX) \
	-D CMAKE_CXX_FLAGS="$(CFLAGS)" \
	-D CMAKE_Fortran_COMPILER=$(MPIF90) \
	-D CMAKE_Fortran_FLAGS="$(FCFLAGS) $(OMPFLAGS)" \
	-D WITH_TOOLS=1 \
	-D WITH_MPI=1 \
	-D WITH_OPENMP=1 \
	-D WITH_REFINER=0 \
	-D WITH_REVOCAP=0 \
	-D WITH_METIS=1 \
	-D METIS_INCLUDE_PATH=$(PREFIX)/$(PARMETIS)/include \
	-D METIS_LIBRARIES=$(PREFIX)/$(PARMETIS)/lib/libmetis.a \
	-D WITH_PARMETIS=1 \
	-D PARMETIS_INCLUDE_PATH=$(PREFIX)/$(PARMETIS)/include \
	-D PARMETIS_LIBRARIES=$(PREFIX)/$(PARMETIS)/lib/libparmetis.a \
	-D WITH_LAPACK=1 \
	-D WITH_MUMPS=1 \
	-D MUMPS_INCLUDE_PATH=$(PREFIX)/$(MUMPS)/include \
	-D MUMPS_LIBRARIES="$(PREFIX)/$(MUMPS)/lib/libdmumps.a;$(PREFIX)/$(MUMPS)/lib/libmumps_common.a;$(PREFIX)/$(MUMPS)/lib/libpord.a;$(PREFIX)/$(SCOTCH)/lib/libptesmumps.a;$(PREFIX)/$(SCOTCH)/lib/libptscotch.a;$(PREFIX)/$(SCOTCH)/lib/libptscotcherr.a;$(PREFIX)/$(SCOTCH)/lib/libscotch.a" \
	-D WITH_ML=1 \
	-D CMAKE_PREFIX_PATH=$(PREFIX)/$(TRILINOS) \
	-D WITH_DOC=0 \
	-D CMAKE_INSTALL_PREFIX=$(PREFIX)/$(FISTR)

ifeq ($(BLASLAPACK), OpenBLAS)
FISTR_CMAKE_OPTS += \
	-D BLAS_LIBRARIES=$(PREFIX)/$(OPENBLAS)/lib/libopenblas.a \
	-D LAPACK_LIBRARIES=$(PREFIX)/$(OPENBLAS)/lib/libopenblas.a
else
  ifeq ($(BLASLAPACK), ATLAS)
FISTR_CMAKE_OPTS += \
	-D BLAS_LIBRARIES="$(PREFIX)/$(ATLAS)/lib/libptf77blas.a;$(PREFIX)/$(ATLAS)/lib/libatlas.a" \
	-D LAPACK_LIBRARIES="$(PREFIX)/$(ATLAS)/lib/libptlapack.a;$(PREFIX)/$(ATLAS)/lib/libptf77blas.a;$(PREFIX)/$(ATLAS)/lib/libptcblas.a;$(PREFIX)/$(ATLAS)/lib/libatlas.a"
  else
    ifeq ($(BLASLAPACK), MKL)
FISTR_CMAKE_OPTS += \
	-D WITH_MKL=1 \
	-D BLA_VENDOR="Intel10_64lp"
    else
      ifeq ($(BLASLAPACK), FUJITSU)
FISTR_CMAKE_OPTS += \
	-D CMAKE_Fortran_MODDIR_FLAG=-M \
	-D BLAS_LIBRARIES=-SSL2BLAMP \
	-D LAPACK_LIBRARIES=-SSL2BLAMP \
	-D SCALAPACK_LIBRARIES=-SCALAPACK \
	-D OpenMP_C_FLAGS=$(OMPFLAGS) \
	-D OpenMP_CXX_FLAGS=$(OMPFLAGS) \
	-D OpenMP_Fortran_FLAGS=$(OMPFLAGS)
      else
FISTR_CMAKE_OPTS += \
	-D BLAS_LIBRARIES=$(BLASLIB) \
	-D LAPACK_LIBRARIES=$(LAPACKLIB) \
	-D SCALAPACK_LIBRARIES=$(SCALAPACKLIB)
      endif
    endif
  endif
endif

$(PREFIX)/.frontistr: $(FISTR) $(PREFIX)/.metis $(PREFIX)/.parmetis $(PREFIX)/.mumps $(PREFIX)/.trilinos
	(cd $(FISTR); mkdir build; cd build; cmake --version; \
	cmake $(FISTR_CMAKE_OPTS) ..; \
	make -j $(NJOBS); \
	make install)
	touch $@
	echo Build completed.
	echo Commands (fistr1, hecmw_part1, etc.) are located in $(PREFIX)/$(FISTR)/bin.
	echo Please add $(PREFIX)/$(FISTR)/bin to your PATH environment variable (or copy files in $(PREFIX)/$(FISTR)/bin to one of the directories in your PATH environment variable).
endif

frontistr: $(PREFIX)/.frontistr
.PHONY: frontistr


env2-code:
	if [ ! -d $@ ]; then \
		git clone https://git.code.sf.net/p/env2/code $@; \
	fi

$(PREFIX)/bashrc:
ifeq ($(MPI), OpenMPI)
	perl -pe 's!%mpidir%!$(PREFIX)/$(OPENMPI)!;' bashrc.template > $(PREFIX)/bashrc
else
  ifeq ($(MPI), MPICH)
	perl -pe 's!%mpidir%!$(PREFIX)/$(MPICH)!;' bashrc.template > $(PREFIX)/bashrc
  endif
endif

$(PREFIX)/modulefile: env2-code $(PREFIX)/bashrc
	echo "#%Module" > $@
	perl env2-code/env2 -from bash -to modulecmd $(PREFIX)/bashrc >> $@

modulefile: $(PREFIX)/modulefile
.PHONY: modulefile


clean:
	rm -f $(TARGET)
	if [ -d $(OPENMPI) ]; then \
		rm -rf $(OPENMPI)/build; \
		rm -f $(PREFIX)/.openmpi; \
	fi
	if [ -d $(MPICH) ]; then \
		rm -rf $(MPICH)/build; \
		rm -f $(PREFIX)/.mpich; \
	fi
	if [ -d $(OPENBLAS) ]; then \
		(cd $(OPENBLAS) && make clean); \
		rm -f $(PREFIX)/.openblas; \
	fi
	if [ -d $(ATLAS) ]; then \
		rm -rf $(ATLAS)/build; \
		rm -f $(PREFIX)/.atlas; \
	fi
	if [ -d $(SCALAPACK) ]; then \
		rm -rf $(SCALAPACK)/build; \
		rm -f $(PREFIX)/.scalapack; \
	fi
	if [ -d $(METIS) ]; then \
		(cd $(METIS) && make distclean); \
		rm -f $(PREFIX)/.metis; \
	fi
	if [ -d $(PARMETIS) ]; then \
		(cd $(PARMETIS) && make distclean); \
		rm -f $(PREFIX)/.parmetis; \
	fi
	if [ -d $(SCOTCH) ]; then \
		(cd $(SCOTCH)/src && make realclean); \
		rm -f $(PREFIX)/.scotch; \
	fi
	if [ -d $(MUMPS) ]; then \
		(cd $(MUMPS) && make clean); \
		rm -f $(PREFIX)/.mumps; \
	fi
	if [ -d $(TRILINOS)-Source ]; then \
		rm -rf $(TRILINOS)-Source/build; \
		rm -f $(PREFIX)/.trilinos; \
	fi
	if [ -d $(FISTR) ]; then \
		(cd $(FISTR); make clean); \
		rm -f $(PREFIX)/.fistr; \
	fi
.PHONY: clean

distclean:
	rm -rf $(CMAKE) $(OPENMPI) $(MPICH) $(OPENBLAS) $(ATLAS) $(SCALAPACK) $(METIS) $(PARMETIS) $(SCOTCH) $(MUMPS) $(TRILINOS)-Source
	rm -rf $(PREFIX)
	if [ -d $(FISTR) ]; then \
		(cd $(FISTR); make distclean); \
		rm -f $(PREFIX)/.fistr; \
	fi
.PHONY: distclean
