include Makefile.in

##########################
### Parameter Settings ###
##########################

TOPDIR = $(CURDIR)

###
### Default values
###

BUILD_TYPE ?= RELEASE
NJOBS ?= 1

###
### Echo basic settings
###

$(info COMPILER is $(COMPILER))
$(info MPI is $(MPI))
$(info BLASLAPACK is $(BLASLAPACK))


###
### Package versions
###

CMAKE     = cmake-3.17.3
OPENMPI   = openmpi-4.0.4
MPICH     = mpich-3.3.2
OPENBLAS  = OpenBLAS-0.3.10
ATLAS     = atlas3.10.3
#LAPACK    = lapack-3.9.0
LAPACK    = lapack-3.8.0
SCALAPACK = scalapack-2.1.0
ifeq ($(metisversion), 4)
  METIS     = metis-4.0.3
  PARMETIS  = ParMetis-3.2.0
else
  METIS     = metis-5.1.0
  PARMETIS  = parmetis-4.0.3
endif
SCOTCH    = scotch_6.0.9
MUMPS     = MUMPS_5.3.3
ifeq ($(COMPILER), FUJITSU)
  TRILINOS  = trilinos-release-12-6-4
else
  TRILINOS  = trilinos-release-12-18-1
endif
REFINER   = REVOCAP_Refiner-1.1.04
FISTR     = FrontISTR


PACKAGES =
PKG_DIRS =
TARGET =

###
### set PREFIX
###

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

###
### detect SYSTEM CMAKE
###

DOWNLOAD_CMAKE = true
export PATH := $(PREFIX)/$(CMAKE)/bin:$(PATH)

ifeq ("$(shell PATH=$(PATH) which cmake)", "")
  $(info CMAKE not found)
else
  CMAKE_MINVER_MAJOR = 2
  CMAKE_MINVER_MINOR = 8
  CMAKE_MINVER_PATCH = 11
  CMAKE_MINVER=$(CMAKE_MINVER_MAJOR).$(CMAKE_MINVER_MINOR).$(CMAKE_MINVER_PATCH)

  CMAKE_VER_MAJOR = $(shell LANG=C PATH=$(PATH) cmake --version | perl -ne 'if(/cmake version/){s/cmake version //; s/\.\d+\.\d+.*//;print;}')
  CMAKE_VER_MINOR = $(shell LANG=C PATH=$(PATH) cmake --version | perl -ne 'if(/cmake version/){s/cmake version \d+\.//; s/\.\d+.*//;print;}')
  CMAKE_VER_PATCH = $(shell LANG=C PATH=$(PATH) cmake --version | perl -ne 'if(/cmake version/){s/cmake version \d+\.\d+\.//; s/[^\d].*//; print;}')

  ifneq ($(CMAKE_VER_MAJOR), "")
    $(info cmake-$(CMAKE_VER_MAJOR).$(CMAKE_VER_MINOR).$(CMAKE_VER_PATCH) detected)
    ifeq ("$(shell [ $(CMAKE_VER_MAJOR) -eq $(CMAKE_MINVER_MAJOR) ] && echo true)", "true")
      ifeq ("$(shell [ $(CMAKE_VER_MINOR) -eq $(CMAKE_MINVER_MINOR) ] && echo true)", "true")
        ifeq ("$(shell [ $(CMAKE_VER_PATCH) -ge $(CMAKE_MINVER_PATCH) ] && echo true)", "true")
          DOWNLOAD_CMAKE = false
        endif
      endif
      ifeq ("$(shell [ $(CMAKE_VER_MINOR) -gt $(CMAKE_MINVER_MINOR) ] && echo true)", "true")
        DOWNLOAD_CMAKE = false
      endif
    endif
    ifeq ("$(shell [ $(CMAKE_VER_MAJOR) -gt $(CMAKE_MINVER_MAJOR) ] && echo true)", "true")
      DOWNLOAD_CMAKE = false
    endif
  endif
  ifeq ($(DOWNLOAD_CMAKE), true)
    $(info SYSTEM CMAKE is older than minimum required version $(CMAKE_MINVER))
  endif
endif
$(info DOWNLOAD_CMAKE is $(DOWNLOAD_CMAKE))
ifeq ($(DOWNLOAD_CMAKE), true)
  PACKAGES = $(CMAKE).tar.gz
  PKG_DIRS = $(CMAKE)
  TARGET = cmake
else
  $(info SYSTEM CMAKE satisfies minimum required version $(CMAKE_MINVER))
endif

###
### Compiler, BLAS, LAPACK ScaLAPACK settings
###

ifeq ($(BLASLAPACK), MKL)
  ifeq ("$(MKLROOT)", "")
    $(error MKLROOT not set; please make sure the environment variables are correctly set)
  endif
endif

