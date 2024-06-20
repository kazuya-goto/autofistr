undefine CC
undefine CXX
undefine FC

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
ifeq ($(MPI), OTHER)
  MPI_BASE ?= OTHER
  $(info MPI_BASE is $(MPI_BASE))
endif
$(info BLASLAPACK is $(BLASLAPACK))


###
### Package versions
###

CMAKE_MINVER_MAJOR := 2
CMAKE_MINVER_MINOR := 8
CMAKE_MINVER_PATCH := 11

CMAKE     = cmake-3.29.6
OPENMPI   = openmpi-5.0.3
MPICH     = mpich-4.2.1
OPENBLAS  = OpenBLAS-0.3.27
ATLAS     = atlas3.10.3
LAPACK    = lapack-3.12.0
SCALAPACK = scalapack-2.2.0
ifeq ($(metisversion), 4)
  METIS     = metis-4.0.3
  PARMETIS  = ParMetis-3.2.0
else
  METIS     = metis-5.1.0
  PARMETIS  = parmetis-4.0.3
endif

BISON_VER_MAJOR = $(shell bison -V | perl -ne 'if(/^bison/){s/^\D*//;s/\..*//;print;}')
$(info BISON_VER_MAJOR is $(BISON_VER_MAJOR))
ifeq ("$(shell [ $(BISON_VER_MAJOR) -ge 3 ] && echo true)", "true")
  SCOTCH = scotch-v7.0.4
else
  SCOTCH = scotch-v6.1.3
endif

MUMPS     = MUMPS_5.7.2
ifeq ($(COMPILER), FUJITSU)
  TRILINOS  = trilinos-release-12-6-4
else
  TRILINOS  = trilinos-release-15-1-1
  #TRILINOS  = trilinos-release-14-4-0
  #TRILINOS  = trilinos-release-14-2-0
  #TRILINOS  = trilinos-release-14-0-0
  CMAKE_MINVER_MAJOR := 3
  CMAKE_MINVER_MINOR := 23
  CMAKE_MINVER_PATCH := 0
  #TRILINOS  = trilinos-release-13-4-1
  #TRILINOS  = trilinos-release-13-2-0
  #CMAKE_MINVER_MAJOR := 3
  #CMAKE_MINVER_MINOR := 17
  #CMAKE_MINVER_PATCH := 0
  #TRILINOS  = trilinos-release-13-0-1
  #TRILINOS  = trilinos-release-12-18-1
  #CMAKE_MINVER_MAJOR := 3
  #CMAKE_MINVER_MINOR := 10
  #CMAKE_MINVER_PATCH := 0
  #TRILINOS  = trilinos-release-12-14-1
  #TRILINOS  = trilinos-release-12-12-1
  #TRILINOS  = trilinos-release-12-10-1
  #TRILINOS  = trilinos-release-12-8-1
  #TRILINOS  = trilinos-release-12-6-4
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
  ifneq ($(BLASLAPACK), FUJITSU)
    $(warning forced to use FUJITSU BLASLAPACK)
    BLASLAPACK = FUJITSU
  endif
  ifneq ($(MPI), FUJITSU)
    $(warning forced to use FUJITSU MPI)
    MPI = FUJITSU
  endif
  PREFIX = $(TOPDIR)/$(COMPILER)
else
  ifeq ($(MPI), NONE)
    DOWNLOAD_MPI = false
    PREFIX = $(TOPDIR)/$(COMPILER)
  else
  ifeq ($(MPI), OTHER)
    DOWNLOAD_MPI = false
    PREFIX = $(TOPDIR)/$(COMPILER)_OTHER
  else
    # detect SYSTEM MPI
    ifneq ("$(shell mpicc --showme:version 2> /dev/null | grep 'Open MPI')", "")
      $(info SYSTEM MPI is OpenMPI)
      SYSTEM_MPI = OPENMPI
    else
    ifneq ("$(shell mpicc -v 2> /dev/null | grep 'MPICH')", "")
      $(info SYSTEM MPI is MPICH)
      SYSTEM_MPI = MPICH
    else
    ifneq ("$(shell mpicc -v 2> /dev/null | grep 'Intel(R) MPI')", "")
      $(info SYSTEM MPI is IntelMPI)
      SYSTEM_MPI = IMPI
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
  endif
endif

###
### detect SYSTEM CMAKE
###

DOWNLOAD_CMAKE = true
export PATH := $(PREFIX)/$(CMAKE)/bin:$(PATH)

ifeq ("$(shell PATH=$(PATH) which cmake)", "")
  $(info CMAKE not found)
else
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
### Compiler settings
###

ifeq ($(COMPILER), GCC)
  CC ?= gcc
  CXX ?= g++
  FC ?= gfortran
  # check existence of compiler commands
  ifeq ("$(shell which $(CC))", "")
    $(error $(CC) not found in PATH)
  endif
  ifeq ("$(shell which $(CXX))", "")
    $(error $(CXX) not found in PATH)
  endif
  ifeq ("$(shell which $(FC))", "")
    $(error $(FC) not found in PATH)
  endif
  ifeq ($(BUILD_TYPE), RELEASE)
    CFLAGS ?= -O3 -mtune=native
    CXXFLAGS ?= -O3 -mtune=native
    FCFLAGS ?= -O3 -mtune=native
  else
    CFLAGS ?= -O0 -g
    CXXFLAGS ?= -O0 -g
    FCFLAGS ?= -O0 -g
  endif
  GCC_VER = $(shell $(FC) -dumpversion | perl -pe 's/\..*//;')
  ifeq ("$(shell [ $(GCC_VER) -ge 10 ] && echo true)", "true")
    FCFLAGS += -fallow-argument-mismatch
  endif
  OMPFLAGS ?= -fopenmp
  NOFOR_MAIN ?=
  NOFOR_MAIN_C ?=
  NOFOR_MAIN_LD ?=
  LIBSTDCXX ?= -lstdc++
  F90FPPFLAG ?= -cpp
