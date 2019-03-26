# autofistr

autofistr is a build support tool for FrontISTR.
FrontISTR will be built with both MPI and OpenMP enabled
and with most of the usefull external libraries, such as METIS, ParMETIS, Scotch, MUMPS, Trilinos/ML.
If you have REVOCAP_Refiner downloaded in the top directory, it will be built together as well.

Please make sure that you accept all the license agreements of FrontISTR and its external packages
before you use this tool.


## System Requirements
1. Operating Systems: Linux, Mac OS X

2. Compilers: Intel, GCC, FUJITSU

### cmake
The build system uses cmake >= 2.8.11.
If supported version of cmake is not found, cmake source archive will be downloaded and built automatically.


## Editing Makefile.in

### Build type
- RELEASE : optimized build
- DEBUG : debug build

### Compiler
On Linux, Intel Compiler, GCC and FUJITSU Compiler are supported.
On Mac OS X, GCC is supported.

### MPI
Intel MPI, OpenMPI, MPICH and FUJITSU MPI are supported.

Intel MPI, OpenMPI and MPICH can be used with either Intel Compiler or GCC.
FUJITSU MPI can be used only with FUJITSU Compiler.

If you specified to use OpenMPI or MPICH and it is not found in your PATH,
source archive of the specified MPI will be downloaded and built automatically.

### BLAS/LAPACK/SCALAPACK
Any BLAS/LAPACK/SCALAPACK can be used; e.g. Intel MKL, OpenBLAS, ATLAS, FUJITSU SSL2.

If you want to use BLAS/LAPACK/SCALAPACK already installed on your system, set BLASLAPACK = SYSTEM
and make sure that BLASLIB/LAPACKLIB/SCALAPACKLIB are correctly set in Makefile.in.

Intel MKL, OpenBLAS and ATLAS can be used with either Intel Compiler or GCC.
FUJITSU SSL2 can be used only with FUJITSU Compiler.

If you choose to use OpenBLAS or ATLAS, netlib scalapack will be downloaded and built automatically.

### Number of Jobs
cmake supports parallel build.
You can specify the number of parallel job for the build.

### Other Options
If fistrbuild = old is set, the old style build with setup.sh is used instead of cmake.

If metisversion = 4 is set, metis4/parmetis3 is used instead of metis5/parmetis4.


## Download FrontISTR (Optional)
If you want to use specific version of FrontISTR, download and extract the source archive before running make.
Souce tree has to be found with the name FrontISTR at the same level with Makefile.

If you skip this process, the current master branch from Github will be downloaded automatically.


## Download REVOCAP_Refiner (Optional)
If you want to use REVOCAP_Refiner, download REVOCAP_Refiner-1.1.04.tar.gz from www.frontistr.org.
The archive has to be found at the same level with Makefile.


## Running make
Just type `make' and wait.
Everything will be done automatically.


## Setting PATH
If all process was successful, you will see message to set environment variables such as PATH,
so please follow the instruction.


## Running FrontISTR
If MPICH or OpenMPI was downloaded and built, make sure that you use mpirun that is built by this tool
when running FrontISTR.


## License
This project is licensed under the MPI License.