ifeq ($(COMPILER), INTEL)
  CC = icc
  CXX = icpc
  FC = ifort
  ifeq ($(BUILD_TYPE), RELEASE)
    CFLAGS = -O3
    CXXFLAGS = -O3
    FCFLAGS = -O3
  else
    CFLAGS = -O0 -g -traceback
    CXXFLAGS = -O0 -g -traceback
    FCFLAGS = -O0 -g -CB -CU -traceback
  endif
  IFORT_VER_MAJOR = $(shell LANG=C ifort -v 2>&1 | perl -pe 's/ifort version //;s/\.\d+\.\d+.*//;')
  $(info IFORT_VER_MAJOR is $(IFORT_VER_MAJOR))
  ifeq ("$(shell [ $(IFORT_VER_MAJOR) -ge 15 ] && echo true)", "true")
    OMPFLAGS = -qopenmp
  else
    OMPFLAGS = -openmp
  endif
  $(info OMPFLAGS is $(OMPFLAGS))
  NOFOR_MAIN = -nofor_main
  ifeq ($(BLASLAPACK), MKL)
    BLASLIB = -lmkl_intel_lp64 -lmkl_intel_thread -lmkl_core -liomp5
    LAPACKLIB = -lmkl_intel_lp64 -lmkl_intel_thread -lmkl_core -liomp5
  else
    ifeq ($(BLASLAPACK), OpenBLAS)
      PACKAGES += $(OPENBLAS).tar.gz $(SCALAPACK).tgz
      PKG_DIRS += $(OPENBLAS) $(SCALAPACK)
      TARGET += openblas scalapack
      BLASLIB = -L$(PREFIX)/$(OPENBLAS)/lib -lopenblas
      LAPACKLIB = -L$(PREFIX)/$(OPENBLAS)/lib -lopenblas
      SCALAPACKLIB = -L$(PREFIX)/$(SCALAPACK)/lib -lscalapack
    else
      ifeq ($(BLASLAPACK), ATLAS)
        PACKAGES += $(ATLAS).tar.bz2 $(LAPACK).tar.gz $(SCALAPACK).tgz
        PKG_DIRS += $(ATLAS) $(SCALAPACK)
        TARGET += atlas scalapack
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
  MPIF90 = mpifort
  MPIEXEC = mpiexec
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
      ifeq ($(DOWNLOAD_MPI), true)
        MPI_INST = openmpi
        MPICC = $(PREFIX)/$(OPENMPI)/bin/mpicc
        MPICXX = $(PREFIX)/$(OPENMPI)/bin/mpicxx
        MPIF90 = $(PREFIX)/$(OPENMPI)/bin/mpifort
        MPIEXEC = $(PREFIX)/$(OPENMPI)/bin/mpiexec
        PACKAGES += $(OPENMPI).tar.bz2
        PKG_DIRS += $(OPENMPI)
        TARGET += openmpi
      endif
      ifeq ($(BLASLAPACK), MKL)
        SCALAPACKLIB = -lmkl_scalapack_lp64 -lmkl_blacs_openmpi_lp64
      endif
      LIBSTDCXX = -lmpi_cxx
    else
      ifeq ($(MPI), MPICH)
        ifeq ($(DOWNLOAD_MPI), true)
          MPI_INST = mpich
          MPICC = $(PREFIX)/$(MPICH)/bin/mpicc
          MPICXX = $(PREFIX)/$(MPICH)/bin/mpicxx
          MPIF90 = $(PREFIX)/$(MPICH)/bin/mpifort
          MPIEXEC = $(PREFIX)/$(MPICH)/bin/mpiexec
          PACKAGES += $(MPICH).tar.gz
          PKG_DIRS += $(MPICH)
          TARGET += mpich
        endif
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
  GCC_VER = $(shell gcc -dumpversion)
  ifeq ($(GCC_VER), 10)
    FCFLAGS += -fallow-argument-mismatch
  endif
  OMPFLAGS = -fopenmp
  NOFOR_MAIN =
  ifeq ($(BLASLAPACK), MKL)
    # BLASLIB, LAPACKLIB, SCALAPACKLIB will be set later
  else
    ifeq ($(BLASLAPACK), OpenBLAS)
      PACKAGES += $(OPENBLAS).tar.gz $(SCALAPACK).tgz
      PKG_DIRS += $(OPENBLAS) $(SCALAPACK)
      TARGET += openblas scalapack
      BLASLIB = -L$(PREFIX)/$(OPENBLAS)/lib -lopenblas
      LAPACKLIB = -L$(PREFIX)/$(OPENBLAS)/lib -lopenblas
      SCALAPACKLIB = -L$(PREFIX)/$(SCALAPACK)/lib -lscalapack
    else
      ifeq ($(BLASLAPACK), ATLAS)
        PACKAGES += $(ATLAS).tar.bz2 $(LAPACK).tar.gz $(SCALAPACK).tgz
        PKG_DIRS += $(ATLAS) $(SCALAPACK)
        TARGET += atlas scalapack
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
  MPIF90 = mpifort
  MPIEXEC = mpiexec
  ifeq ($(MPI), IMPI)
    ifeq ($(BLASLAPACK), MKL)
      BLASLIB = -Wl,--start-group \
        ${MKLROOT}/lib/intel64/libmkl_scalapack_lp64.a \
        ${MKLROOT}/lib/intel64/libmkl_blacs_intelmpi_lp64.a \
        ${MKLROOT}/lib/intel64/libmkl_gf_lp64.a \
        ${MKLROOT}/lib/intel64/libmkl_gnu_thread.a \
        ${MKLROOT}/lib/intel64/libmkl_core.a \
        -Wl,--end-group -lgomp -ldl
      LAPACKLIB = $(BLASLIB)
      SCALAPACKLIB = $(BLASLIB)
    endif
  else
    ifeq ($(MPI), OpenMPI)
      ifeq ($(DOWNLOAD_MPI), true)
        MPI_INST = openmpi
        MPICC = $(PREFIX)/$(OPENMPI)/bin/mpicc
        MPICXX = $(PREFIX)/$(OPENMPI)/bin/mpicxx
        MPIF90 = $(PREFIX)/$(OPENMPI)/bin/mpifort
        MPIEXEC = $(PREFIX)/$(OPENMPI)/bin/mpiexec
        PACKAGES += $(OPENMPI).tar.bz2
        PKG_DIRS += $(OPENMPI)
        TARGET += openmpi
      endif
      ifeq ($(BLASLAPACK), MKL)
        BLASLIB = -Wl,--start-group \
          ${MKLROOT}/lib/intel64/libmkl_scalapack_lp64.a \
          ${MKLROOT}/lib/intel64/libmkl_blacs_openmpi_lp64.a \
          ${MKLROOT}/lib/intel64/libmkl_gf_lp64.a \
          ${MKLROOT}/lib/intel64/libmkl_gnu_thread.a \
          ${MKLROOT}/lib/intel64/libmkl_core.a \
          -Wl,--end-group -lgomp -ldl
        LAPACKLIB = $(BLASLIB)
        SCALAPACKLIB = $(BLASLIB)
      endif
      LIBSTDCXX = -lmpi_cxx
    else
      ifeq ($(MPI), MPICH)
        ifeq ($(DOWNLOAD_MPI), true)
          MPI_INST = mpich
          MPICC = $(PREFIX)/$(MPICH)/bin/mpicc
          MPICXX = $(PREFIX)/$(MPICH)/bin/mpicxx
          MPIF90 = $(PREFIX)/$(MPICH)/bin/mpifort
          MPIEXEC = $(PREFIX)/$(MPICH)/bin/mpiexec
          PACKAGES += $(MPICH).tar.gz
          PKG_DIRS += $(MPICH)
          TARGET += mpich
        endif
        ifeq ($(BLASLAPACK), MKL)
          BLASLIB = -Wl,--start-group \
            ${MKLROOT}/lib/intel64/libmkl_scalapack_lp64.a \
            ${MKLROOT}/lib/intel64/libmkl_blacs_intelmpi_lp64.a \
            ${MKLROOT}/lib/intel64/libmkl_gf_lp64.a \
            ${MKLROOT}/lib/intel64/libmkl_gnu_thread.a \
            ${MKLROOT}/lib/intel64/libmkl_core.a \
            -Wl,--end-group -lgomp -ldl
          LAPACKLIB = $(BLASLIB)
          SCALAPACKLIB = $(BLASLIB)
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