else
ifeq ($(COMPILER), INTEL)
  ifeq ("$(shell which icc)", "")
    CC ?= icx
  else
    CC ?= icc
  endif
  ifeq ("$(shell which icpc)", "")
    CXX ?= icpx
  else
    CXX ?= icpc
  endif
  ifeq ("$(shell which ifort)", "")
    FC ?= ifx
  else
    FC ?= ifort
  endif
  # check existence of compiler commands
  ifeq ("$(shell which $(CC))", "")
    $(error $(CC) not found in PATH)
  endif
  ifeq ("$(shell which $(CXX))", "")
    $(error $(CXX) not found in PATH)
  endif
  ifeq ("$(shell which $(FC))", "")
    $(error $(FC) not found in PATH)
  endif
  ifeq ($(BUILD_TYPE), RELEASE)
    CFLAGS ?= -O3
    CXXFLAGS ?= -O3
    FCFLAGS ?= -O3
  else
    CFLAGS ?= -O0 -g -traceback
    CXXFLAGS ?= -O0 -g -traceback
    FCFLAGS ?= -O0 -g -CB -CU -traceback
  endif
  IFORT_VER_MAJOR = $(shell LANG=C ifort -v 2>&1 | perl -pe 's/ifort version //;s/\D.*//;')
  IFORT_VER_MINOR = $(shell LANG=C ifort -v 2>&1 | perl -pe 's/ifort version \d+\.//;s/\D.*//;')
  IFORT_VER_PATCH = $(shell LANG=C ifort -v 2>&1 | perl -pe 's/ifort version \d+\.\d+\.//;s/\D.*//;')
  $(info IFORT_VER is $(IFORT_VER_MAJOR).$(IFORT_VER_MINOR).$(IFORT_VER_PATCH))
  ifeq ("$(shell [ $(IFORT_VER_MAJOR) -ge 15 ] && echo true)", "true")
    OMPFLAGS ?= -qopenmp
  else
    OMPFLAGS ?= -openmp
  endif
  $(info OMPFLAGS is $(OMPFLAGS))
  NOFOR_MAIN ?= -nofor-main
  NOFOR_MAIN_C ?=
  NOFOR_MAIN_LD ?= -nofor-main
  LIBSTDCXX ?= -lstdc++
  F90FPPFLAG ?= -fpp
else
ifeq ($(COMPILER), NVIDIA)
  CC ?= nvc
  CXX ?= nvc++
  FC ?= nvfortran
  # check existence of compiler commands
  ifeq ("$(shell which $(CC))", "")
    $(error $(CC) not found in PATH)
  endif
  ifeq ("$(shell which $(CXX))", "")
    $(error $(CXX) not found in PATH)
  endif
  ifeq ("$(shell which $(FC))", "")
    $(error $(FC) not found in PATH)
  endif
  ifeq ($(BUILD_TYPE), RELEASE)
    CFLAGS ?= -fast -O3
    CXXFLAGS ?= -fast -O3
    FCFLAGS ?= -fast -O3
  else
    CFLAGS ?= -O0 -g -Mbounds -traceback
    CXXFLAGS ?= -O0 -g -Mbounds -traceback
    FCFLAGS ?= -O0 -g -Mbounds -traceback
  endif
  OMPFLAGS ?= -mp
  NOFOR_MAIN ?= -Mnomain
  NOFOR_MAIN_C ?= -DMAIN_COMP
  NOFOR_MAIN_LD ?=
  LIBSTDCXX ?= -lstdc++
  F90FPPFLAG ?= -Mpreprocess
else
ifeq ($(COMPILER), FUJITSU)
  CC ?= fcc
  CXX ?= FCC
  FC ?= frt
  # check existence of compiler commands
  ifeq ("$(shell which $(CC))", "")
    $(error $(CC) not found in PATH)
  endif
  ifeq ("$(shell which $(CXX))", "")
    $(error $(CXX) not found in PATH)
  endif
  ifeq ("$(shell which $(FC))", "")
    $(error $(FC) not found in PATH)
  endif
  ifeq ($(BUILD_TYPE), RELEASE)
    CFLAGS ?= -Kfast -Xg
    CXXFLAGS ?= -Kfast -Xg
    FCFLAGS ?= -Kfast
  else
    CFLAGS ?= -O0 -Xg
    CXXFLAGS ?= -O0 -Xg
    FCFLAGS ?= -O0 -Xg
  endif
  OMPFLAGS ?= -Kopenmp
  #NOFOR_MAIN = -mlcmain=main
  NOFOR_MAIN ?=
  NOFOR_MAIN_C ?= -DMAIN_COMP
  NOFOR_MAIN_LD ?=
  LIBSTDCXX ?=
  F90FPPFLAG ?= -Cpp -Cfpp
else
  CC ?= cc
  CXX ?= c++
  FC ?= f95
  # check existence of compiler commands
  ifeq ("$(shell which $(CC))", "")
    $(error $(CC) not found in PATH)
  endif
  ifeq ("$(shell which $(CXX))", "")
    $(error $(CXX) not found in PATH)
  endif
  ifeq ("$(shell which $(FC))", "")
    $(error $(FC) not found in PATH)
  endif
  ifeq ($(BUILD_TYPE), RELEASE)
    CFLAGS ?= -O3
    CXXFLAGS ?= -O3
    FCFLAGS ?= -O3
  else
    CFLAGS ?= -O0 -g
    CXXFLAGS ?= -O0 -g
    FCFLAGS ?= -O0 -g
  endif
  OMPFLAGS ?= -fopenmp
  NOFOR_MAIN ?=
  NOFOR_MAIN_C ?=
  NOFOR_MAIN_LD ?=
  LIBSTDCXX ?=
  F90FPPFLAG ?= -cpp
endif
endif
endif
endif

$(info CC = $(CC))
$(info CXX = $(CXX))
$(info FC = $(FC))

###
### MPI settings
###

ifeq ($(DOWNLOAD_MPI), true)
  ifeq ($(MPI), OPENMPI)
    MPI_INST = openmpi
    PACKAGES += $(OPENMPI).tar.bz2
    PKG_DIRS += $(OPENMPI)
    TARGET += openmpi
    MPICC = $(PREFIX)/$(OPENMPI)/bin/mpicc
    MPICXX = $(PREFIX)/$(OPENMPI)/bin/mpicxx
    MPIF90 = $(PREFIX)/$(OPENMPI)/bin/mpif90
    MPIEXEC = $(PREFIX)/$(OPENMPI)/bin/mpiexec
  endif
  ifeq ($(MPI), MPICH)
    MPI_INST = mpich
    PACKAGES += $(MPICH).tar.gz
    PKG_DIRS += $(MPICH)
    TARGET += mpich
    MPICC = $(PREFIX)/$(MPICH)/bin/mpicc
    MPICXX = $(PREFIX)/$(MPICH)/bin/mpicxx
    MPIF90 = $(PREFIX)/$(MPICH)/bin/mpif90
    MPIEXEC = $(PREFIX)/$(MPICH)/bin/mpiexec
  endif
else
  ifeq ($(MPI), NONE)
    MPICC = $(CC)
    MPICXX = $(CXX)
    MPIF90 = $(FC)
    MPIEXEC =
    SCALAPACKLIB =
    SCALAPACK = NONE
  else
    ifeq ($(COMPILER), INTEL)
      ifeq ($(MPI), OPENMPI)
        ifeq ("$(shell $(MPICC) --showme:version 2> /dev/null | grep 'icc version')", "")
          $(error SYSTEM OpenMPI is not built with INTEL; set DOWNLOAD_MPI=true and try again)
        endif
      endif
      ifeq ($(MPI), MPICH)
        ifeq ("$(shell $(MPICC) -v 2> /dev/null | grep 'icc version')", "")
          $(error SYSTEM MPICH is not built with INTEL; set DOWNLOAD_MPI=true and try again)
        endif
      endif
      ifeq ($(MPI), IMPI)
        ifeq ("$(CC)", "icc")
          MPICC ?= mpiicc
        else
          MPICC ?= mpiicx
        endif
        ifeq ("$(CXX)", "icpc")
          MPICXX ?= mpiicpc
        else
          MPICXX ?= mpiicpx
        endif
        ifeq ("$(FC)", "ifort")
          MPIF90 ?= mpiifort
        else
          MPIF90 ?= mpiifx
        endif
      endif
    endif
    ifeq ($(COMPILER), FUJITSU)
      MPICC ?= mpifcc
      MPICXX ?= mpiFCC
      MPIF90 ?= mpifrt
    endif
    MPICC ?= mpicc
    MPICXX ?= mpicxx
    MPIF90 ?= mpif90
    MPIEXEC ?= mpiexec
  endif
endif

$(info MPICC = $(MPICC))
$(info MPICXX = $(MPICXX))
$(info MPIF90 = $(MPIF90))
$(info MPIEXEC = $(MPIEXEC))

#ifeq ($(MPI), OPENMPI)
#  LIBMPICXX = -lmpi_cxx
#endif

CLINKER ?= $(MPICC)
F90LINKER ?= $(MPIF90)

ifeq ($(COMPILER), FUJITSU)
  CLINKER = $(MPICXX)
  F90LINKER = $(MPICXX) --linkfortran
endif

###
### BLAS, LAPACK, ScaLAPACK settings
###

ifeq ($(BLASLAPACK), OpenBLAS)
  PACKAGES += $(OPENBLAS).tar.gz
  PKG_DIRS += $(OPENBLAS)
  TARGET += openblas
  BLASLIB = -L$(PREFIX)/$(OPENBLAS)/lib -lopenblas
  LAPACKLIB = -L$(PREFIX)/$(OPENBLAS)/lib -lopenblas
  ifneq ($(MPI), NONE)
    PACKAGES += $(SCALAPACK).tgz
    PKG_DIRS += $(SCALAPACK)
    TARGET += scalapack
    SCALAPACKLIB = -L$(PREFIX)/$(SCALAPACK)/lib -lscalapack
  endif
else
ifeq ($(BLASLAPACK), ATLAS)
  PACKAGES += $(ATLAS).tar.bz2 $(LAPACK).tar.gz
  PKG_DIRS += $(ATLAS)
  TARGET += atlas
  BLASLIB = -L$(PREFIX)/$(ATLAS)/lib -lf77blas -lcblas -latlas
  LAPACKLIB = -L$(PREFIX)/$(ATLAS)/lib -llapack -lf77blas -lcblas -latlas
  ifneq ($(MPI), NONE)
    PACKAGES += $(SCALAPACK).tgz
    PKG_DIRS += $(SCALAPACK)
    TARGET += scalapack
    SCALAPACKLIB = -L$(PREFIX)/$(SCALAPACK)/lib -lscalapack
  endif