###
### Special settings for MAC
###

ifeq ("$(shell uname)", "Darwin")
  SCOTCH_MAKEFILE_INC = Makefile.inc.i686_mac_darwin10
endif

###
### External packages and targets
###

ifneq ($(metisversion), 4)
  PACKAGES += $(METIS).tar.gz
  PKG_DIRS += $(METIS)
  TARGET += metis
endif
PACKAGES += $(PARMETIS).tar.gz $(SCOTCH).tar.gz $(MUMPS).tar.gz $(TRILINOS).tar.gz
PKG_DIRS += $(PARMETIS) $(SCOTCH) $(MUMPS) Trilinos-$(TRILINOS)
TARGET += parmetis scotch mumps trilinos

ifeq ("$(shell [ -f $(REFINER).tar.gz ] && echo true)", "true")
  WITH_REFINER = 1
  PKG_DIRS += $(REFINER)
  TARGET += refiner
  #ARCH = $(shell ruby -e 'puts RUBY_PLATFORM')
  ARCH = x86_64-linux
else
  WITH_REFINER = 0
endif

TARGET += frontistr

$(info TARGET is $(TARGET))


##################
### Make Rules ###
##################

all: $(PREFIX) $(TARGET)
.PHONY: all

download: $(PACKAGES) $(FISTR)
.PHONY: download

extract: $(PKG_DIRS)
.PHONY: extract


$(PREFIX):
	if [ ! -d $(PREFIX) ]; then mkdir -p $(PREFIX); fi

###
### CMAKE
###

CMAKE_VER = $(shell echo $(CMAKE) | perl -pe 's/cmake-//;')

$(CMAKE).tar.gz:
	wget https://github.com/Kitware/CMake/releases/download/v$(CMAKE_VER)/$@

$(CMAKE): $(CMAKE).tar.gz
	rm -rf $@
	tar zxvf $<
	touch $@

$(PREFIX)/$(CMAKE)/bin/cmake: $(CMAKE)
	(cd $(CMAKE) && ./bootstrap --parallel=$(NJOBS) --prefix=$(PREFIX)/$(CMAKE) -- -DCMAKE_USE_OPENSSL=OFF && make -j $(NJOBS) && make install)

cmake: $(PREFIX)/$(CMAKE)/bin/cmake
.PHONY: cmake


###
### OpenMPI
###

OPENMPI_VER = $(shell echo $(OPENMPI) | perl -pe 's/openmpi-//;')
OPENMPI_VER_MM = $(shell echo $(OPENMPI_VER) | perl -pe 's/\.\d+[^\.]//;')

$(OPENMPI).tar.bz2:
	wget https://download.open-mpi.org/release/open-mpi/v$(OPENMPI_VER_MM)/$@

$(OPENMPI): $(OPENMPI).tar.bz2
	rm -rf $@
	tar jxvf $<
	touch $@