else
ifeq ($(BLASLAPACK), MKL)
  ifeq ("$(MKLROOT)", "")
    $(error MKLROOT not set; please make sure the environment variables are correctly set)
  endif
  MKLOPT ?= NONE
  ifneq ($(MKLOPT), NONE)
    ifneq ($(COMPILER), INTEL)
      $(error MKLOPT can be specified only when COMPILER==INTEL)
    endif
    BLASLIB = $(MKLOPT)
    LAPACKLIB = $(MKLOPT)
    SCALAPACKLIB = $(MKLOPT)
    SCALAPACK = MKL
  else
    ifeq ("$(shell uname)", "Linux")
      MKL_LIBDIR := ${MKLROOT}/lib/intel64
      # BLAS
      ifeq ($(COMPILER), INTEL)
        BLASLIB = -Wl,--start-group \
          ${MKL_LIBDIR}/libmkl_intel_lp64.a \
          ${MKL_LIBDIR}/libmkl_intel_thread.a \
          ${MKL_LIBDIR}/libmkl_core.a \
          -Wl,--end-group -liomp5
      endif
      ifeq ($(COMPILER), GCC)
        BLASLIB = -Wl,--start-group \
          ${MKL_LIBDIR}/libmkl_gf_lp64.a \
          ${MKL_LIBDIR}/libmkl_gnu_thread.a \
          ${MKL_LIBDIR}/libmkl_core.a \
          -Wl,--end-group -lgomp -ldl
      endif
      # LAPACK
      LAPACKLIB = $(BLASLIB)
      # ScaLAPACK
      ifneq ($(MPI), NONE)
        ifeq ($(MPI), IMPI)
          SCALAPACKLIB = -L${MKL_LIBDIR} -lmkl_scalapack_lp64 -lmkl_blacs_intelmpi_lp64
          SCALAPACK = MKL
        else
        ifeq ($(MPI), OPENMPI)
          SCALAPACKLIB = -L${MKL_LIBDIR} -lmkl_scalapack_lp64 -lmkl_blacs_openmpi_lp64
          SCALAPACK = MKL
        else
        ifeq ($(MPI), MPICH)
          SCALAPACKLIB = -L${MKL_LIBDIR} -lmkl_scalapack_lp64 -lmkl_blacs_intelmpi_lp64
          SCALAPACK = MKL
        else
          ifeq ($(MPI_BASE), MPICH)
            SCALAPACKLIB = -L${MKL_LIBDIR} -lmkl_scalapack_lp64 -lmkl_blacs_intelmpi_lp64
            SCALAPACK = MKL
          else
          ifeq ($(MPI_BASE), OPENMPI)
            SCALAPACKLIB = -L${MKL_LIBDIR} -lmkl_scalapack_lp64 -lmkl_blacs_openmpi_lp64
            SCALAPACK = MKL
          else
            PACKAGES += $(SCALAPACK).tgz
            PKG_DIRS += $(SCALAPACK)
            TARGET += scalapack
            SCALAPACKLIB = -L$(PREFIX)/$(SCALAPACK)/lib -lscalapack
          endif
          endif
        endif
        endif
        endif
      endif
    else
    ifeq ("$(shell uname)", "Darwin")
      MKL_LIBDIR := ${MKLROOT}/lib
      # BLAS
      BLASLIB = -L${MKL_LIBDIR} -lmkl_intel_lp64 -lmkl_intel_thread -lmkl_core -liomp5
      # LAPACK
      LAPACKLIB = $(BLASLIB)
      # ScaLAPACK
      ifneq ($(MPI), NONE)
        ifeq ($(MPI), MPICH)
          SCALAPACKLIB = -lmkl_scalapack_lp64 -lmkl_blacs_mpich_lp64
          SCALAPACK = MKL
        else
          PACKAGES += $(SCALAPACK).tgz
          PKG_DIRS += $(SCALAPACK)
          TARGET += scalapack
          SCALAPACKLIB = -L$(PREFIX)/$(SCALAPACK)/lib -lscalapack
        endif
      endif
    endif
    endif
  endif
else
ifeq ($(BLASLAPACK), FUJITSU)
  BLASLIB = -SSL2BLAMP
  LAPACKLIB = -SSL2BLAMP
  ifneq ($(MPI), NONE)
    SCALAPACKLIB = -SCALAPACK
    SCALAPACK = FUJITSU
  endif
else
ifeq ($(BLASLAPACK), SYSTEM)
  BLASLIB ?= -lblas
  LAPACKLIB ?= -llapack
  ifneq ($(MPI), NONE)
    ifeq ($(COMPILER), NVIDIA)
      SCALAPACKLIB ?= -Mscalapack
    else
      SCALAPACKLIB ?= -lscalapack
    endif
  endif
  # check SYSTEM BLAS
  HAVE_BLAS = $(shell printf 'program test\nend program' > test.f90 && $(FC) test.f90 $(BLASLIB) > /dev/null 2>&1 && echo true)
  ifeq ($(HAVE_BLAS), true)
    $(info SYSTEM BLAS found)
  else
    $(error SYSTEM BLAS not found)
  endif
  # check SYSTEM LAPACK
  HAVE_LAPACK = $(shell printf 'program test\nend program' > test.f90 && $(FC) test.f90 $(LAPACKLIB) > /dev/null 2>&1 && echo true)
  ifeq ($(HAVE_LAPACK), true)
    $(info SYSTEM LAPACK found)
  else
    $(error SYSTEM LAPACK not found)
  endif
  # check SYSTEM SCALAPACK
  ifneq ($(MPI), NONE)
    HAVE_SCALAPACK = $(shell printf 'program test\nend program' > test.f90 && $(MPIF90) test.f90 $(SCALAPACKLIB) > /dev/null 2>&1 && echo true)
    ifeq ($(HAVE_SCALAPACK), true)
      $(info SYSTEM SCALAPACK found)
      SCALAPACK = SYSTEM
    else
      $(info SYSTEM SCALAPACK not found; set to be downloaded from netlib)
      TARGET += scalapack
      SCALAPACKLIB = -L$(PREFIX)/$(SCALAPACK)/lib -lscalapack
    endif
  endif
else
  $(error unsupported BLASLAPACK: $(BLASLAPACK))
endif
endif
endif
endif
endif

###
### Scotch settings
###

ifeq ("$(shell uname)", "Linux")
  SCOTCH_MAKEFILE_INC := Makefile.inc.x86-64_pc_linux2
else
ifeq ("$(shell uname)", "Darwin")
  SCOTCH_MAKEFILE_INC := Makefile.inc.i686_mac_darwin10