$(PREFIX)/$(OPENMPI)/bin/mpicc: $(OPENMPI)
	(cd $(OPENMPI); mkdir build; cd build; \
	../configure CC=$(CC) CXX=$(CXX) F77=$(FC) FC=$(FC) \
	CFLAGS="$(CFLAGS)" CXXFLAGS="$(CXXFLAGS)" FFLAGS="$(FCFLAGS)" FCFLAGS="$(FCFLAGS)" \
	--prefix=$(PREFIX)/$(OPENMPI); \
	make -j $(NJOBS); make install)

openmpi: $(PREFIX)/$(OPENMPI)/bin/mpicc
.PHONY: openmpi


###
### MPICH
###

MPICH_VER = $(shell echo $(MPICH) | perl -pe 's/mpich-//;')

$(MPICH).tar.gz:
	wget http://www.mpich.org/static/downloads/$(MPICH_VER)/$@

$(MPICH): $(MPICH).tar.gz
	rm -rf $@
	tar zxvf $<
	touch $@

$(PREFIX)/$(MPICH)/bin/mpicc: $(MPICH)
	(cd $(MPICH); mkdir build; cd build; \
	../configure CC=$(CC) CXX=$(CXX) F77=$(FC) FC=$(FC) --enable-fast=all \
	MPICHLIB_CFLAGS="$(CFLAGS)" MPICHLIB_FFLAGS="$(FCFLAGS)" \
	MPICHLIB_CXXFLAGS="$(CXXFLAGS)" MPICHLIB_FCFLAGS="$(FCFLAGS)" \
	-prefix=$(PREFIX)/$(MPICH); \
	make -j $(NJOBS); make install)

mpich: $(PREFIX)/$(MPICH)/bin/mpicc
.PHONY: mpich


###
### OpenBLAS
###

OPENBLAS_VER = $(shell echo $(OPENBLAS) | perl -pe 's/OpenBLAS-//;')

$(OPENBLAS).tar.gz:
	wget https://github.com/xianyi/OpenBLAS/archive/v$(OPENBLAS_VER).tar.gz
	mv v$(OPENBLAS_VER).tar.gz $@

$(OPENBLAS): $(OPENBLAS).tar.gz
	rm -rf $@
	tar zxvf $(OPENBLAS).tar.gz
	touch $@

$(PREFIX)/$(OPENBLAS)/lib/libopenblas.a: $(OPENBLAS)
	(cd $(OPENBLAS); make USE_OPENMP=1 NO_SHARED=1 CC=$(CC) FC=$(FC); make install NO_SHARED=1 PREFIX=$(PREFIX)/$(OPENBLAS))

openblas: $(PREFIX)/$(OPENBLAS)/lib/libopenblas.a
.PHONY: openblas


###
### ATLAS
###

ATLAS_VER = $(shell echo $(ATLAS) | perl -pe 's/atlas//;')
LAPACK_VER = $(shell echo $(LAPACK) | perl -pe 's/lapack-//;')

$(ATLAS).tar.bz2:
	wget https://downloads.sourceforge.net/project/math-atlas/Stable/$(ATLAS_VER)/$@

# from 3.9.0
#$(LAPACK).tar.gz:
#	wget https://github.com/Reference-LAPACK/lapack/archive/v$(LAPACK_VER).tar.gz
#	mv v$(LAPACK_VER).tar.gz $@

# till 3.8.0
$(LAPACK).tar.gz:
	wget http://www.netlib.org/lapack/$@

$(ATLAS): $(ATLAS).tar.bz2
	rm -rf $@
	tar jxvf $<
	mv ATLAS $@
	touch $@

$(PREFIX)/$(ATLAS)/lib/libatlas.a: $(ATLAS) $(LAPACK).tar.gz
	(cd $(ATLAS); mkdir build; cd build; \
	../configure --with-netlib-lapack-tarfile=$(TOPDIR)/$(LAPACK).tar.gz \
	-Si omp 1 -F alg $(OMPFLAGS) --prefix=$(PREFIX)/$(ATLAS); \
	make build; make install)

# to force change compiler, add the following to configure option
#	-C ac $(CC) -C if $(FC) \
# to force change compiler flags, add the following to configure option
#	-F ac "$(CFLAGS)" -F if "$(FCFLAGS)" \

atlas: $(PREFIX)/$(ATLAS)/lib/libatlas.a
.PHONY: atlas


###
### ScaLAPACK
###

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
	-D BLAS_goto2_LIBRARY:FILEPATH=$(PREFIX)/$(OPENBLAS)/lib/libopenblas.a \
	-D LAPACK_goto2_LIBRARY:FILEPATH=$(PREFIX)/$(OPENBLAS)/lib/libopenblas.a
else
SCALAPACK_CMAKE_OPTS += \
	-D BLAS_atlas_LIBRARY:FILEPATH=$(PREFIX)/$(ATLAS)/lib/libatlas.a \
	-D BLAS_f77blas_LIBRARY:FILEPATH=$(PREFIX)/$(ATLAS)/lib/libf77blas.a \
	-D LAPACK_LA_ACK_LIBRARY:FILEPATH=$(PREFIX)/$(ATLAS)/liblapack_atlas.a
endif

$(PREFIX)/$(SCALAPACK)/lib/libscalapack.a: $(SCALAPACK) $(MPI_INST)
	(cd $(SCALAPACK); mkdir build; cd build; \
	echo "cmake $(SCALAPACK_CMAKE_OPTS) .." > run_cmake.sh; \
	sh run_cmake.sh; \
	make -j $(NJOBS); \
	make install)

scalapack: $(PREFIX)/$(SCALAPACK)/lib/libscalapack.a
.PHONY: scalapack


###
### METIS
###

$(METIS).tar.gz:
ifeq ($(metisversion), 4)
	wget http://glaros.dtc.umn.edu/gkhome/fetch/sw/metis/OLD/$@
else
	wget http://glaros.dtc.umn.edu/gkhome/fetch/sw/metis/$@
endif

$(METIS): $(METIS).tar.gz
	rm -rf $@
	tar zxvf $<
	touch $@

ifeq ($(metisversion), 4)
$(PREFIX)/$(PARMETIS)/lib/libmetis.a: parmetis
else
$(PREFIX)/$(PARMETIS)/lib/libmetis.a: $(METIS)
	(cd $(METIS) && make config prefix=$(PREFIX)/$(PARMETIS) cc=$(CC) && \
	make --no-print-directory -j $(NJOBS) install)
endif

metis: $(PREFIX)/$(PARMETIS)/lib/libmetis.a
.PHONY: metis


###
### ParMETIS
###

$(PARMETIS).tar.gz:
ifeq ($(metisversion), 4)
	wget http://glaros.dtc.umn.edu/gkhome/fetch/sw/parmetis/OLD/$@
else
	wget http://glaros.dtc.umn.edu/gkhome/fetch/sw/parmetis/$@
endif

$(PARMETIS): $(PARMETIS).tar.gz
	rm -rf $@
	tar zxvf $<
	touch $@