endif
endif

ifeq ($(COMPILER), INTEL)
  SCOTCH_MAKEFILE_INC := $(SCOTCH_MAKEFILE_INC).icc
  ifeq ($(MPI), IMPI)
    SCOTCH_MAKEFILE_INC := $(SCOTCH_MAKEFILE_INC).impi
  endif
endif

###
### External packages and targets
###

ifneq ($(metisversion), 4)
  PACKAGES += $(METIS).tar.gz
  PKG_DIRS += $(METIS)
  TARGET += metis
endif

ifneq ($(MPI), NONE)
  PACKAGES += $(PARMETIS).tar.gz
  PKG_DIRS += $(PARMETIS)
  TARGET += parmetis
endif

PACKAGES += $(SCOTCH).tar.gz $(MUMPS).tar.gz $(TRILINOS).tar.gz
PKG_DIRS += $(SCOTCH) $(MUMPS) Trilinos-$(TRILINOS)
TARGET += scotch mumps trilinos

ifeq ("$(shell [ -f $(REFINER).tar.gz ] && echo true)", "true")
  WITH_REFINER = 1
  PKG_DIRS += $(REFINER)
  TARGET += refiner
  #ARCH = $(shell ruby -e 'puts RUBY_PLATFORM')
  ifeq ("$(shell uname)", "Linux")
    ARCH = x86_64-linux
  else
  ifeq ("$(shell uname)", "Darwin")
    ARCH = x86_64-darwin
  endif
  endif
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
	--with-device=ch4:ofi \
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
$(LAPACK).tar.gz:
	wget https://github.com/Reference-LAPACK/lapack/archive/v$(LAPACK_VER).tar.gz
	mv v$(LAPACK_VER).tar.gz $@

## 3.8.0
#$(LAPACK).tar.gz:
#	wget http://www.netlib.org/lapack/$@

$(ATLAS): $(ATLAS).tar.bz2
	rm -rf $@
	tar jxvf $<
	mv ATLAS $@
	touch $@