$(PREFIX)/$(PARMETIS)/lib/libparmetis.a: $(PARMETIS) $(MPI_INST)
ifeq ($(metisversion), 4)
	perl -i -pe \
	"if(/^CC/){s!= .*!= $(MPICC)!;} \
	elsif(/^OPTFLAGS/){s!= .*!= $(CFLAGS)!;} \
	elsif(/^LD/){s!= .*!= $(MPICC)!;}" \
	$(PARMETIS)/Makefile.in
	(cd $(PARMETIS) && make && \
	if [ ! -d $(PREFIX)/$(PARMETIS)/lib ]; then mkdir -p $(PREFIX)/$(PARMETIS)/lib; fi && \
	cp lib*.a $(PREFIX)/$(PARMETIS)/lib && \
	if [ ! -d $(PREFIX)/$(PARMETIS)/include ]; then mkdir -p $(PREFIX)/$(PARMETIS)/include; fi && \
	cp *.h $(PREFIX)/$(PARMETIS)/include && \
	if [ ! -d $(PREFIX)/$(PARMETIS)/include/METISLib ]; then mkdir -p $(PREFIX)/$(PARMETIS)/include/METISLib; fi && \
	cp METISLib/*.h $(PREFIX)/$(PARMETIS)/include/METISLib)
else
	(cd $(PARMETIS) && make config prefix=$(PREFIX)/$(PARMETIS) cc=$(MPICC) cxx=$(MPICXX) && \
	make --no-print-directory -j $(NJOBS) install)
endif

parmetis: $(PREFIX)/$(PARMETIS)/lib/libparmetis.a
.PHONY: parmetis


###
### SCOTCH
###

$(SCOTCH).tar.gz:
	wget https://gforge.inria.fr/frs/download.php/latestfile/298/$@

$(SCOTCH): $(SCOTCH).tar.gz
	rm -rf $@
	tar zxvf $<
	touch $@

$(PREFIX)/$(SCOTCH)/lib/libscotch.a: $(SCOTCH) $(MPI_INST)
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

scotch: $(PREFIX)/$(SCOTCH)/lib/libscotch.a
.PHONY: scotch


###
### MUMPS
###

$(MUMPS).tar.gz:
	wget http://mumps.enseeiht.fr/$@

$(MUMPS): $(MUMPS).tar.gz
	rm -rf $@
	tar zxvf $<
	touch $@

MUMPS_DEPS = $(MUMPS) metis parmetis scotch
ifeq ($(BLASLAPACK), OpenBLAS)
MUMPS_DEPS += scalapack
endif
ifeq ($(BLASLAPACK), ATLAS)
MUMPS_DEPS += scalapack
endif

$(PREFIX)/$(MUMPS)/lib/libdmumps.a: $(MUMPS_DEPS)
	perl -pe \
	"s!%scotch_dir%!$(PREFIX)/$(SCOTCH)!; \
	s!%metis_dir%!$(PREFIX)/$(PARMETIS)!; \
	s!%mpicc%!$(MPICC)!; \
	s!%mpifort%!$(MPIF90)!; \
	s!%lapack_libs%!$(LAPACKLIB)!; \
	s!%scalapack_libs%!$(SCALAPACKLIB)!; \
	s!%blas_libs%!$(BLASLIB)!; \
	s!%fcflags%!$(FCFLAGS) $(NOFOR_MAIN) $(OMPFLAGS)!; \
	s!%ldflags%!$(FCFLAGS) $(NOFOR_MAIN) $(OMPFLAGS)!; \
	s!%cflags%!$(CFLAGS) $(NOFOR_MAIN_C) $(OMPFLAGS)!;" \
	MUMPS_Makefile.inc > $(MUMPS)/Makefile.inc  ### to be fixed
ifeq ($(metisversion), 4)
	perl -i -pe \
	"s!Dmetis!Dmetis4!; \
	s!Dparmetis!Dparmetis3!; \
	if(/^IMETIS/){s!include!include -I$(PREFIX)/$(PARMETIS)/include/METISLib!;}" \
	$(MUMPS)/Makefile.inc
endif
	(cd $(MUMPS) && make -j $(NJOBS) && \
	if [ ! -d $(PREFIX)/$(MUMPS) ]; then mkdir $(PREFIX)/$(MUMPS); fi && \
	cp -r lib include $(PREFIX)/$(MUMPS)/.)


mumps: $(PREFIX)/$(MUMPS)/lib/libdmumps.a
.PHONY: mumps


###
### TRILINOS
###

$(TRILINOS).tar.gz:
	wget https://github.com/trilinos/Trilinos/archive/$@

Trilinos-$(TRILINOS): $(TRILINOS).tar.gz
	rm -rf $@
	tar zxvf $<
	touch $@

TRILINOS_CMAKE_OPTS = \
	-D Trilinos_ENABLE_ALL_OPTIONAL_PACKAGES=OFF \
	-D CMAKE_BUILD_TYPE=$(BUILD_TYPE) \
	-D CMAKE_C_COMPILER=$(MPICC) \
	-D CMAKE_C_FLAGS=\"$(CFLAGS)\" \
	-D CMAKE_CXX_COMPILER=$(MPICXX) \
	-D CMAKE_CXX_FLAGS=\"$(CFLAGS)\" \
	-D TPL_ENABLE_MPI=ON \
	-D MPI_EXEC=$(MPIEXEC) \
	-D Trilinos_ENABLE_Fortran:BOOL=OFF \
	-D Trilinos_ENABLE_OpenMP:BOOL=ON \
	-D OpenMP_C_FLAGS=$(OMPFLAGS) \
	-D OpenMP_CXX_FLAGS=$(OMPFLAGS) \
	-D Trilinos_ENABLE_Epetra=ON \
	-D Trilinos_ENABLE_Zoltan=ON \
	-D Trilinos_ENABLE_Amesos=ON \
	-D Trilinos_ENABLE_ML=ON \
	-D ML_ENABLE_Amesos=ON \
	-D TPL_ENABLE_METIS=ON \
	-D METIS_INCLUDE_DIRS=$(PREFIX)/$(PARMETIS)/include \
	-D METIS_LIBRARY_DIRS=$(PREFIX)/$(PARMETIS)/lib \
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

ifeq ($(COMPILER), SOME_OLD_COMPILER)
TRILINOS_CMAKE_OPTS += \
	-D Trilinos_ENABLE_CXX11=OFF
else
TRILINOS_CMAKE_OPTS += \
	-D Trilinos_ENABLE_CXX11=ON
endif

ifeq ($(BLASLAPACK), OpenBLAS)
TRILINOS_CMAKE_OPTS += \
	-D BLAS_INCLUDE_DIRS:PATH=$(PREFIX)/$(OPENBLAS)/include \
	-D BLAS_LIBRARY_DIRS:PATH=$(PREFIX)/$(OPENBLAS)/lib \
	-D BLAS_LIBRARY_NAMES:STRING=\"openblas\" \
	-D LAPACK_LIBRARY_DIRS:PATH=$(PREFIX)/$(OPENBLAS)/lib \
	-D LAPACK_LIBRARY_NAMES:STRING=\"openblas\"
else
  ifeq ($(BLASLAPACK), ATLAS)
TRILINOS_CMAKE_OPTS += \
	-D BLAS_INCLUDE_DIRS:PATH=$(PREFIX)/$(ATLAS)/include \
	-D BLAS_LIBRARY_DIRS:PATH=$(PREFIX)/$(ATLAS)/lib \
	-D BLAS_LIBRARY_NAMES:STRING=\"f77blas;cblas;atlas\" \
	-D LAPACK_LIBRARY_DIRS:PATH=$(PREFIX)/$(ATLAS)/lib \
	-D LAPACK_LIBRARY_NAMES:STRING=\"lapack;f77blas;cblas;atlas\"
  else
    ifeq ($(BLASLAPACK), MKL)
TRILINOS_CMAKE_OPTS += \
	-D BLAS_INCLUDE_DIRS:PATH=$(MKLROOT)/include \
	-D BLAS_LIBRARY_DIRS:PATH=\"$(MKLROOT)/lib/intel64\" \
	-D BLAS_LIBRARY_NAMES:STRING=\"mkl_intel_lp64;mkl_sequential;mkl_core\" \
	-D LAPACK_LIBRARY_DIRS:PATH=\"$(MKLROOT)/lib/intel64\" \
	-D LAPACK_LIBRARY_NAMES:STRING=\"mkl_intel_lp64;mkl_sequential;mkl_core\"
    else
      ifeq ($(BLASLAPACK), FUJITSU)
TRILINOS_CMAKE_OPTS += \
	-D TPL_BLAS_LIBRARIES:STRING=\"-SSL2\" \
	-D TPL_LAPACK_LIBRARIES:STRING=\"-SSL2\"
      endif
    endif
  endif
endif

$(PREFIX)/$(TRILINOS)/lib/libml.a: Trilinos-$(TRILINOS) metis parmetis scotch mumps
	(cd Trilinos-$(TRILINOS); mkdir build; cd build; \
	echo "cmake $(TRILINOS_CMAKE_OPTS) .." > run_cmake.sh; \
	sh run_cmake.sh; \
	make -j $(NJOBS); \
	make install)

trilinos: $(PREFIX)/$(TRILINOS)/lib/libml.a
.PHONY: trilinos


###
### REVOCAP_Refiner
###

$(REFINER): $(REFINER).tar.gz
	rm -rf $@
	tar zxvf $(REFINER).tar.gz
	touch $@

$(PREFIX)/$(REFINER)/lib/libRcapRefiner.a: $(REFINER)
	(cd $(REFINER); \
	ARCH=$(ARCH) CC=$(MPICC) CFLAGS="$(CFLAGS)" CXX=$(MPICXX) CXXFLAGS="$(CXXFLAGS)" F90=$(MPIF90) FFLAGS="$(FCFLAGS)" make Refiner; \
	mkdir -p $(PREFIX)/$(REFINER)/include $(PREFIX)/$(REFINER)/lib; \
	cp Refiner/rcapRefiner.h $(PREFIX)/$(REFINER)/include; \
	cp lib/$(ARCH)/libRcapRefiner.a $(PREFIX)/$(REFINER)/lib)

refiner: $(PREFIX)/$(REFINER)/lib/libRcapRefiner.a
.PHONY: refiner


###
### FrontISTR
###

$(FISTR):
	if [ ! -d $(FISTR) ]; then \
		git clone https://gitlab.com/FrontISTR-Commons/FrontISTR.git $(FISTR); \
	fi

SCOTCH_LIBS = -L$(PREFIX)/$(SCOTCH)/lib -lptesmumps -lptscotch -lscotch -lptscotcherr
F90LDFLAGS = $(SCOTCH_LIBS) $(SCALAPACKLIB) $(LAPACKLIB) $(BLASLIB) $(OMPFLAGS) $(LIBSTDCXX)

ifeq ($(fistrbuild), old)
### Old style build with setup.sh
FISTR_SETUP_OPTS = -p --with-tools --with-metis --with-parmetis --with-mumps --with-ml --with-lapack

ifeq ($(WITH_REFINER), 1)
FISTR_SETUP_OPTS += --with-refiner
endif

$(PREFIX)/$(FISTR)/bin/fistr1: $(FISTR) metis parmetis mumps trilinos
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
ifeq ($(metisversion), 4)
	perl -i -pe \
	"if(/^METISINCDIR/){s!include!include/METISLib!;}" \
	$(FISTR)/Makefile.conf
endif
	(cd $(FISTR) && \
	./setup.sh $(FISTR_SETUP_OPTS) && \
	(cd hecmw1 && make) && (cd fistr1 && make) && \
	if [ ! -d $(PREFIX)/$(FISTR)/bin ]; then mkdir -p $(PREFIX)/$(FISTR)/bin; fi && \
	cp hecmw1/bin/* fistr1/bin/* $(PREFIX)/$(FISTR)/bin/.)
	@echo
	@echo "Build completed."
	@echo "Commands (fistr1, hecmw_part1, etc.) are located in $(PREFIX)/$(FISTR)/bin."
	@echo "Please add $(PREFIX)/$(FISTR)/bin to your PATH environment variable (or copy files in $(PREFIX)/$(FISTR)/bin to one of the directories in your PATH environment variable)."
	@echo
### End of old style build with setup.sh

else

### New style build with CMake
FISTR_CMAKE_OPTS = \
	-D CMAKE_BUILD_TYPE=$(BUILD_TYPE) \
	-D CMAKE_C_COMPILER=$(MPICC) \
	-D CMAKE_C_FLAGS=\"$(CFLAGS)\" \
	-D CMAKE_CXX_COMPILER=$(MPICXX) \
	-D CMAKE_CXX_FLAGS=\"$(CFLAGS)\" \
	-D CMAKE_Fortran_COMPILER=$(MPIF90) \
	-D CMAKE_Fortran_FLAGS=\"$(FCFLAGS) $(OMPFLAGS)\" \
	-D WITH_TOOLS=1 \
	-D WITH_MPI=1 \
	-D WITH_OPENMP=1 \
	-D WITH_REFINER=$(WITH_REFINER) \
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
	-D MUMPS_LIBRARIES=\"$(PREFIX)/$(MUMPS)/lib/libdmumps.a;$(PREFIX)/$(MUMPS)/lib/libmumps_common.a;$(PREFIX)/$(MUMPS)/lib/libpord.a;$(PREFIX)/$(SCOTCH)/lib/libptesmumps.a;$(PREFIX)/$(SCOTCH)/lib/libptscotch.a;$(PREFIX)/$(SCOTCH)/lib/libptscotcherr.a;$(PREFIX)/$(SCOTCH)/lib/libscotch.a\" \
	-D WITH_ML=1 \
	-D CMAKE_PREFIX_PATH=$(PREFIX)/$(TRILINOS) \
	-D WITH_DOC=0 \
	-D CMAKE_INSTALL_PREFIX=$(PREFIX)/$(FISTR)

ifeq ($(WITH_REFINER), 1)
FISTR_CMAKE_OPTS += \
	-D REFINER_INCLUDE_PATH=$(PREFIX)/$(REFINER)/include \
	-D REFINER_LIBRARIES=$(PREFIX)/$(REFINER)/lib/libRcapRefiner.a
endif

ifeq ($(BLASLAPACK), OpenBLAS)
FISTR_CMAKE_OPTS += \
	-D WITH_MKL=OFF \
	-D BLAS_LIBRARIES=$(PREFIX)/$(OPENBLAS)/lib/libopenblas.a \
	-D LAPACK_LIBRARIES=$(PREFIX)/$(OPENBLAS)/lib/libopenblas.a \
	-D SCALAPACK_LIBRARIES=\"$(SCALAPACKLIB)\"
else
  ifeq ($(BLASLAPACK), ATLAS)
FISTR_CMAKE_OPTS += \
	-D WITH_MKL=OFF \
	-D BLAS_LIBRARIES=\"$(PREFIX)/$(ATLAS)/lib/libptf77blas.a;$(PREFIX)/$(ATLAS)/lib/libatlas.a\" \
	-D LAPACK_LIBRARIES=\"$(PREFIX)/$(ATLAS)/lib/libptlapack.a;$(PREFIX)/$(ATLAS)/lib/libptf77blas.a;$(PREFIX)/$(ATLAS)/lib/libptcblas.a;$(PREFIX)/$(ATLAS)/lib/libatlas.a\" \
	-D SCALAPACK_LIBRARIES=\"$(SCALAPACKLIB)\"
  else
    ifeq ($(BLASLAPACK), MKL)
FISTR_CMAKE_OPTS += \
	-D WITH_MKL=ON \
	-D BLA_VENDOR=\"Intel10_64lp\"
    else
      ifeq ($(BLASLAPACK), FUJITSU)
FISTR_CMAKE_OPTS += \
	-D WITH_MKL=OFF \
	-D CMAKE_Fortran_MODDIR_FLAG=-M \
	-D BLAS_LIBRARIES=-SSL2BLAMP \
	-D LAPACK_LIBRARIES=-SSL2BLAMP \
	-D SCALAPACK_LIBRARIES=-SCALAPACK \
	-D OpenMP_C_FLAGS=$(OMPFLAGS) \
	-D OpenMP_CXX_FLAGS=$(OMPFLAGS) \
	-D OpenMP_Fortran_FLAGS=$(OMPFLAGS)
      else
FISTR_CMAKE_OPTS += \
	-D WITH_MKL=OFF \
	-D BLAS_LIBRARIES=\"$(BLASLIB)\" \
	-D LAPACK_LIBRARIES=\"$(LAPACKLIB)\" \
	-D SCALAPACK_LIBRARIES=\"$(SCALAPACKLIB)\"
      endif
    endif
  endif
endif

$(PREFIX)/$(FISTR)/bin/fistr1: $(FISTR) metis parmetis mumps trilinos
	(cd $(FISTR); mkdir build; cd build; cmake --version; \
	echo "cmake $(FISTR_CMAKE_OPTS) .." > run_cmake.sh; \
	sh run_cmake.sh; \
	make -j $(NJOBS); \
	make install)
	@echo
	@echo "Build completed."
	@echo "Commands (fistr1, hecmw_part1, etc.) are located in $(PREFIX)/$(FISTR)/bin."
	@echo "Please add $(PREFIX)/$(FISTR)/bin to your PATH environment variable (or copy files in $(PREFIX)/$(FISTR)/bin to one of the directories in your PATH environment variable)."
	@echo
### End of new style build with CMake
endif

frontistr: $(PREFIX)/$(FISTR)/bin/fistr1
.PHONY: frontistr


###
### Misc.
###

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
ifeq ($(metisversion), 4)
	if [ -d $(METIS) ]; then \
		(cd $(METIS) && make clean); \
	fi
	if [ -d $(PARMETIS) ]; then \
		(cd $(PARMETIS) && make clean); \
	fi
else
	if [ -d $(METIS) ]; then \
		(cd $(METIS) && make distclean); \
	fi
	if [ -d $(PARMETIS) ]; then \
		(cd $(PARMETIS) && make distclean); \
	fi
endif
	if [ -d $(SCOTCH) ]; then \
		(cd $(SCOTCH)/src && make realclean); \
	fi
	if [ -d $(MUMPS) ]; then \
		(cd $(MUMPS) && make clean); \
	fi
	if [ -d Trilinos-$(TRILINOS) ]; then \
		rm -rf Trilinos-$(TRILINOS)/build; \
	fi
	if [ -d $(REFINER) ]; then \
		(cd $(REFINER) && make clean); \
	fi
	if [ -d $(FISTR) ]; then \
		if [ -d $(FISTR)/build ]; then rm -rf $(FISTR)/build; fi; \
		if [ -f $(FISTR)/Makefile ]; then (cd $(FISTR); make clean); fi; \
	fi
.PHONY: clean

distclean:
	rm -rf $(CMAKE) $(OPENMPI) $(MPICH) $(OPENBLAS) $(ATLAS) $(SCALAPACK) $(METIS) $(PARMETIS) $(SCOTCH) $(MUMPS) Trilinos-$(TRILINOS) $(REFINER)
	rm -rf $(PREFIX)
	if [ -d $(FISTR) ]; then \
		if [ -d $(FISTR)/build ]; then rm -rf $(FISTR)/build; fi; \
		if [ -f $(FISTR)/Makefile ]; then (cd $(FISTR); make distclean); fi; \
	fi
.PHONY: distclean