$(PREFIX)/$(ATLAS)/lib/libatlas.a: $(ATLAS) $(LAPACK).tar.gz
	(cd $(ATLAS); mkdir build; cd build; \
	../configure --with-netlib-lapack-tarfile=$(TOPDIR)/$(LAPACK).tar.gz \
	-Si omp 1 -F alg $(OMPFLAGS) --prefix=$(PREFIX)/$(ATLAS) $(ATLAS_CONFIG_FLAGS); \
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

# provide MPICC and MPIF90 in place of CC and FC due to a bug introduced at ver.2.2.0
SCALAPACK_CMAKE_OPTS = \
	-D CMAKE_C_COMPILER=\"$(MPICC)\" \
	-D CMAKE_C_FLAGS=\"$(CFLAGS)\" \
	-D CMAKE_Fortran_COMPILER=\"$(MPIF90)\" \
	-D CMAKE_Fortran_FLAGS=\"$(FCFLAGS)\" \
	-D MPI_C_COMPILER=\"$(MPICC)\" \
	-D MPI_Fortran_COMPILER=\"$(MPIF90)\" \
	-D CMAKE_EXE_LINKER_FLAGS=$(OMPFLAGS) \
	-D BLAS_LIBRARIES=\"$(BLASLIB)\" \
	-D LAPACK_LIBRARIES=\"$(LAPACKLIB)\" \
	-D CMAKE_INSTALL_PREFIX=$(PREFIX)/$(SCALAPACK)

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
	(cd $(METIS) && CXX=$(CXX) make config prefix=$(PREFIX)/$(PARMETIS) cc=$(CC) openmp=1 && \
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
	(cd $(PARMETIS) && make config prefix=$(PREFIX)/$(PARMETIS) cc=\"$(MPICC)\" cxx=\"$(MPICXX)\" openmp=1 && \
	make --no-print-directory -j $(NJOBS) install)
endif

parmetis: $(PREFIX)/$(PARMETIS)/lib/libparmetis.a
.PHONY: parmetis


###
### SCOTCH
###

SCOTCH_VER = $(shell echo $(SCOTCH) | perl -pe 's/scotch-//;')

$(SCOTCH).tar.gz:
	wget https://gitlab.inria.fr/scotch/scotch/-/archive/$(SCOTCH_VER)/$@

$(SCOTCH): $(SCOTCH).tar.gz
	rm -rf $@
	tar zxvf $<
	if [ -e $(SCOTCH).patch ]; then (cd $(SCOTCH); patch -p 1 < ../$(SCOTCH).patch); fi
	touch $@

ifneq ($(MPI), NONE)
$(PREFIX)/$(SCOTCH)/lib/libscotch.a: $(SCOTCH) $(MPI_INST)
	perl -pe \
	"if(/^CCS/){s!= .*!= $(CC)!;} \
	elsif(/^CCP/){s!= .*!= $(MPICC)!;} \
	elsif(/^CCD/){s!= .*!= $(MPICC)!;} \
	elsif(/^CFLAGS/){s!-O3!$(CFLAGS)!; s!-DSCOTCH_PTHREAD!!;}" \
	$(SCOTCH)/src/Make.inc/$(SCOTCH_MAKEFILE_INC) > $(SCOTCH)/src/Makefile.inc
	(cd $(SCOTCH)/src && \
	 (make -j $(NJOBS) scotch && echo make scotch done) && \
	 (make -j $(NJOBS) ptscotch && echo make ptscotch done) && \
	 (make esmumps && echo make esmumps done) && \
	 (make ptesmumps && echo make ptesmumps done) && \
	if [ ! -d $(PREFIX)/$(SCOTCH) ]; then mkdir $(PREFIX)/$(SCOTCH); fi && \
	make prefix=$(PREFIX)/$(SCOTCH) install && \
	cp -f ../lib/*esmumps*.a $(PREFIX)/$(SCOTCH)/lib)
else
$(PREFIX)/$(SCOTCH)/lib/libscotch.a: $(SCOTCH)
	perl -pe \
	"if(/^CCS/){s!= .*!= $(CC)!;} \
	elsif(/^CCP/){s!= .*!= $(MPICC)!;} \
	elsif(/^CCD/){s!= .*!= $(MPICC)!;} \
	elsif(/^CFLAGS/){s!-O3!$(CFLAGS)!; s!-DSCOTCH_PTHREAD!!;}" \
	$(SCOTCH)/src/Make.inc/$(SCOTCH_MAKEFILE_INC) > $(SCOTCH)/src/Makefile.inc
	(cd $(SCOTCH)/src && \
	make -j $(NJOBS) scotch && \
	make esmumps && \
	if [ ! -d $(PREFIX)/$(SCOTCH) ]; then mkdir $(PREFIX)/$(SCOTCH); fi && \
	make prefix=$(PREFIX)/$(SCOTCH) install && \
	cp -f ../lib/*esmumps*.a $(PREFIX)/$(SCOTCH)/lib)
endif

scotch: $(PREFIX)/$(SCOTCH)/lib/libscotch.a
.PHONY: scotch


###
### MUMPS
###

$(MUMPS).tar.gz:
	wget https://mumps-solver.org/$@

$(MUMPS): $(MUMPS).tar.gz
	rm -rf $@
	tar zxvf $<
	touch $@

MUMPS_DEPS = $(MUMPS) metis scotch
ifneq ($(MPI), NONE)
  MUMPS_DEPS += $(MPI_INST) parmetis
endif

ifneq ($(MPI), NONE)
  ifeq ($(BLASLAPACK), OpenBLAS)
    MUMPS_DEPS += scalapack
  endif
  ifeq ($(BLASLAPACK), ATLAS)
    MUMPS_DEPS += scalapack
  endif
  ifeq ($(BLASLAPACK), SYSTEM)
    ifneq ($(HAVE_SCALAPACK), true)
      MUMPS_DEPS += scalapack
    endif
  endif
endif

ifneq ($(MPI), NONE)
$(PREFIX)/$(MUMPS)/lib/libdmumps.a: $(MUMPS_DEPS)
	perl -pe \
	"s!%scotch_dir%!$(PREFIX)/$(SCOTCH)!; \
	s!%metis_dir%!$(PREFIX)/$(PARMETIS)!; \
	s!%mpicc%!$(MPICC)!; \
	s!%mpif90%!$(MPIF90)!; \
	s!%lapack_libs%!$(LAPACKLIB)!; \
	s!%scalapack_libs%!$(SCALAPACKLIB)!; \
	s!%blas_libs%!$(BLASLIB)!; \
	s!%fcflags%!$(FCFLAGS) $(NOFOR_MAIN) $(OMPFLAGS)!; \
	s!%ldflags%!$(FCFLAGS) $(NOFOR_MAIN_LD) $(OMPFLAGS)!; \
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
else
$(PREFIX)/$(MUMPS)/lib/libdmumps.a: $(MUMPS_DEPS)
	perl -pe \
	"s!%scotch_dir%!$(PREFIX)/$(SCOTCH)!; \
	s!%metis_dir%!$(PREFIX)/$(PARMETIS)!; \
	s!%mpicc%!$(MPICC)!; \
	s!%mpif90%!$(MPIF90)!; \
	s!%lapack_libs%!$(LAPACKLIB)!; \
	s!%scalapack_libs%!$(SCALAPACKLIB)!; \
	s!%blas_libs%!$(BLASLIB)!; \
	s!%fcflags%!$(FCFLAGS) $(NOFOR_MAIN) $(OMPFLAGS)!; \
	s!%ldflags%!$(FCFLAGS) $(NOFOR_MAIN_LD) $(OMPFLAGS)!; \
	s!%cflags%!$(CFLAGS) $(NOFOR_MAIN_C) $(OMPFLAGS)!;" \
	MUMPS_Makefile.inc.seq > $(MUMPS)/Makefile.inc  ### to be fixed
ifeq ($(metisversion), 4)
	perl -i -pe \
	"s!Dmetis!Dmetis4!; \
	s!Dparmetis!Dparmetis3!; \
	if(/^IMETIS/){s!include!include -I$(PREFIX)/$(PARMETIS)/include/METISLib!;}" \
	$(MUMPS)/Makefile.inc
endif
	(cd $(MUMPS) && make -j $(NJOBS) && \
	if [ ! -d $(PREFIX)/$(MUMPS) ]; then mkdir $(PREFIX)/$(MUMPS); fi && \
	cp -r lib include $(PREFIX)/$(MUMPS)/. && \
	cp libseq/libmpiseq.a $(PREFIX)/$(MUMPS)/lib/.)
endif

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
	-D CMAKE_C_COMPILER=\"$(MPICC)\" \
	-D CMAKE_C_FLAGS=\"$(CFLAGS)\" \
	-D CMAKE_CXX_COMPILER=\"$(MPICXX)\" \
	-D CMAKE_CXX_FLAGS=\"$(CXXFLAGS)\" \
	-D Trilinos_ENABLE_CXX11=ON \
	-D Trilinos_ENABLE_Fortran:BOOL=OFF \
	-D Trilinos_ENABLE_OpenMP:BOOL=ON \
	-D OpenMP_C_FLAGS=$(OMPFLAGS) \
	-D OpenMP_CXX_FLAGS=$(OMPFLAGS) \
	-D Trilinos_ENABLE_Epetra=ON \
	-D Trilinos_ENABLE_Amesos=ON \
	-D Trilinos_ENABLE_ML=ON \
	-D ML_ENABLE_Amesos=ON \
	-D TPL_ENABLE_METIS=ON \
	-D METIS_INCLUDE_DIRS=$(PREFIX)/$(PARMETIS)/include \
	-D METIS_LIBRARY_DIRS=$(PREFIX)/$(PARMETIS)/lib \
	-D TPL_ENABLE_Scotch=ON \
	-D Scotch_INCLUDE_DIRS=$(PREFIX)/$(SCOTCH)/include \
	-D Scotch_LIBRARY_DIRS=$(PREFIX)/$(SCOTCH)/lib \
	-D TPL_ENABLE_BLAS=ON \
	-D TPL_ENABLE_LAPACK=ON \
	-D TPL_BLAS_LIBRARIES:STRING=\"$(BLASLIB)\" \
	-D TPL_LAPACK_LIBRARIES:STRING=\"$(LAPACKLIB)\" \
	-D CMAKE_INSTALL_LIBDIR:STRING=lib \
	-D CMAKE_INSTALL_PREFIX=$(PREFIX)/$(TRILINOS)
ifneq ($(MPI), NONE)
TRILINOS_CMAKE_OPTS += \
	-D TPL_ENABLE_MPI=ON \
	-D MPI_EXEC=$(MPIEXEC) \
	-D Trilinos_ENABLE_Zoltan=ON \
	-D TPL_ENABLE_ParMETIS=ON \
	-D ParMETIS_INCLUDE_DIRS=$(PREFIX)/$(PARMETIS)/include \
	-D ParMETIS_LIBRARY_DIRS=$(PREFIX)/$(PARMETIS)/lib \
	-D TPL_ENABLE_MUMPS=ON \
	-D MUMPS_INCLUDE_DIRS=$(PREFIX)/$(MUMPS)/include \
	-D MUMPS_LIBRARY_DIRS=$(PREFIX)/$(MUMPS)/lib
endif

TRILINOS_DEPS = Trilinos-$(TRILINOS) metis scotch mumps
ifneq ($(MPI), NONE)
  TRILINOS_DEPS += $(MPI_INST) parmetis
endif

$(PREFIX)/$(TRILINOS)/lib/libml.a: $(TRILINOS_DEPS)
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
	perl -pe \
	"s!%arch%!$(ARCH)!; \
	s!%cc%!$(CC)!; \
	s!%cflags%!$(CFLAGS)!; \
	s!%cxx%!$(CXX)!; \
	s!%cxxflags%!$(CXXFLAGS)!; \
	s!%f90%!$(F90)!; \
	s!%f90flags%!$(FCFLAGS)!; \
	s!%libstdcxx%!$(LIBSTDCXX)!;" \
	REVOCAP_Refiner_MakefileConfig.in > $(REFINER)/MakefileConfig.in
	(cd $(REFINER); \
	make -j $(NJOBS) Refiner; \
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

ifneq ($(MPI), NONE)
  SCOTCH_LIBS = -L$(PREFIX)/$(SCOTCH)/lib -lptesmumps -lptscotch -lscotch -lptscotcherr
else
  SCOTCH_LIBS = -L$(PREFIX)/$(SCOTCH)/lib -lesmumps -lscotch -lscotcherr
endif

F90LDFLAGS := $(SCOTCH_LIBS) $(SCALAPACKLIB) $(LAPACKLIB) $(BLASLIB) $(OMPFLAGS) $(LIBMPICXX) $(LIBSTDCXX)
ifeq ($(MPI), NONE)
  F90LDFLAGS := -L$(PREFIX)/$(MUMPS)/lib -lmpiseq $(F90LDFLAGS)
endif

ifeq ($(fistrbuild), old)
#
# Old style build with setup.sh
#
FISTR_SETUP_OPTS = --with-tools --with-metis --with-mumps --with-ml --with-lapack
ifneq ($(MPI), NONE)
  FISTR_SETUP_OPTS += -p --with-parmetis
endif

ifeq ($(BLASLAPACK), MKL)
ifeq ($(SCALAPACK), MKL)
  FISTR_SETUP_OPTS += --with-mkl
endif
endif

ifeq ($(WITH_REFINER), 1)
  FISTR_SETUP_OPTS += --with-refiner
endif

FISTR_DEPS = $(FISTR) metis mumps trilinos
ifneq ($(MPI), NONE)
  FISTR_DEPS += parmetis
endif

$(PREFIX)/$(FISTR)/bin/fistr1: $(FISTR_DEPS)
	perl -pe \
	"s!%metis_dir%!$(PREFIX)/$(PARMETIS)!; \
	s!%refiner_dir%!$(PREFIX)/$(REFINER)!; \
	s!%coupler_dir%!$(PREFIX)/$(COUPLER)!; \
	s!%mumps_dir%!$(PREFIX)/$(MUMPS)!; \
	s!%trilinos_dir%!$(PREFIX)/$(TRILINOS)!; \
	s!%ml_libs%!`perl get_ml_libs.pl $(PREFIX)/$(TRILINOS)/lib/cmake/Trilinos/TrilinosConfig.cmake`!; \
	s!%mpicc%!$(MPICC)!; \
	s!%cflags%!$(OMPFLAGS)!; \
	s!%ldflags%!$(OMPFLAGS) -lm $(LIBMPICXX) $(LIBSTDCXX)!; \
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
ifeq ($(BLASLAPACK), MKL)
	perl -i -pe \
	"s!%mkl_dir%!$(MKLROOT)!; \
	s!%mkl_libdir%!$(MKL_LIBDIR)!;" \
	$(FISTR)/Makefile.conf
endif
	(cd $(FISTR) && \
	./setup.sh $(FISTR_SETUP_OPTS) && \
	(cd hecmw1 && make -j $(NJOBS_F)) && (cd fistr1 && make -j $(NJOBS_F)) && \
	if [ ! -d $(PREFIX)/$(FISTR)/bin ]; then mkdir -p $(PREFIX)/$(FISTR)/bin; fi && \
	cp hecmw1/bin/* fistr1/bin/* $(PREFIX)/$(FISTR)/bin/.)
	@echo
	@echo "Build completed."
	@echo "Commands (fistr1, hecmw_part1, etc.) are located in $(PREFIX)/$(FISTR)/bin."
	@echo "Please add $(PREFIX)/$(FISTR)/bin to your PATH environment variable (or copy files in $(PREFIX)/$(FISTR)/bin to one of the directories in your PATH environment variable)."
	@echo
### End of old style build with setup.sh

else
#
# New style build with CMake
#
FISTR_CMAKE_OPTS = \
	-D CMAKE_EXPORT_COMPILE_COMMANDS=1 \
	-D CMAKE_BUILD_TYPE=$(BUILD_TYPE) \
	-D CMAKE_C_COMPILER=\"$(MPICC)\" \
	-D CMAKE_C_FLAGS=\"$(CFLAGS)\" \
	-D CMAKE_CXX_COMPILER=\"$(MPICXX)\" \
	-D CMAKE_CXX_FLAGS=\"$(CFLAGS)\" \
	-D CMAKE_Fortran_COMPILER=\"$(MPIF90)\" \
	-D CMAKE_Fortran_FLAGS=\"$(FCFLAGS) $(OMPFLAGS)\" \
	-D WITH_TOOLS=1 \
	-D WITH_OPENMP=1 \
	-D WITH_REFINER=$(WITH_REFINER) \
	-D WITH_REVOCAP=0 \
	-D WITH_METIS=1 \
	-D METIS_INCLUDE_PATH=$(PREFIX)/$(PARMETIS)/include \
	-D METIS_LIBRARIES=$(PREFIX)/$(PARMETIS)/lib/libmetis.a \
	-D WITH_LAPACK=1 \
	-D WITH_ML=1 \
	-D CMAKE_PREFIX_PATH=$(PREFIX)/$(TRILINOS) \
	-D WITH_DOC=0 \
	-D BLAS_LIBRARIES=\"$(BLASLIB)\" \
	-D LAPACK_LIBRARIES=\"$(LAPACKLIB)\" \
	-D OpenMP_C_FLAGS=$(OMPFLAGS) \
	-D OpenMP_CXX_FLAGS=$(OMPFLAGS) \
	-D OpenMP_Fortran_FLAGS=$(OMPFLAGS) \
	-D CMAKE_INSTALL_PREFIX=$(PREFIX)/$(FISTR)

ifneq ($(MPI), NONE)
FISTR_CMAKE_OPTS += \
	-D WITH_MPI=1 \
	-D WITH_PARMETIS=1 \
	-D PARMETIS_INCLUDE_PATH=$(PREFIX)/$(PARMETIS)/include \
	-D PARMETIS_LIBRARIES=$(PREFIX)/$(PARMETIS)/lib/libparmetis.a \
	-D WITH_MUMPS=1 \
	-D MUMPS_INCLUDE_PATH=$(PREFIX)/$(MUMPS)/include \
	-D MUMPS_LIBRARIES=\"$(PREFIX)/$(MUMPS)/lib/libdmumps.a;$(PREFIX)/$(MUMPS)/lib/libmumps_common.a;$(PREFIX)/$(MUMPS)/lib/libpord.a;$(PREFIX)/$(SCOTCH)/lib/libptesmumps.a;$(PREFIX)/$(SCOTCH)/lib/libptscotch.a;$(PREFIX)/$(SCOTCH)/lib/libptscotcherr.a;$(PREFIX)/$(SCOTCH)/lib/libscotch.a\" \
	-D SCALAPACK_LIBRARIES=\"$(SCALAPACKLIB)\"
else
FISTR_CMAKE_OPTS += \
	-D WITH_MPI=OFF \
	-D WITH_MUMPS=1 \
	-D MUMPS_INCLUDE_PATH=$(PREFIX)/$(MUMPS)/include \
	-D MUMPS_LIBRARIES=\"$(PREFIX)/$(MUMPS)/lib/libdmumps.a;$(PREFIX)/$(MUMPS)/lib/libmumps_common.a;$(PREFIX)/$(MUMPS)/lib/libpord.a;$(PREFIX)/$(MUMPS)/lib/libmpiseq.a;$(PREFIX)/$(SCOTCH)/lib/libesmumps.a;$(PREFIX)/$(SCOTCH)/lib/libscotch.a;$(PREFIX)/$(SCOTCH)/lib/libscotcherr.a\"
endif

ifeq ($(WITH_REFINER), 1)
FISTR_CMAKE_OPTS += \
	-D REFINER_INCLUDE_PATH=$(PREFIX)/$(REFINER)/include \
	-D REFINER_LIBRARIES=$(PREFIX)/$(REFINER)/lib/libRcapRefiner.a
endif

ifeq ($(BLASLAPACK), MKL)
FISTR_CMAKE_OPTS += \
	-D BLA_VENDOR=\"Intel10_64lp\"
ifeq ($(SCALAPACK), MKL)
FISTR_CMAKE_OPTS += \
	-D WITH_MKL=ON \
	-D MKL_INCLUDE_PATH=$(MKLROOT)/include \
	-D MKL_LIBRARIES=\"$(BLASLIB)\"
else
FISTR_CMAKE_OPTS += \
	-D WITH_MKL=OFF
endif
else
FISTR_CMAKE_OPTS += \
	-D WITH_MKL=OFF
endif

ifeq ($(BLASLAPACK), FUJITSU)
FISTR_CMAKE_OPTS += \
	-D CMAKE_Fortran_MODDIR_FLAG=-M
endif

FISTR_DEPS = $(FISTR) metis mumps trilinos
ifneq ($(MPI), NONE)
FISTR_DEPS += $(MPI_INST) parmetis
endif

$(PREFIX)/$(FISTR)/bin/fistr1: $(FISTR_DEPS)
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
ifeq ($(MPI), OPENMPI)
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
