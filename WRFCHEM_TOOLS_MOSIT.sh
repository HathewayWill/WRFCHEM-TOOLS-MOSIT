#!/bin/bash
# Non-interactive mode when called from another script (args passed) or env flag set
NONINTERACTIVE=0
if [[ -n "${MOSIT_NONINTERACTIVE:-}" ]] || [[ $# -ge 1 ]] || [[ ! -t 0 ]]; then
  NONINTERACTIVE=1
fi

# Conda environment test
if [ -n "$CONDA_DEFAULT_ENV" ]; then
  echo "CONDA_DEFAULT_ENV is active: $CONDA_DEFAULT_ENV"
  echo "Turning off $CONDA_DEFAULT_ENV"
  conda deactivate
  conda deactivate
else
  echo "CONDA_DEFAULT_ENV is not active."
  echo "Continuing script"
fi

start=$(date)
START=$(date +"%s")

############################### Version Numbers ##########################
# For Ease of updating
##########################################################################
export Zlib_Version=1.3.1
export Mpich_Version=4.3.2
export Libpng_Version=1.6.51
export Jasper_Version=1.900.1
export HDF5_Version=1.14.6
export Pnetcdf_Version=1.14.1
export Netcdf_C_Version=4.9.3
export Netcdf_Fortran_Version=4.6.2
export Netcdf_CXX_Version=4.3.1

############################### Citation Requirement  ####################
if [[ "$NONINTERACTIVE" -eq 0 ]]; then
  echo " "
  echo " The GitHub software WRF-MOSIT (Version 2.1.1) by W. Hatheway (2023)"
  echo " "
  echo "It is important to note that any usage or publication that incorporates or references this software must include a proper citation to acknowledge the work of the author."
  echo " "
  echo -e "This is not only a matter of respect and academic integrity, but also a \e[31mrequirement\e[0m set by the author. Please ensure to adhere to this guideline when using this software."
  echo " "
  echo -e "\e[31mCitation: Hatheway, W., Snoun, H., ur Rehman, H., & Mwanthi, A. WRF-MOSIT: a modular and cross-platform tool for configuring and installing the WRF model [Computer software]. https://doi.org/10.1007/s12145-023-01136-y]\e[0m"

  echo " "
  read -p "Press enter to continue"
fi
############################### System Architecture Type #################
# Determine if the system is 32 or 64-bit based on the architecture
##########################################################################
export SYS_ARCH=$(uname -m)

if [ "$SYS_ARCH" = "x86_64" ] || [ "$SYS_ARCH" = "arm64" ] || [ "$SYS_ARCH" = "aarch64" ]; then
  export SYSTEMBIT="64"
else
  export SYSTEMBIT="32"
fi

# Determine if aarch64 is present
if [ "$SYS_ARCH" = "aarch64" ]; then
  export aarch64=1
fi

# Determine the chip type if on macOS (ARM or Intel)
if [ "$SYS_ARCH" = "arm64" ]; then
  export MAC_CHIP="ARM"
else
  export MAC_CHIP="Intel"
fi

############################# System OS Version #############################
# Detect if the OS is macOS or Linux
#############################################################################
export SYS_OS=$(uname -s)

if [ "$SYS_OS" = "Darwin" ]; then
  export SYSTEMOS="MacOS"
  # Get the macOS version using sw_vers
  export MACOS_VERSION=$(sw_vers -productVersion)
  echo "Operating system detected: MacOS, Version: $MACOS_VERSION"
elif [ "$SYS_OS" = "Linux" ]; then
  export SYSTEMOS="Linux"
fi

########## RHL and Linux Distribution Detection #############
# More accurate Linux distribution detection using /etc/os-release
########## Linux Distribution + Package Manager Detection ##########
if [ "$SYSTEMOS" = "Linux" ]; then
  if [ -r /etc/os-release ]; then
    . /etc/os-release

    # Human-friendly info
    DISTRO_NAME="${NAME:-Linux}"
    DISTRO_VERSION="${VERSION_ID:-unknown}"
    echo "Operating system detected: $DISTRO_NAME, Version: $DISTRO_VERSION"

    # Classify distro family using ID / ID_LIKE (more reliable than checking yum/dnf)
    # We'll use SYSTEMOS values you already branch on: "RHL" or "Linux"
    case " ${ID:-} ${ID_LIKE:-} " in
      *" rhel "* | *" fedora "* | *" centos "* | *" rocky "* | *" almalinux "*)
        SYSTEMOS="RHL"
        ;;
      *" debian "* | *" ubuntu "*)
        SYSTEMOS="Linux" # keep your existing "Linux" meaning Debian/Ubuntu path
        ;;
      *)
        SYSTEMOS="Linux" # unknowns fall back to generic Linux path
        ;;
    esac

    # Choose package manager (used for installs, not OS identity)
    if command -v dnf > /dev/null 2>&1; then
      PKG_MGR="dnf"
    elif command -v yum > /dev/null 2>&1; then
      PKG_MGR="yum"
    elif command -v apt-get > /dev/null 2>&1; then
      PKG_MGR="apt"
    else
      PKG_MGR="none"
    fi

    echo "Final operating system detected: $SYSTEMOS"
    echo "Package manager detected: $PKG_MGR"
  else
    echo "Unable to detect the Linux distribution version (missing /etc/os-release)."
    SYSTEMOS="Linux"
    PKG_MGR="none"
  fi
fi

# Print the final detected OS
echo "Final operating system detected: $SYSTEMOS"

############################### Intel or GNU Compiler Option #############

# Only proceed with RHL-specific logic if the system is RHL
if [ "$SYSTEMOS" = "RHL" ]; then
  # Check for 32-bit RHL system
  if [ "$SYSTEMBIT" = "32" ]; then
    echo "Your system is not compatible with this script."
    exit
  fi

  # Check for 64-bit RHL system
  if [ "$SYSTEMBIT" = "64" ]; then
    echo "Your system is a 64-bit version of RHL Linux Kernel."

    # Check if RHL_64bit_Intel or RHL_64bit_GNU environment variables are set
    if [ -n "$RHL_64bit_Intel" ] || [ -n "$RHL_64bit_GNU" ]; then
      echo "The environment variable RHL_64bit_Intel/GNU is already set."
    else
      echo "The environment variable RHL_64bit_Intel/GNU is not set."

      # Prompt user to select a compiler (Intel or GNU)
      while read -r -p "Which compiler do you want to use?
                - Intel
                - GNU
                Please answer Intel or GNU and press enter (case-sensitive): " yn; do
        case $yn in
          Intel)
            echo "Intel is selected for installation."
            export RHL_64bit_Intel=1
            break
            ;;
          GNU)
            echo "GNU is selected for installation."
            export RHL_64bit_GNU=1
            break
            ;;
          *)
            echo "Please answer Intel or GNU (case-sensitive)."
            ;;
        esac
      done
    fi

    # Check for the version of the GNU compiler (gcc)
    if [ -n "$RHL_64bit_GNU" ]; then
      export gcc_test_version=$(gcc -dumpversion 2>&1 | awk '{print $1}')
      export gcc_test_version_major=$(echo $gcc_test_version | awk -F. '{print $1}')
      export gcc_version_9="9"

      if [[ $gcc_test_version_major -lt $gcc_version_9 ]]; then
        export RHL_64bit_GNU=2
        echo "OLD GNU FILES FOUND."
        echo "RHL_64bit_GNU=$RHL_64bit_GNU"
      fi
    fi
  fi
fi

# Check for 64-bit Linux system (Debian/Ubuntu)
if [ "$SYSTEMBIT" = "64" ] && [ "$SYSTEMOS" = "Linux" ]; then
  echo "Your system is a 64-bit version of Linux Kernel."
  echo ""

  # Check if Ubuntu_64bit_Intel or Ubuntu_64bit_GNU environment variables are set
  if [ -n "$Ubuntu_64bit_Intel" ] || [ -n "$Ubuntu_64bit_GNU" ]; then
    echo "The environment variable Ubuntu_64bit_Intel/GNU is already set."
  else
    echo "The environment variable Ubuntu_64bit_Intel/GNU is not set."

    # Prompt user to select a compiler (Intel or GNU)
    while read -r -p "Which compiler do you want to use?
            - Intel
            -- ****GNU only for aarch64 based systems****
            -- Please note that WRF_CMAQ is only compatible with GNU Compilers

            - GNU

            Please answer Intel or GNU and press enter (case-sensitive): " yn; do
      case $yn in
        Intel)
          echo "Intel is selected for installation."
          export Ubuntu_64bit_Intel=1
          break
          ;;
        GNU)
          echo "GNU is selected for installation."
          export Ubuntu_64bit_GNU=1
          break
          ;;
        *)
          echo "Please answer Intel or GNU (case-sensitive)."
          ;;
      esac
    done
  fi
fi

# Check for 32-bit Linux system
if [ "$SYSTEMBIT" = "32" ] && [ "$SYSTEMOS" = "Linux" ]; then
  echo "Your system is not compatible with this script."
  exit
fi

############################# macOS Handling ##############################

# Check for 32-bit MacOS system
if [ "$SYSTEMBIT" = "32" ] && [ "$SYSTEMOS" = "MacOS" ]; then
  echo "Your system is not compatible with this script."
  exit
fi

# Check for 64-bit Intel-based MacOS system
if [ "$SYSTEMBIT" = "64" ] && [ "$SYSTEMOS" = "MacOS" ] && [ "$MAC_CHIP" = "Intel" ]; then
  echo "Your system is a 64-bit version of macOS with an Intel chip."
  echo "Intel compilers are not compatible with this script."
  echo "Setting compiler to GNU."
  export macos_64bit_GNU=1

  # Ensure Xcode Command Line Tools are installed
  if ! xcode-select --print-path &> /dev/null; then
    echo "Installing Xcode Command Line Tools..."
    xcode-select --install

    # Add a loop to wait for the installation to be completed
    echo "Waiting for Xcode Command Line Tools to install. Please follow the installer prompts..."
    while ! xcode-select --print-path &> /dev/null; do
      sleep 5 # Wait for 5 seconds before checking again
    done

    echo "Xcode Command Line Tools installation confirmed."
  fi

  # Install Homebrew for Intel Macs in /usr/local
  echo "Installing Homebrew..."
  /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"

  echo 'eval "$(/usr/local/bin/brew shellenv)"' >> ~/.profile
  eval "$(/usr/local/bin/brew shellenv)"

  chsh -s /bin/bash
fi

# Check for 64-bit ARM-based MacOS system (M1, M2 chips)
if [ "$SYSTEMBIT" = "64" ] && [ "$SYSTEMOS" = "MacOS" ] && [ "$MAC_CHIP" = "ARM" ]; then
  echo "Your system is a 64-bit version of macOS with an ARM chip (M1/M2)."
  echo "Intel compilers are not compatible with this script."
  echo "Setting compiler to GNU."
  export macos_64bit_GNU=1

  # Ensure Xcode Command Line Tools are installed
  if ! xcode-select --print-path &> /dev/null; then
    echo "Installing Xcode Command Line Tools..."
    xcode-select --install

    # Add a loop to wait for the installation to be completed
    echo "Waiting for Xcode Command Line Tools to install. Please follow the installer prompts..."
    while ! xcode-select --print-path &> /dev/null; do
      sleep 5 # Wait for 5 seconds before checking again
    done

    echo "Xcode Command Line Tools installation confirmed."
  fi

  # Install Homebrew for ARM Macs in /opt/homebrew
  echo "Installing Homebrew..."
  /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"

  echo 'eval "$(/opt/homebrew/bin/brew shellenv)"' >> ~/.profile
  eval "$(/opt/homebrew/bin/brew shellenv)"

  chsh -s /bin/bash
fi

############################# Enter sudo users information #############################
echo "-------------------------------------------------- "

# 1) Accept PASSWD from environment OR arg1 (WRF-MOSIT passes both)
if [[ -z "${PASSWD:-}" && -n "${1:-}" ]]; then
  export PASSWD="$1"
fi

# 2) If PASSWD exists, skip prompting
if [[ -n "${PASSWD:-}" ]]; then
  echo "Using sudo password passed in from parent script."
else
  while true; do
    read -r -s -p "
    Password is only saved locally and will not be seen when typing.
    Please enter your sudo password: " password1
    echo
    read -r -s -p "Please re-enter your password to verify: " password2
    echo

    if [[ "$password1" == "$password2" ]]; then
      export PASSWD="$password1"
      echo "Password verified successfully."
      break
    else
      echo "Passwords do not match. Please enter the passwords again."
    fi
  done
fi

echo "Beginning Installation"

##################################### WRFCHEM Tools ###############################################
# This script will install the WRFCHEM pre-processor tools.
# Information on these tools can be found here:
# https://www2.acom.ucar.edu/wrf-chem/wrf-chem-tools-community#download
#
# Addtional information on WRFCHEM can be found here:
# https://ruc.noaa.gov/wrf/wrf-chem/
#
# We ask users of the WRF-Chem preprocessor tools to include in any publications the following acknowledgement:
# "We acknowledge use of the WRF-Chem preprocessor tool {mozbc, fire_emiss, etc.} provided by the Atmospheric Chemistry Observations and Modeling Lab (ACOM) of NCAR."
#
#
# This script installs the WRFCHEM Tools with gnu or intel compilers.
####################################################################################################

if [ "$RHL_64bit_GNU" = "1" ]; then

  # Basic Package Management for WRF-CHEM Tools and Processors
  export HOME=$(
    cd ~ \
      && pwd
  )

  #Basic Package Management for Model Evaluation Tools (MET)
  echo $PASSWD | sudo -S yum install epel-release -y
  echo $PASSWD | sudo -S yum install dnf -y
  echo $PASSWD | sudo -S dnf install epel-release -y
  echo $PASSWD | sudo -S dnf -y update
  echo $PASSWD | sudo -S dnf -y upgrade
  echo $PASSWD | sudo -S dnf -y install byacc bzip2 bzip2-devel cairo-devel cmake cpp curl curl-devel flex fontconfig fontconfig-devel gcc gcc-c++ gcc-gfortran git ksh libjpeg libjpeg-devel libstdc++ libstdc++-devel libX11 libX11-devel libXaw libXaw-devel libXext-devel libXmu libXmu-devel libXrender libXrender-devel libXt libXt-devel libxml2 libxml2-devel libgeotiff libgeotiff-devel libtiff libtiff-devel m4 nfs-utils perl 'perl(XML::LibXML)' pkgconfig pixman pixman-devel python3 python3-devel tcsh time unzip wget
  echo $PASSWD | sudo -S dnf install -y java java-devel
  echo $PASSWD | sudo -S dnf install -y java-17-openjdk-devel java-17-openjdk
  echo $PASSWD | sudo -S dnf install -y java-21-openjdk-devel java-21-openjdk
  echo $PASSWD | sudo -S dnf -y install python3-dateutil
  echo $PASSWD | sudo -S dnf -y groupinstall "Development Tools"
  echo $PASSWD | sudo -S dnf -y update
  echo $PASSWD | sudo -S dnf -y upgrade
  echo " "

  #Directory Listings
  export HOME=$(
    cd ~ \
      && pwd
  )
  mkdir $HOME/WRFCHEM
  export WRF_FOLDER=$HOME/WRFCHEM
  cd $HOME/WRFCHEM
  mkdir Downloads
  mkdir Libs
  mkdir Libs/grib2
  mkdir Libs/NETCDF
  mkdir "${WRF_FOLDER}"/WRF_CHEM_Tools
  mkdir "${WRF_FOLDER}"/WRF_CHEM_Tools/Libs
  mkdir "${WRF_FOLDER}"/WRF_CHEM_Tools/Libs/grib2
  mkdir "${WRF_FOLDER}"/WRF_CHEM_Tools/Libs/NETCDF
  mkdir "${WRF_FOLDER}"/WRF_CHEM_Tools/Downloads
  mkdir "${WRF_FOLDER}"/WRF_CHEM_Tools/mozbc
  mkdir "${WRF_FOLDER}"/WRF_CHEM_Tools/megan_bio_emiss
  mkdir "${WRF_FOLDER}"/WRF_CHEM_Tools/megan_bio_data
  mkdir "${WRF_FOLDER}"/WRF_CHEM_Tools/wes_coldens
  mkdir "${WRF_FOLDER}"/WRF_CHEM_Tools/ANTHRO_EMIS
  mkdir "${WRF_FOLDER}"/WRF_CHEM_Tools/EDGAR_HTAP
  mkdir "${WRF_FOLDER}"/WRF_CHEM_Tools/EPA_ANTHRO_EMIS
  mkdir "${WRF_FOLDER}"/WRF_CHEM_Tools/UBC
  mkdir "${WRF_FOLDER}"/WRF_CHEM_Tools/Aircraft
  mkdir "${WRF_FOLDER}"/WRF_CHEM_Tools/FINN
  mkdir "${WRF_FOLDER}"/WRF_CHEM_Tools/Tests
  mkdir "${WRF_FOLDER}"/WRF_CHEM_Tools/Tests/Environment
  mkdir "${WRF_FOLDER}"/WRF_CHEM_Tools/Tests/Compatibility

  ##############################Downloading Libraries############################
  cd "${WRF_FOLDER}"/WRF_CHEM_Tools/Downloads

  wget -c https://github.com/madler/zlib/releases/download/v$Zlib_Version/zlib-$Zlib_Version.tar.gz
  wget -c https://github.com/HDFGroup/hdf5/releases/download/hdf5_$HDF5_Version/hdf5-$HDF5_Version.tar.gz
  wget -c https://github.com/Unidata/netcdf-c/archive/refs/tags/v$Netcdf_C_Version.tar.gz
  wget -c https://github.com/Unidata/netcdf-fortran/archive/refs/tags/v$Netcdf_Fortran_Version.tar.gz
  wget -c https://download.sourceforge.net/libpng/libpng-$Libpng_Version.tar.gz
  wget -c https://www.ece.uvic.ca/~frodo/jasper/software/jasper-$Jasper_Version.zip
  wget -c https://github.com/pmodels/mpich/releases/download/v$Mpich_Version/mpich-$Mpich_Version.tar.gz
  wget -c https://parallel-netcdf.github.io/Release/pnetcdf-$Pnetcdf_Version.tar.gz

  #############################Core Management####################################

  export CPU_CORE=$(nproc) # number of available threads on system
  export CPU_6CORE="6"
  export CPU_QUARTER=$(($CPU_CORE / 4))                          #quarter of availble cores on system
  export CPU_QUARTER_EVEN=$(($CPU_QUARTER - ($CPU_QUARTER % 2))) #Forces CPU cores to even number to avoid partial core export. ie 7 cores would be 3.5 cores.

  if [ $CPU_CORE -le $CPU_6CORE ]; then #If statement for low core systems.  Forces computers to only use 1 core if there are 4 cores or less on the system. then
    export CPU_QUARTER_EVEN="2"
  else
    export CPU_QUARTER_EVEN=$(($CPU_QUARTER - ($CPU_QUARTER % 2)))
  fi

  echo "##########################################"
  echo "Number of Threads being used $CPU_QUARTER_EVEN"
  echo "##########################################"

  echo " "

  #############################Compilers############################
  export DIR="${WRF_FOLDER}"/WRF_CHEM_Tools/Libs
  export CC=gcc
  export CXX=g++
  export FC=gfortran
  export F77=gfortran
  export CFLAGS="-fPIC -fPIE -O3 -Wno-implicit-function-declaration -Wno-incompatible-pointer-types "

  #IF statement for GNU compiler issue
  export GCC_VERSION=$(/usr/bin/gcc -dumpfullversion | awk '{print$1}')
  export GFORTRAN_VERSION=$(/usr/bin/gfortran -dumpfullversion | awk '{print$1}')
  export GPLUSPLUS_VERSION=$(/usr/bin/g++ -dumpfullversion | awk '{print$1}')

  export GCC_VERSION_MAJOR_VERSION=$(echo $GCC_VERSION | awk -F. '{print $1}')
  export GFORTRAN_VERSION_MAJOR_VERSION=$(echo $GFORTRAN_VERSION | awk -F. '{print $1}')
  export GPLUSPLUS_VERSION_MAJOR_VERSION=$(echo $GPLUSPLUS_VERSION | awk -F. '{print $1}')

  export version_10="10"

  if [ $GCC_VERSION_MAJOR_VERSION -ge $version_10 ] || [ $GFORTRAN_VERSION_MAJOR_VERSION -ge $version_10 ] || [ $GPLUSPLUS_VERSION_MAJOR_VERSION -ge $version_10 ]; then
    export fallow_argument=-fallow-argument-mismatch
    export boz_argument=-fallow-invalid-boz
  else
    export fallow_argument=
    export boz_argument=
  fi

  export FFLAGS="$fallow_argument"
  export FCFLAGS="$fallow_argument"

  echo "##########################################"
  echo "FFLAGS = $FFLAGS"
  echo "FCFLAGS = $FCFLAGS"
  echo "CFLAGS = $CFLAGS"
  echo "##########################################"

  #############################zlib############################
  #Uncalling compilers due to comfigure issue with zlib$Zlib_Version
  #With CC & CXX definied ./configure uses different compiler Flags

  cd "${WRF_FOLDER}"/WRF_CHEM_Tools/Downloads
  env -u LD_LIBRARY_PATH tar -xzf zlib-$Zlib_Version.tar.gz
  cd zlib-$Zlib_Version/
  ./configure --prefix=$DIR/grib2 2>&1 | tee configure.log
  make -j $CPU_QUARTER_EVEN 2>&1 | tee make.log
  make -j $CPU_QUARTER_EVEN install 2>&1 | tee make.make.log

  ##############################MPICH############################
  cd "${WRF_FOLDER}"/WRF_CHEM_Tools/Downloads
  env -u LD_LIBRARY_PATH tar -xzf mpich-$Mpich_Version.tar.gz
  cd mpich-$Mpich_Version/
  F90= ./configure --prefix=$DIR/MPICH --with-device=ch3 FFLAGS=$FFLAGS FCFLAGS=$FCFLAGS 2>&1 | tee configure.log
  make -j $CPU_QUARTER_EVEN 2>&1 | tee make.log
  make -j $CPU_QUARTER_EVEN install 2>&1 | tee make.make.log

  export PATH=$DIR/MPICH/bin:$PATH

  export MPIFC=$DIR/MPICH/bin/mpifort
  export MPIF77=$DIR/MPICH/bin/mpifort
  export MPIF90=$DIR/MPICH/bin/mpifort
  export MPICC=$DIR/MPICH/bin/mpicc
  export MPICXX=$DIR/MPICH/bin/mpicxx

  echo " "

  #############################libpng############################
  cd "${WRF_FOLDER}"/WRF_CHEM_Tools/Downloads
  export LDFLAGS=-L$DIR/grib2/lib
  export CPPFLAGS=-I$DIR/grib2/include
  env -u LD_LIBRARY_PATH tar -xzf libpng-$Libpng_Version.tar.gz
  cd libpng-$Libpng_Version/
  CC=$MPICC FC=$MPIFC F77=$MPIF77 F90=$MPIF90 CXX=$MPICXX CFLAGS=$CFLAGS FFLAGS=$FFLAGS FCFLAGS=$FCFLAGS ./configure --prefix=$DIR/grib2 2>&1 | tee configure.log
  make -j $CPU_QUARTER_EVEN 2>&1 | tee make.log
  make -j $CPU_QUARTER_EVEN install 2>&1 | tee make.make.log

  #############################JasPer############################
  cd "${WRF_FOLDER}"/WRF_CHEM_Tools/Downloads
  unzip jasper-$Jasper_Version.zip
  cd jasper-$Jasper_Version/
  CC=$MPICC FC=$MPIFC F77=$MPIF77 F90=$MPIF90 CXX=$MPICXX CFLAGS=$CFLAGS FFLAGS=$FFLAGS FCFLAGS=$FCFLAGS ./configure --prefix=$DIR/grib2 2>&1 | tee configure.log
  make -j $CPU_QUARTER_EVEN 2>&1 | tee make.log
  make -j $CPU_QUARTER_EVEN install 2>&1 | tee make.make.log

  export JASPERLIB=$DIR/grib2/lib
  export JASPERINC=$DIR/grib2/include

  #############################hdf5 library for netcdf4 functionality############################
  cd "${WRF_FOLDER}"/WRF_CHEM_Tools/Downloads
  env -u LD_LIBRARY_PATH tar -xzf hdf5-$HDF5_Version.tar.gz
  cd hdf5-$HDF5_Version
  CC=$MPICC FC=$MPIFC F77=$MPIF77 F90=$MPIF90 CXX=$MPICXX CFLAGS=$CFLAGS FFLAGS=$FFLAGS FCFLAGS=$FCFLAGS ./configure --prefix=$DIR/grib2 --with-zlib=$DIR/grib2 --enable-hl --enable-fortran --enable-parallel 2>&1 | tee configure.log
  make -j $CPU_QUARTER_EVEN 2>&1 | tee make.log
  make -j $CPU_QUARTER_EVEN install 2>&1 | tee make.make.log

  export HDF5=$DIR/grib2
  export PHDF5=$DIR/grib2
  export LD_LIBRARY_PATH=$DIR/grib2/lib:$LD_LIBRARY_PATH

  echo " "

  #############################Install Parallel-netCDF##############################
  #Make file created with half of available cpu cores
  #Hard path for MPI added
  ##################################################################################
  cd "${WRF_FOLDER}"/WRF_CHEM_Tools/Downloads
  env -u LD_LIBRARY_PATH tar -xzf pnetcdf-$Pnetcdf_Version.tar.gz
  cd pnetcdf-$Pnetcdf_Version
  CC=$MPICC FC=$MPIFC F77=$MPIF77 F90=$MPIF90 CXX=$MPICXX CFLAGS=$CFLAGS FFLAGS=$FFLAGS FCFLAGS=$FCFLAGS ./configure --prefix=$DIR/grib2 --enable-shared --enable-static 2>&1 | tee configure.log
  make -j $CPU_QUARTER_EVEN 2>&1 | tee make.log
  make -j $CPU_QUARTER_EVEN install 2>&1 | tee make.make.log

  export PNETCDF=$DIR/grib2

  ##############################Install NETCDF C Library############################
  cd "${WRF_FOLDER}"/WRF_CHEM_Tools/Downloads
  env -u LD_LIBRARY_PATH tar -xzf v$Netcdf_C_Version.tar.gz
  cd netcdf-c-$Netcdf_C_Version/
  export CPPFLAGS=-I$DIR/grib2/include
  export LDFLAGS=-L$DIR/grib2/lib
  export LIBS="-lhdf5_hl -lhdf5 -lz -lcurl -lgfortran -lgcc -lm -ldl -lpnetcdf"
  CC=$MPICC FC=$MPIFC F77=$MPIF77 F90=$MPIF90 CXX=$MPICXX CFLAGS=$CFLAGS FFLAGS=$FFLAGS FCFLAGS=$FCFLAGS ./configure --prefix=$DIR/NETCDF --with-zlib=$DIR/grib2 --disable-dap --enable-netcdf-4 --enable-netcdf4 --enable-shared --enable-static --enable-pnetcdf --enable-cdf5 --enable-parallel-tests 2>&1 | tee configure.log
  make -j $CPU_QUARTER_EVEN 2>&1 | tee make.log
  make -j $CPU_QUARTER_EVEN install 2>&1 | tee make.make.log

  export PATH=$DIR/NETCDF/bin:$PATH
  export NETCDF=$DIR/NETCDF

  ##############################NetCDF fortran library############################
  cd "${WRF_FOLDER}"/WRF_CHEM_Tools/Downloads
  env -u LD_LIBRARY_PATH tar -xzf v$Netcdf_Fortran_Version.tar.gz
  cd netcdf-fortran-$Netcdf_Fortran_Version/
  export LD_LIBRARY_PATH=$DIR/NETCDF/lib:$LD_LIBRARY_PATH
  export CPPFLAGS="-I$DIR/NETCDF/include -I$DIR/grib2/include"
  export LDFLAGS="-L$DIR/NETCDF/lib -L$DIR/grib2/lib"
  export LIBS="-lnetcdf -lpnetcdf -lcurl -lhdf5_hl -lhdf5 -lz -ldl -lgcc -lgfortran"
  CC=$MPICC FC=$MPIFC F77=$MPIF77 F90=$MPIF90 CXX=$MPICXX CFLAGS=$CFLAGS FFLAGS=$FFLAGS FCFLAGS=$FCFLAGS ./configure --prefix=$DIR/NETCDF --enable-netcdf-4 --enable-netcdf4 --enable-shared --enable-static --enable-parallel-tests --enable-hdf5 2>&1 | tee configure.log
  make -j $CPU_QUARTER_EVEN 2>&1 | tee make.log
  make -j $CPU_QUARTER_EVEN install 2>&1 | tee make.make.log

  echo " "

  #################################### System Environment Tests ##############

  cd "${WRF_FOLDER}"/WRF_CHEM_Tools/Downloads
  wget -c https://www2.mmm.ucar.edu/wrf/OnLineTutorial/compile_tutorial/tar_files/Fortran_C_NETCDF_MPI_tests.tar
  wget -c https://www2.mmm.ucar.edu/wrf/OnLineTutorial/compile_tutorial/tar_files/Fortran_C_tests.tar

  env -u LD_LIBRARY_PATH tar -xvf Fortran_C_tests.tar -C "${WRF_FOLDER}"/WRF_CHEM_Tools/Tests/Environment
  env -u LD_LIBRARY_PATH tar -xvf Fortran_C_NETCDF_MPI_tests.tar -C "${WRF_FOLDER}"/WRF_CHEM_Tools/Tests/Compatibility

  export one="1"
  echo " "
  ############## Testing Environment #####

  cd "${WRF_FOLDER}"/WRF_CHEM_Tools/Tests/Environment

  cp ${NETCDF}/include/netcdf.inc .

  echo " "
  echo " "
  echo "Environment Testing "
  echo "Test 1"
  $FC TEST_1_fortran_only_fixed.f
  ./a.out | tee env_test1.txt
  export TEST_PASS=$(grep -w -o -c "SUCCESS" env_test1.txt | awk '{print$1}')
  if [ $TEST_PASS -ge 1 ]; then
    echo "Enviroment Test 1 Passed"
  else
    echo "Environment Compiler Test 1 Failed"
    exit
  fi
  read -r -t 3 -p "I am going to wait for 3 seconds only ..."

  echo " "
  echo "Test 2"
  $FC TEST_2_fortran_only_free.f90
  ./a.out | tee env_test2.txt
  export TEST_PASS=$(grep -w -o -c "SUCCESS" env_test2.txt | awk '{print$1}')
  if [ $TEST_PASS -ge 1 ]; then
    echo "Enviroment Test 2 Passed"
  else
    echo "Environment Compiler Test 2 Failed"
    exit
  fi
  echo " "
  read -r -t 3 -p "I am going to wait for 3 seconds only ..."

  echo " "
  echo "Test 3"
  $CC TEST_3_c_only.c
  ./a.out | tee env_test3.txt
  export TEST_PASS=$(grep -w -o -c "SUCCESS" env_test3.txt | awk '{print$1}')
  if [ $TEST_PASS -ge 1 ]; then
    echo "Enviroment Test 3 Passed"
  else
    echo "Environment Compiler Test 3 Failed"
    exit
  fi
  echo " "
  read -r -t 3 -p "I am going to wait for 3 seconds only ..."

  echo " "
  echo "Test 4"
  $CC -c -m64 TEST_4_fortran+c_c.c
  $FC -c -m64 TEST_4_fortran+c_f.f90
  $FC -m64 TEST_4_fortran+c_f.o TEST_4_fortran+c_c.o
  ./a.out | tee env_test4.txt
  export TEST_PASS=$(grep -w -o -c "SUCCESS" env_test4.txt | awk '{print$1}')
  if [ $TEST_PASS -ge 1 ]; then
    echo "Enviroment Test 4 Passed"
  else
    echo "Environment Compiler Test 4 Failed"
    exit
  fi
  echo " "
  read -r -t 3 -p "I am going to wait for 3 seconds only ..."

  echo " "
  ############## Testing Environment #####

  cd "${WRF_FOLDER}"/WRF_CHEM_Tools/Tests/Compatibility

  cp ${NETCDF}/include/netcdf.inc .

  echo " "
  echo " "
  echo "Library Compatibility Tests "
  echo "Test 1"
  $FC -c 01_fortran+c+netcdf_f.f
  $CC -c 01_fortran+c+netcdf_c.c
  $FC 01_fortran+c+netcdf_f.o 01_fortran+c+netcdf_c.o \
    -L${NETCDF}/lib -lnetcdff -lnetcdf

  ./a.out | tee comp_test1.txt
  export TEST_PASS=$(grep -w -o -c "SUCCESS" comp_test1.txt | awk '{print$1}')
  if [ $TEST_PASS -ge 1 ]; then
    echo "Compatibility Test 1 Passed"
  else
    echo "Compatibility Compiler Test 1 Failed"
    exit
  fi
  echo " "
  read -r -t 3 -p "I am going to wait for 3 seconds only ..."

  echo " "

  echo "Test 2"
  $MPIFC -c 02_fortran+c+netcdf+mpi_f.f
  $MPICC -c 02_fortran+c+netcdf+mpi_c.c
  $MPIFC 02_fortran+c+netcdf+mpi_f.o \
    02_fortran+c+netcdf+mpi_c.o \
    -L${NETCDF}/lib -lnetcdff -lnetcdf

  $DIR/MPICH/bin/mpirun ./a.out | tee comp_test2.txt
  export TEST_PASS=$(grep -w -o -c "SUCCESS" comp_test2.txt | awk '{print$1}')
  if [ $TEST_PASS -ge 1 ]; then
    echo "Compatibility Test 2 Passed"
  else
    echo "Compatibility Compiler Test 2 Failed"
    exit
  fi
  echo " "
  read -r -t 3 -p "I am going to wait for 3 seconds only ..."
  echo " "

  echo " All tests completed and passed"
  echo " "

  # Downloading WRF-CHEM Tools and untarring files
  cd "${WRF_FOLDER}"/WRF_CHEM_Tools/Downloads

  wget -c https://www.acom.ucar.edu/wrf-chem/mozbc.tar
  wget -c https://www.acom.ucar.edu/wrf-chem/UBC_inputs.tar
  wget -c https://www.acom.ucar.edu//wrf-chem/megan_bio_emiss.tar
  wget -c https://www.acom.ucar.edu/wrf-chem/megan.data.tar.gz
  wget -c https://www.acom.ucar.edu/wrf-chem/wes-coldens.tar
  wget -c https://www.acom.ucar.edu/wrf-chem/ANTHRO.tar
  wget -c https://www.acom.ucar.edu/webt/wrf-chem/processors/EDGAR-HTAP.tgz
  wget -c https://www.acom.ucar.edu/wrf-chem/EPA_ANTHRO_EMIS.tgz
  wget -c https://www2.acom.ucar.edu/sites/default/files/documents/aircraft_preprocessor_files.tar
  # Downloading FINN
  wget -c https://www.acom.ucar.edu/Data/fire/data/finn2/FINNv2.4_MOD_MOZART_2020_c20210617.txt.gz
  wget -c https://www.acom.ucar.edu/Data/fire/data/finn2/FINNv2.4_MOD_MOZART_2013_c20210617.txt.gz
  wget -c https://www.acom.ucar.edu/Data/fire/data/finn2/FINNv2.4_MODVRS_MOZART_2019_c20210615.txt.gz
  wget -c https://www.acom.ucar.edu/Data/fire/data/fire_emis.tgz
  wget -c https://www.acom.ucar.edu/Data/fire/data/fire_emis_input.tar
  wget -c https://www.acom.ucar.edu/Data/fire/data/TrashEmis.zip

  echo ""
  echo "Unpacking Mozbc."
  env -u LD_LIBRARY_PATH tar -xvf mozbc.tar -C "${WRF_FOLDER}"/WRF_CHEM_Tools/mozbc
  echo ""
  echo "Unpacking MEGAN Bio Emission."
  env -u LD_LIBRARY_PATH tar -xvf megan_bio_emiss.tar -C "${WRF_FOLDER}"/WRF_CHEM_Tools/megan_bio_emiss
  echo ""
  echo "Unpacking MEGAN Bio Emission Data."
  env -u LD_LIBRARY_PATH tar -xzf megan.data.tar.gz -C "${WRF_FOLDER}"/WRF_CHEM_Tools/megan_bio_data
  echo ""
  echo "Unpacking Wes Coldens"
  env -u LD_LIBRARY_PATH tar -xvf wes-coldens.tar -C "${WRF_FOLDER}"/WRF_CHEM_Tools/wes_coldens
  echo ""
  echo "Unpacking Unpacking ANTHRO Emission."
  env -u LD_LIBRARY_PATH tar -xvf ANTHRO.tar -C "${WRF_FOLDER}"/WRF_CHEM_Tools/ANTHRO_EMIS
  echo ""
  echo "Unpacking EDGAR-HTAP."
  env -u LD_LIBRARY_PATH tar -xzf EDGAR-HTAP.tgz -C "${WRF_FOLDER}"/WRF_CHEM_Tools/EDGAR_HTAP
  echo ""
  echo "Unpacking EPA ANTHRO Emission."
  env -u LD_LIBRARY_PATH tar -xzf EPA_ANTHRO_EMIS.tgz -C "${WRF_FOLDER}"/WRF_CHEM_Tools/EPA_ANTHRO_EMIS
  echo ""
  echo "Unpacking Upper Boundary Conditions."
  env -u LD_LIBRARY_PATH tar -xvf UBC_inputs.tar -C "${WRF_FOLDER}"/WRF_CHEM_Tools/UBC
  echo ""
  echo "Unpacking Aircraft Preprocessor Files."
  echo ""
  env -u LD_LIBRARY_PATH tar -xvf aircraft_preprocessor_files.tar -C "${WRF_FOLDER}"/WRF_CHEM_Tools/Aircraft
  echo ""
  echo "Unpacking Fire INventory from NCAR (FINN)"
  env -u LD_LIBRARY_PATH tar -xzf fire_emis.tgz -C "${WRF_FOLDER}"/WRF_CHEM_Tools/FINN
  env -u LD_LIBRARY_PATH tar -xvf fire_emis_input.tar
  env -u LD_LIBRARY_PATH tar -xzf grass_from_img.nc.tgz -C "${WRF_FOLDER}"/WRF_CHEM_Tools/FINN/grid_finn_fire_emis_v2020/src
  env -u LD_LIBRARY_PATH tar -xzf tempfor_from_img.nc.tgz -C "${WRF_FOLDER}"/WRF_CHEM_Tools/FINN/grid_finn_fire_emis_v2020/src
  env -u LD_LIBRARY_PATH tar -xzf shrub_from_img.nc.tgz -C "${WRF_FOLDER}"/WRF_CHEM_Tools/FINN/grid_finn_fire_emis_v2020/src
  env -u LD_LIBRARY_PATH tar -xzf tropfor_from_img.nc.tgz -C "${WRF_FOLDER}"/WRF_CHEM_Tools/FINN/grid_finn_fire_emis_v2020/src

  mv "${WRF_FOLDER}"/WRF_CHEM_Tools/Downloads/FINNv2.4_MOD_MOZART_2020_c20210617.txt.gz "${WRF_FOLDER}"/WRF_CHEM_Tools/FINN
  mv "${WRF_FOLDER}"/WRF_CHEM_Tools/Downloads/FINNv2.4_MOD_MOZART_2013_c20210617.txt.gz "${WRF_FOLDER}"/WRF_CHEM_Tools/FINN
  mv "${WRF_FOLDER}"/WRF_CHEM_Tools/Downloads/FINNv2.4_MODVRS_MOZART_2019_c20210615.txt.gz "${WRF_FOLDER}"/WRF_CHEM_Tools/FINN

  unzip TrashEmis.zip
  mv "${WRF_FOLDER}"/WRF_CHEM_Tools/Downloads/ALL_Emiss_04282014.nc "${WRF_FOLDER}"/WRF_CHEM_Tools/FINN/grid_finn_fire_emis_v2020/src

  cd "${WRF_FOLDER}"/WRF_CHEM_Tools/FINN

  gunzip FINNv2.4_MOD_MOZART_2020_c20210617.txt.gz
  gunzip FINNv2.4_MOD_MOZART_2013_c20210617.txt.gz
  gunzip FINNv2.4_MODVRS_MOZART_2019_c20210615.txt.gz
  ############################Installation of Mozbc #############################
  # Recalling variables from install script to make sure the path is right

  cd "${WRF_FOLDER}"/WRF_CHEM_Tools/mozbc
  chmod +x make_mozbc
  export DIR="${WRF_FOLDER}"/WRF_CHEM_Tools/Libs
  export FC=gfortran
  export NETCDF_DIR=$DIR/NETCDF
  sed -i 's/"${ar_libs} -lnetcdff"/"-lnetcdff ${ar_libs}"/' make_mozbc
  sed -i '8s/FFLAGS = --g/FFLAGS = --g ${fallow_argument}/' Makefile
  sed -i '10s/FFLAGS = -g/FFLAGS = -g ${fallow_argument}/' Makefile
  ./make_mozbc 2>&1 | tee make.log

  ################## Information on Upper Boundary Conditions ###################

  cd "${WRF_FOLDER}"/WRF_CHEM_Tools/UBC/
  wget -c https://www2.acom.ucar.edu/sites/default/files/documents/8A_2_Barth_WRFWorkshop_11.pdf

  ########################## MEGAN Bio Emission #################################
  # Data for MEGAN Bio Emission located in
  # "${WRF_FOLDER}"/WRF_CHEM_Tools/megan_bio_data

  cd "${WRF_FOLDER}"/WRF_CHEM_Tools/megan_bio_emiss
  chmod +x make_util
  export DIR="${WRF_FOLDER}"/WRF_CHEM_Tools/Libs
  export FC=gfortran
  export NETCDF_DIR=$DIR/NETCDF
  sed -i 's/"${ar_libs} -lnetcdff"/"-lnetcdff ${ar_libs}"/' make_util
  sed -i '8s/FFLAGS = --g/FFLAGS = --g ${fallow_argument}/' Makefile
  sed -i '10s/FFLAGS = -g/FFLAGS = -g ${fallow_argument}/' Makefile
  ./make_util megan_bio_emiss 2>&1 | tee make.bio.log
  ./make_util megan_xform 2>&1 | tee make.xform.log
  ./make_util surfdata_xform 2>&1 | tee make.surfdata.log

  ############################# Anthroprogenic Emissions #########################

  cd "${WRF_FOLDER}"/WRF_CHEM_Tools/ANTHRO_EMIS/ANTHRO/src
  chmod +x make_anthro
  export DIR="${WRF_FOLDER}"/WRF_CHEM_Tools/Libs
  export FC=gfortran
  export NETCDF_DIR=$DIR/NETCDF
  sed -i 's/"${ar_libs} -lnetcdff"/"-lnetcdff ${ar_libs}"/' make_anthro
  sed -i '8s/FFLAGS = --g/FFLAGS = --g ${fallow_argument}/' Makefile
  sed -i '10s/FFLAGS = -g/FFLAGS = -g ${fallow_argument}/' Makefile
  ./make_anthro 2>&1 | tee make.log

  ############################# EDGAR HTAP ######################################
  #  This directory contains EDGAR-HTAP anthropogenic emission files for the
  #  year 2010.  The files are in the MOZCART and MOZART-MOSAIC sub-directories.
  #  The MOZCART files are intended to be used for the WRF MOZCART_KPP chemical
  #  option.  The MOZART-MOSAIC files are intended to be used with the following
  #  WRF chemical options (See read -rme in Folder

  ######################### EPA Anthroprogenic Emissions ########################
  cd "${WRF_FOLDER}"/WRF_CHEM_Tools/EPA_ANTHRO_EMIS/src
  chmod +x make_anthro
  export DIR="${WRF_FOLDER}"/WRF_CHEM_Tools/Libs
  export FC=gfortran
  export NETCDF_DIR=$DIR/NETCDF
  sed -i 's/"${ar_libs} -lnetcdff"/"-lnetcdff ${ar_libs}"/' make_anthro
  sed -i '8s/FFLAGS = --g/FFLAGS = --g ${fallow_argument}/' Makefile
  sed -i '10s/FFLAGS = -g/FFLAGS = -g ${fallow_argument}/' Makefile
  ./make_anthro 2>&1 | tee make.log

  ######################### Weseley EXO Coldens ##################################
  cd "${WRF_FOLDER}"/WRF_CHEM_Tools/wes_coldens
  chmod +x make_util
  export DIR="${WRF_FOLDER}"/WRF_CHEM_Tools/Libs
  export FC=gfortran
  export NETCDF_DIR=$DIR/NETCDF
  sed -i 's/"${ar_libs} -lnetcdff"/"-lnetcdff ${ar_libs}"/' make_util
  sed -i '8s/FFLAGS = --g/FFLAGS = --g ${fallow_argument}/' Makefile
  sed -i '10s/FFLAGS = -g/FFLAGS = -g ${fallow_argument}/' Makefile
  ./make_util wesely 2>&1 | tee make.wesely.log
  ./make_util exo_coldens 2>&1 | tee make.exo.log

  ########################## Aircraft Emissions Preprocessor #####################
  # This is an IDL based preprocessor to create WRF-Chem read -ry aircraft emissions files
  # (wrfchemaircraft_) from a global inventory in netcdf format. Please consult the read -rME file
  # for how to use the preprocessor. The emissions inventory is not included, so the user must
  # provide their own.
  echo " "
  echo "######################################################################"
  echo " Please see script for details about Aircraft Emissions Preprocessor"
  echo "######################################################################"
  echo " "

  ######################## Fire INventory from NCAR (FINN) ###########################
  # Fire INventory from NCAR (FINN): A daily fire emissions product for atmospheric chemistry models
  # https://www2.acom.ucar.edu/modeling/finn-fire-inventory-ncar
  echo " "
  echo "###########################################"
  echo " Please see folder for details about FINN."
  echo "###########################################"
  echo " "

  ######################################### PREP-CHEM-SRC ##############################################
  # PREP-CHEM-SRC is a pollutant emissions numerical too developed at CPTEC/INPE
  # whose function is to create data of atmospheric pollutant emissions from biomass burning,
  # photosynthesis or other forest transformation processes, combustion of oil-based products
  # by vehicles or industry, charcoal production, and many other processes.
  # The system is maintained and developed at CPTEC/INPE by the GMAI group, which not
  # only updates versions of data such as EDGAR, RETRO, MEGAN, etc., but also
  # implements new functionalities such as volcanic emissions which is present now in this
  # version.
  # The purpose of this guide is to present how to install, compile and run the pre-processor.
  # Finally, the steps for utilizing the emissions data in the CCATT-BRAMS, WRF-Chem and
  # FIM-Chem models are presented.
  # We recommend that you read -r the article “PREP-CHEM-SRC – 1.0: a preprocessor of
  # trace gas and aerosol emission fields for regional and global atmospheric chemistry
  # models” (Freitas et al., 2010 - http://www.geosci-model-dev.net/4/419/2011/gmd-4-419-
  # 2011.pdf).
  # Email: mailto:atende.cptec@inpe.br
  # WEB: http://brams.cptec.inpe.br
  # http:// meioambiente.cptec.inpe.br
  # Prep-Chem-Src v1.5.0 (note v1.8.3 is in Beta still)
  #########################################################################################################

  # Downloading PREP-CHEM-SRC-1.5 and untarring files
  mkdir "${WRF_FOLDER}"/WRF_CHEM_Tools/PREP-CHEM-SRC-1.5

  cd "${WRF_FOLDER}"/WRF_CHEM_Tools/Downloads

  wget -c http://ftp.cptec.inpe.br/pesquisa/bramsrd/BRAMS_5.4/PREP-CHEM/PREP-CHEM-SRC-1.5.tar.gz

  env -u LD_LIBRARY_PATH tar -xzf PREP-CHEM-SRC-1.5.tar.gz -C "${WRF_FOLDER}"/WRF_CHEM_Tools/PREP-CHEM-SRC-1.5

  cd "${WRF_FOLDER}"/WRF_CHEM_Tools/PREP-CHEM-SRC-1.5

  # Installation of PREP-CHEM-SRC-1.5

  cd "${WRF_FOLDER}"/WRF_CHEM_Tools/PREP-CHEM-SRC-1.5/bin/build

  sed -i '47s|/scratchin/grupos/catt-brams/shared/libs/gfortran/netcdf-4.1.3|${DIR}/NETCDF|' include.mk.gfortran.wrf          #Changing NETDCF Location
  sed -i '53s|/scratchin/grupos/catt-brams/shared/libs/gfortran/hdf5-1.8.13-serial|${DIR}/grib2|' include.mk.gfortran.wrf     #Changing HDF5 Location
  sed -i '55s|-L/scratchin/grupos/catt-brams/shared/libs/gfortran/zlib-1.2.8/lib|-L${DIR}/grib2/lib|' include.mk.gfortran.wrf #Changing zlib Location
  sed -i '69s|-frecord-marker=4|-frecord-marker=4 ${fallow_argument}|' include.mk.gfortran.wrf                                #Changing adding fallow argument mismatch to fix dummy error

  make OPT=gfortran.wrf CHEM=RADM_WRF_FIM AER=SIMPLE 2>&1 | tee make.log # Compiling and making of PRE-CHEM-SRC-1.5

  # IF statement to check that all files were created.
  cd "${WRF_FOLDER}"/WRF_CHEM_Tools/PREP-CHEM-SRC-1.5/bin
  n=$(ls ./*.exe | wc -l)
  if (($n >= 2)); then
    echo "All expected files created."
    read -r -t 5 -p "Finished installing WRF-CHEM-PREP. I am going to wait for 5 seconds only ..."
  else
    echo "Missing one or more expected files. Exiting the script."
    read -r -p "Please contact script authors for assistance, press 'Enter' to exit script."
    exit
  fi
  echo " "
fi

if [ "$RHL_64bit_GNU" = "2" ]; then

  # Basic Package Management for WRF-CHEM Tools and Processors
  export HOME=$(
    cd ~ \
      && pwd
  )

  #Basic Package Management for Model Evaluation Tools (MET)
  echo $PASSWD | sudo -S yum install epel-release -y
  echo $PASSWD | sudo -S yum install dnf -y
  echo $PASSWD | sudo -S dnf install epel-release -y
  echo $PASSWD | sudo -S dnf -y update
  echo $PASSWD | sudo -S dnf -y upgrade
  echo $PASSWD | sudo -S dnf -y install byacc bzip2 bzip2-devel cairo-devel cmake cpp curl curl-devel flex fontconfig fontconfig-devel gcc gcc-c++ gcc-gfortran git ksh libjpeg libjpeg-devel libstdc++ libstdc++-devel libX11 libX11-devel libXaw libXaw-devel libXext-devel libXmu libXmu-devel libXrender libXrender-devel libXt libXt-devel libxml2 libxml2-devel libgeotiff libgeotiff-devel libtiff libtiff-devel m4 nfs-utils perl 'perl(XML::LibXML)' pkgconfig pixman pixman-devel python3 python3-devel tcsh time unzip wget
  echo $PASSWD | sudo -S dnf install -y java java-devel
  echo $PASSWD | sudo -S dnf install -y java-17-openjdk-devel java-17-openjdk
  echo $PASSWD | sudo -S dnf install -y java-21-openjdk-devel java-21-openjdk
  echo $PASSWD | sudo -S dnf -y install python3-dateutil

  echo $PASSWD | sudo -S dnf -y groupinstall "Development Tools"
  echo $PASSWD | sudo -S dnf -y update
  echo $PASSWD | sudo -S dnf -y upgrade
  echo " "

  #Directory Listings
  export HOME=$(
    cd ~ \
      && pwd
  )
  mkdir $HOME/WRFCHEM
  export WRF_FOLDER=$HOME/WRFCHEM
  cd $HOME/WRFCHEM
  mkdir Downloads
  mkdir Libs
  mkdir Libs/grib2
  mkdir Libs/NETCDF
  mkdir "${WRF_FOLDER}"/WRF_CHEM_Tools
  mkdir "${WRF_FOLDER}"/WRF_CHEM_Tools/Libs
  mkdir "${WRF_FOLDER}"/WRF_CHEM_Tools/Libs/grib2
  mkdir "${WRF_FOLDER}"/WRF_CHEM_Tools/Libs/NETCDF
  mkdir "${WRF_FOLDER}"/WRF_CHEM_Tools/Downloads
  mkdir "${WRF_FOLDER}"/WRF_CHEM_Tools/mozbc
  mkdir "${WRF_FOLDER}"/WRF_CHEM_Tools/megan_bio_emiss
  mkdir "${WRF_FOLDER}"/WRF_CHEM_Tools/megan_bio_data
  mkdir "${WRF_FOLDER}"/WRF_CHEM_Tools/wes_coldens
  mkdir "${WRF_FOLDER}"/WRF_CHEM_Tools/ANTHRO_EMIS
  mkdir "${WRF_FOLDER}"/WRF_CHEM_Tools/EDGAR_HTAP
  mkdir "${WRF_FOLDER}"/WRF_CHEM_Tools/EPA_ANTHRO_EMIS
  mkdir "${WRF_FOLDER}"/WRF_CHEM_Tools/UBC
  mkdir "${WRF_FOLDER}"/WRF_CHEM_Tools/Aircraft
  mkdir "${WRF_FOLDER}"/WRF_CHEM_Tools/FINN
  mkdir "${WRF_FOLDER}"/WRF_CHEM_Tools/Tests
  mkdir "${WRF_FOLDER}"/WRF_CHEM_Tools/Tests/Environment
  mkdir "${WRF_FOLDER}"/WRF_CHEM_Tools/Tests/Compatibility

  ##############################Downloading Libraries############################
  cd "${WRF_FOLDER}"/WRF_CHEM_Tools/Downloads

  wget -c https://github.com/madler/zlib/releases/download/v$Zlib_Version/zlib-$Zlib_Version.tar.gz
  wget -c https://github.com/HDFGroup/hdf5/releases/download/hdf5_$HDF5_Version/hdf5-$HDF5_Version.tar.gz
  wget -c https://github.com/Unidata/netcdf-c/archive/refs/tags/v$Netcdf_C_Version.tar.gz
  wget -c https://github.com/Unidata/netcdf-fortran/archive/refs/tags/v$Netcdf_Fortran_Version.tar.gz
  wget -c https://download.sourceforge.net/libpng/libpng-$Libpng_Version.tar.gz
  wget -c https://www.ece.uvic.ca/~frodo/jasper/software/jasper-$Jasper_Version.zip
  wget -c https://github.com/pmodels/mpich/releases/download/v$Mpich_Version/mpich-$Mpich_Version.tar.gz
  wget -c https://parallel-netcdf.github.io/Release/pnetcdf-$Pnetcdf_Version.tar.gz

  #############################Core Management####################################

  export CPU_CORE=$(nproc) # number of available threads on system
  export CPU_6CORE="6"
  export CPU_QUARTER=$(($CPU_CORE / 4))                          #quarter of availble cores on system
  export CPU_QUARTER_EVEN=$(($CPU_QUARTER - ($CPU_QUARTER % 2))) #Forces CPU cores to even number to avoid partial core export. ie 7 cores would be 3.5 cores.

  if [ $CPU_CORE -le $CPU_6CORE ]; then #If statement for low core systems.  Forces computers to only use 1 core if there are 4 cores or less on the system. then
    export CPU_QUARTER_EVEN="2"
  else
    export CPU_QUARTER_EVEN=$(($CPU_QUARTER - ($CPU_QUARTER % 2)))
  fi

  echo "##########################################"
  echo "Number of Threads being used $CPU_QUARTER_EVEN"
  echo "##########################################"

  echo " "

  #############################Compilers############################
  export DIR="${WRF_FOLDER}"/WRF_CHEM_Tools/Libs
  export CC=gcc
  export CXX=g++
  export FC=gfortran
  export F77=gfortran
  export CFLAGS="-fPIC -fPIE -O3 -Wno-implicit-function-declaration -Wno-incompatible-pointer-types "

  #IF statement for GNU compiler issue
  export GCC_VERSION=$(/usr/bin/gcc -dumpfullversion | awk '{print$1}')
  export GFORTRAN_VERSION=$(/usr/bin/gfortran -dumpfullversion | awk '{print$1}')
  export GPLUSPLUS_VERSION=$(/usr/bin/g++ -dumpfullversion | awk '{print$1}')

  export GCC_VERSION_MAJOR_VERSION=$(echo $GCC_VERSION | awk -F. '{print $1}')
  export GFORTRAN_VERSION_MAJOR_VERSION=$(echo $GFORTRAN_VERSION | awk -F. '{print $1}')
  export GPLUSPLUS_VERSION_MAJOR_VERSION=$(echo $GPLUSPLUS_VERSION | awk -F. '{print $1}')

  export version_10="10"

  if [ $GCC_VERSION_MAJOR_VERSION -ge $version_10 ] || [ $GFORTRAN_VERSION_MAJOR_VERSION -ge $version_10 ] || [ $GPLUSPLUS_VERSION_MAJOR_VERSION -ge $version_10 ]; then
    export fallow_argument=-fallow-argument-mismatch
    export boz_argument=-fallow-invalid-boz
  else
    export fallow_argument=
    export boz_argument=
  fi

  export FFLAGS="$fallow_argument"
  export FCFLAGS="$fallow_argument"

  echo "##########################################"
  echo "FFLAGS = $FFLAGS"
  echo "FCFLAGS = $FCFLAGS"
  echo "CFLAGS = $CFLAGS"
  echo "##########################################"

  #############################zlib############################
  #Uncalling compilers due to comfigure issue with zlib$Zlib_Version
  #With CC & CXX definied ./configure uses different compiler Flags

  cd "${WRF_FOLDER}"/WRF_CHEM_Tools/Downloads
  env -u LD_LIBRARY_PATH tar -xzf zlib-$Zlib_Version.tar.gz
  cd zlib-$Zlib_Version/
  ./configure --prefix=$DIR/grib2 2>&1 | tee configure.log
  make -j $CPU_QUARTER_EVEN 2>&1 | tee make.log
  make -j $CPU_QUARTER_EVEN install 2>&1 | tee make.make.log

  ##############################MPICH############################
  cd "${WRF_FOLDER}"/WRF_CHEM_Tools/Downloads
  env -u LD_LIBRARY_PATH tar -xzf mpich-$Mpich_Version.tar.gz
  cd mpich-$Mpich_Version/
  F90= ./configure --prefix=$DIR/MPICH --with-device=ch3 FFLAGS=$FFLAGS FCFLAGS=$FCFLAGS 2>&1 | tee configure.log
  make -j $CPU_QUARTER_EVEN 2>&1 | tee make.log
  make -j $CPU_QUARTER_EVEN install 2>&1 | tee make.make.log

  export PATH=$DIR/MPICH/bin:$PATH

  export MPIFC=$DIR/MPICH/bin/mpifort
  export MPIF77=$DIR/MPICH/bin/mpifort
  export MPIF90=$DIR/MPICH/bin/mpifort
  export MPICC=$DIR/MPICH/bin/mpicc
  export MPICXX=$DIR/MPICH/bin/mpicxx

  echo " "

  #############################libpng############################
  cd "${WRF_FOLDER}"/WRF_CHEM_Tools/Downloads
  export LDFLAGS=-L$DIR/grib2/lib
  export CPPFLAGS=-I$DIR/grib2/include
  env -u LD_LIBRARY_PATH tar -xzf libpng-$Libpng_Version.tar.gz
  cd libpng-$Libpng_Version/
  CC=$MPICC FC=$MPIFC F77=$MPIF77 F90=$MPIF90 CXX=$MPICXX CFLAGS=$CFLAGS FFLAGS=$FFLAGS FCFLAGS=$FCFLAGS ./configure --prefix=$DIR/grib2 2>&1 | tee configure.log
  make -j $CPU_QUARTER_EVEN 2>&1 | tee make.log
  make -j $CPU_QUARTER_EVEN install 2>&1 | tee make.make.log

  #############################JasPer############################
  cd "${WRF_FOLDER}"/WRF_CHEM_Tools/Downloads
  unzip jasper-$Jasper_Version.zip
  cd jasper-$Jasper_Version/
  CC=$MPICC FC=$MPIFC F77=$MPIF77 F90=$MPIF90 CXX=$MPICXX CFLAGS=$CFLAGS FFLAGS=$FFLAGS FCFLAGS=$FCFLAGS ./configure --prefix=$DIR/grib2 2>&1 | tee configure.log
  make -j $CPU_QUARTER_EVEN 2>&1 | tee make.log
  make -j $CPU_QUARTER_EVEN install 2>&1 | tee make.make.log

  export JASPERLIB=$DIR/grib2/lib
  export JASPERINC=$DIR/grib2/include

  #############################hdf5 library for netcdf4 functionality############################
  cd "${WRF_FOLDER}"/WRF_CHEM_Tools/Downloads
  env -u LD_LIBRARY_PATH tar -xzf hdf5-$HDF5_Version.tar.gz
  cd hdf5-$HDF5_Version
  CC=$MPICC FC=$MPIFC F77=$MPIF77 F90=$MPIF90 CXX=$MPICXX CFLAGS=$CFLAGS FFLAGS=$FFLAGS FCFLAGS=$FCFLAGS ./configure --prefix=$DIR/grib2 --with-zlib=$DIR/grib2 --enable-hl --enable-fortran --enable-parallel 2>&1 | tee configure.log
  make -j $CPU_QUARTER_EVEN 2>&1 | tee make.log
  make -j $CPU_QUARTER_EVEN install 2>&1 | tee make.make.log

  export HDF5=$DIR/grib2
  export PHDF5=$DIR/grib2
  export LD_LIBRARY_PATH=$DIR/grib2/lib:$LD_LIBRARY_PATH

  echo " "

  #############################Install Parallel-netCDF##############################
  #Make file created with half of available cpu cores
  #Hard path for MPI added
  ##################################################################################
  cd "${WRF_FOLDER}"/WRF_CHEM_Tools/Downloads
  env -u LD_LIBRARY_PATH tar -xzf pnetcdf-$Pnetcdf_Version.tar.gz
  cd pnetcdf-$Pnetcdf_Version
  CC=$MPICC FC=$MPIFC F77=$MPIF77 F90=$MPIF90 CXX=$MPICXX CFLAGS=$CFLAGS FFLAGS=$FFLAGS FCFLAGS=$FCFLAGS ./configure --prefix=$DIR/grib2 --enable-shared --enable-static 2>&1 | tee configure.log
  make -j $CPU_QUARTER_EVEN 2>&1 | tee make.log
  make -j $CPU_QUARTER_EVEN install 2>&1 | tee make.make.log

  export PNETCDF=$DIR/grib2

  ##############################Install NETCDF C Library############################
  cd "${WRF_FOLDER}"/WRF_CHEM_Tools/Downloads
  env -u LD_LIBRARY_PATH tar -xzf v$Netcdf_C_Version.tar.gz
  cd netcdf-c-$Netcdf_C_Version/
  export CPPFLAGS=-I$DIR/grib2/include
  export LDFLAGS=-L$DIR/grib2/lib
  export LIBS="-lhdf5_hl -lhdf5 -lz -lcurl -lgfortran -lgcc -lm -ldl -lpnetcdf"
  CC=$MPICC FC=$MPIFC F77=$MPIF77 F90=$MPIF90 CXX=$MPICXX CFLAGS=$CFLAGS FFLAGS=$FFLAGS FCFLAGS=$FCFLAGS ./configure --prefix=$DIR/NETCDF --with-zlib=$DIR/grib2 --disable-dap --enable-netcdf-4 --enable-netcdf4 --enable-shared --enable-static --enable-pnetcdf --enable-cdf5 --enable-parallel-tests 2>&1 | tee configure.log
  make -j $CPU_QUARTER_EVEN 2>&1 | tee make.log
  make -j $CPU_QUARTER_EVEN install 2>&1 | tee make.make.log

  export PATH=$DIR/NETCDF/bin:$PATH
  export NETCDF=$DIR/NETCDF

  ##############################NetCDF fortran library############################
  cd "${WRF_FOLDER}"/WRF_CHEM_Tools/Downloads
  env -u LD_LIBRARY_PATH tar -xzf v$Netcdf_Fortran_Version.tar.gz
  cd netcdf-fortran-$Netcdf_Fortran_Version/
  export LD_LIBRARY_PATH=$DIR/NETCDF/lib:$LD_LIBRARY_PATH
  export CPPFLAGS="-I$DIR/NETCDF/include -I$DIR/grib2/include"
  export LDFLAGS="-L$DIR/NETCDF/lib -L$DIR/grib2/lib"
  export LIBS="-lnetcdf -lpnetcdf -lcurl -lhdf5_hl -lhdf5 -lz -ldl -lgcc -lgfortran"
  CC=$MPICC FC=$MPIFC F77=$MPIF77 F90=$MPIF90 CXX=$MPICXX CFLAGS=$CFLAGS FFLAGS=$FFLAGS FCFLAGS=$FCFLAGS ./configure --prefix=$DIR/NETCDF --enable-netcdf-4 --enable-netcdf4 --enable-shared --enable-static --enable-parallel-tests --enable-hdf5 2>&1 | tee configure.log
  make -j $CPU_QUARTER_EVEN 2>&1 | tee make.log
  make -j $CPU_QUARTER_EVEN install 2>&1 | tee make.make.log

  echo " "
  #################################### System Environment Tests ##############

  cd "${WRF_FOLDER}"/WRF_CHEM_Tools/Downloads
  wget -c https://www2.mmm.ucar.edu/wrf/OnLineTutorial/compile_tutorial/tar_files/Fortran_C_NETCDF_MPI_tests.tar
  wget -c https://www2.mmm.ucar.edu/wrf/OnLineTutorial/compile_tutorial/tar_files/Fortran_C_tests.tar

  env -u LD_LIBRARY_PATH tar -xvf Fortran_C_tests.tar -C "${WRF_FOLDER}"/WRF_CHEM_Tools/Tests/Environment
  env -u LD_LIBRARY_PATH tar -xvf Fortran_C_NETCDF_MPI_tests.tar -C "${WRF_FOLDER}"/WRF_CHEM_Tools/Tests/Compatibility

  export one="1"
  echo " "
  ############## Testing Environment #####

  cd "${WRF_FOLDER}"/WRF_CHEM_Tools/Tests/Environment

  cp ${NETCDF}/include/netcdf.inc .

  echo " "
  echo " "
  echo "Environment Testing "
  echo "Test 1"
  $FC TEST_1_fortran_only_fixed.f
  ./a.out | tee env_test1.txt
  export TEST_PASS=$(grep -w -o -c "SUCCESS" env_test1.txt | awk '{print$1}')
  if [ $TEST_PASS -ge 1 ]; then
    echo "Enviroment Test 1 Passed"
  else
    echo "Environment Compiler Test 1 Failed"
    exit
  fi
  read -r -t 3 -p "I am going to wait for 3 seconds only ..."

  echo " "
  echo "Test 2"
  $FC TEST_2_fortran_only_free.f90
  ./a.out | tee env_test2.txt
  export TEST_PASS=$(grep -w -o -c "SUCCESS" env_test2.txt | awk '{print$1}')
  if [ $TEST_PASS -ge 1 ]; then
    echo "Enviroment Test 2 Passed"
  else
    echo "Environment Compiler Test 2 Failed"
    exit
  fi
  echo " "
  read -r -t 3 -p "I am going to wait for 3 seconds only ..."

  echo " "
  echo "Test 3"
  $CC TEST_3_c_only.c
  ./a.out | tee env_test3.txt
  export TEST_PASS=$(grep -w -o -c "SUCCESS" env_test3.txt | awk '{print$1}')
  if [ $TEST_PASS -ge 1 ]; then
    echo "Enviroment Test 3 Passed"
  else
    echo "Environment Compiler Test 3 Failed"
    exit
  fi
  echo " "
  read -r -t 3 -p "I am going to wait for 3 seconds only ..."

  echo " "
  echo "Test 4"
  $CC -c -m64 TEST_4_fortran+c_c.c
  $FC -c -m64 TEST_4_fortran+c_f.f90
  $FC -m64 TEST_4_fortran+c_f.o TEST_4_fortran+c_c.o
  ./a.out | tee env_test4.txt
  export TEST_PASS=$(grep -w -o -c "SUCCESS" env_test4.txt | awk '{print$1}')
  if [ $TEST_PASS -ge 1 ]; then
    echo "Enviroment Test 4 Passed"
  else
    echo "Environment Compiler Test 4 Failed"
    exit
  fi
  echo " "
  read -r -t 3 -p "I am going to wait for 3 seconds only ..."

  echo " "
  ############## Testing Environment #####

  cd "${WRF_FOLDER}"/WRF_CHEM_Tools/Tests/Compatibility

  cp ${NETCDF}/include/netcdf.inc .

  echo " "
  echo " "
  echo "Library Compatibility Tests "
  echo "Test 1"
  $FC -c 01_fortran+c+netcdf_f.f
  $CC -c 01_fortran+c+netcdf_c.c
  $FC 01_fortran+c+netcdf_f.o 01_fortran+c+netcdf_c.o \
    -L${NETCDF}/lib -lnetcdff -lnetcdf

  ./a.out | tee comp_test1.txt
  export TEST_PASS=$(grep -w -o -c "SUCCESS" comp_test1.txt | awk '{print$1}')
  if [ $TEST_PASS -ge 1 ]; then
    echo "Compatibility Test 1 Passed"
  else
    echo "Compatibility Compiler Test 1 Failed"
    exit
  fi
  echo " "
  read -r -t 3 -p "I am going to wait for 3 seconds only ..."

  echo " "

  echo "Test 2"
  $MPIFC -c 02_fortran+c+netcdf+mpi_f.f
  $MPICC -c 02_fortran+c+netcdf+mpi_c.c
  $MPIFC 02_fortran+c+netcdf+mpi_f.o \
    02_fortran+c+netcdf+mpi_c.o \
    -L${NETCDF}/lib -lnetcdff -lnetcdf

  $DIR/MPICH/bin/mpirun ./a.out | tee comp_test2.txt
  export TEST_PASS=$(grep -w -o -c "SUCCESS" comp_test2.txt | awk '{print$1}')
  if [ $TEST_PASS -ge 1 ]; then
    echo "Compatibility Test 2 Passed"
  else
    echo "Compatibility Compiler Test 2 Failed"
    exit
  fi
  echo " "
  read -r -t 3 -p "I am going to wait for 3 seconds only ..."
  echo " "

  echo " All tests completed and passed"
  echo " "

  # Downloading WRF-CHEM Tools and untarring files
  cd "${WRF_FOLDER}"/WRF_CHEM_Tools/Downloads

  wget -c https://www.acom.ucar.edu/wrf-chem/mozbc.tar
  wget -c https://www.acom.ucar.edu/wrf-chem/UBC_inputs.tar
  wget -c https://www.acom.ucar.edu//wrf-chem/megan_bio_emiss.tar
  wget -c https://www.acom.ucar.edu/wrf-chem/megan.data.tar.gz
  wget -c https://www.acom.ucar.edu/wrf-chem/wes-coldens.tar
  wget -c https://www.acom.ucar.edu/wrf-chem/ANTHRO.tar
  wget -c https://www.acom.ucar.edu/webt/wrf-chem/processors/EDGAR-HTAP.tgz
  wget -c https://www.acom.ucar.edu/wrf-chem/EPA_ANTHRO_EMIS.tgz
  wget -c https://www2.acom.ucar.edu/sites/default/files/documents/aircraft_preprocessor_files.tar
  # Downloading FINN
  wget -c https://www.acom.ucar.edu/Data/fire/data/finn2/FINNv2.4_MOD_MOZART_2020_c20210617.txt.gz
  wget -c https://www.acom.ucar.edu/Data/fire/data/finn2/FINNv2.4_MOD_MOZART_2013_c20210617.txt.gz
  wget -c https://www.acom.ucar.edu/Data/fire/data/finn2/FINNv2.4_MODVRS_MOZART_2019_c20210615.txt.gz
  wget -c https://www.acom.ucar.edu/Data/fire/data/fire_emis.tgz
  wget -c https://www.acom.ucar.edu/Data/fire/data/fire_emis_input.tar
  wget -c https://www.acom.ucar.edu/Data/fire/data/TrashEmis.zip

  echo ""
  echo "Unpacking Mozbc."
  env -u LD_LIBRARY_PATH tar -xvf mozbc.tar -C "${WRF_FOLDER}"/WRF_CHEM_Tools/mozbc
  echo ""
  echo "Unpacking MEGAN Bio Emission."
  env -u LD_LIBRARY_PATH tar -xvf megan_bio_emiss.tar -C "${WRF_FOLDER}"/WRF_CHEM_Tools/megan_bio_emiss
  echo ""
  echo "Unpacking MEGAN Bio Emission Data."
  env -u LD_LIBRARY_PATH tar -xzf megan.data.tar.gz -C "${WRF_FOLDER}"/WRF_CHEM_Tools/megan_bio_data
  echo ""
  echo "Unpacking Wes Coldens"
  env -u LD_LIBRARY_PATH tar -xvf wes-coldens.tar -C "${WRF_FOLDER}"/WRF_CHEM_Tools/wes_coldens
  echo ""
  echo "Unpacking Unpacking ANTHRO Emission."
  env -u LD_LIBRARY_PATH tar -xvf ANTHRO.tar -C "${WRF_FOLDER}"/WRF_CHEM_Tools/ANTHRO_EMIS
  echo ""
  echo "Unpacking EDGAR-HTAP."
  env -u LD_LIBRARY_PATH tar -xzf EDGAR-HTAP.tgz -C "${WRF_FOLDER}"/WRF_CHEM_Tools/EDGAR_HTAP
  echo ""
  echo "Unpacking EPA ANTHRO Emission."
  env -u LD_LIBRARY_PATH tar -xzf EPA_ANTHRO_EMIS.tgz -C "${WRF_FOLDER}"/WRF_CHEM_Tools/EPA_ANTHRO_EMIS
  echo ""
  echo "Unpacking Upper Boundary Conditions."
  env -u LD_LIBRARY_PATH tar -xvf UBC_inputs.tar -C "${WRF_FOLDER}"/WRF_CHEM_Tools/UBC
  echo ""
  echo "Unpacking Aircraft Preprocessor Files."
  echo ""
  env -u LD_LIBRARY_PATH tar -xvf aircraft_preprocessor_files.tar -C "${WRF_FOLDER}"/WRF_CHEM_Tools/Aircraft
  echo ""
  echo "Unpacking Fire INventory from NCAR (FINN)"
  env -u LD_LIBRARY_PATH tar -xzf fire_emis.tgz -C "${WRF_FOLDER}"/WRF_CHEM_Tools/FINN
  env -u LD_LIBRARY_PATH tar -xvf fire_emis_input.tar
  env -u LD_LIBRARY_PATH tar -xzf grass_from_img.nc.tgz -C "${WRF_FOLDER}"/WRF_CHEM_Tools/FINN/grid_finn_fire_emis_v2020/src
  env -u LD_LIBRARY_PATH tar -xzf tempfor_from_img.nc.tgz -C "${WRF_FOLDER}"/WRF_CHEM_Tools/FINN/grid_finn_fire_emis_v2020/src
  env -u LD_LIBRARY_PATH tar -xzf shrub_from_img.nc.tgz -C "${WRF_FOLDER}"/WRF_CHEM_Tools/FINN/grid_finn_fire_emis_v2020/src
  env -u LD_LIBRARY_PATH tar -xzf tropfor_from_img.nc.tgz -C "${WRF_FOLDER}"/WRF_CHEM_Tools/FINN/grid_finn_fire_emis_v2020/src

  mv "${WRF_FOLDER}"/WRF_CHEM_Tools/Downloads/FINNv2.4_MOD_MOZART_2020_c20210617.txt.gz "${WRF_FOLDER}"/WRF_CHEM_Tools/FINN
  mv "${WRF_FOLDER}"/WRF_CHEM_Tools/Downloads/FINNv2.4_MOD_MOZART_2013_c20210617.txt.gz "${WRF_FOLDER}"/WRF_CHEM_Tools/FINN
  mv "${WRF_FOLDER}"/WRF_CHEM_Tools/Downloads/FINNv2.4_MODVRS_MOZART_2019_c20210615.txt.gz "${WRF_FOLDER}"/WRF_CHEM_Tools/FINN

  unzip TrashEmis.zip
  mv "${WRF_FOLDER}"/WRF_CHEM_Tools/Downloads/ALL_Emiss_04282014.nc "${WRF_FOLDER}"/WRF_CHEM_Tools/FINN/grid_finn_fire_emis_v2020/src

  cd "${WRF_FOLDER}"/WRF_CHEM_Tools/FINN

  gunzip FINNv2.4_MOD_MOZART_2020_c20210617.txt.gz
  gunzip FINNv2.4_MOD_MOZART_2013_c20210617.txt.gz
  gunzip FINNv2.4_MODVRS_MOZART_2019_c20210615.txt.gz
  ############################Installation of Mozbc #############################
  # Recalling variables from install script to make sure the path is right

  cd "${WRF_FOLDER}"/WRF_CHEM_Tools/mozbc
  chmod +x make_mozbc
  export DIR="${WRF_FOLDER}"/WRF_CHEM_Tools/Libs
  export FC=gfortran
  export NETCDF_DIR=$DIR/NETCDF
  sed -i 's/"${ar_libs} -lnetcdff"/"-lnetcdff ${ar_libs}"/' make_mozbc
  sed -i '8s/FFLAGS = --g/FFLAGS = --g ${fallow_argument}/' Makefile
  sed -i '10s/FFLAGS = -g/FFLAGS = -g ${fallow_argument}/' Makefile
  ./make_mozbc 2>&1 | tee make.log

  ################## Information on Upper Boundary Conditions ###################

  cd "${WRF_FOLDER}"/WRF_CHEM_Tools/UBC/
  wget -c https://www2.acom.ucar.edu/sites/default/files/documents/8A_2_Barth_WRFWorkshop_11.pdf

  ########################## MEGAN Bio Emission #################################
  # Data for MEGAN Bio Emission located in
  # "${WRF_FOLDER}"/WRF_CHEM_Tools/megan_bio_data

  cd "${WRF_FOLDER}"/WRF_CHEM_Tools/megan_bio_emiss
  chmod +x make_util
  export DIR="${WRF_FOLDER}"/WRF_CHEM_Tools/Libs
  export FC=gfortran
  export NETCDF_DIR=$DIR/NETCDF
  sed -i 's/"${ar_libs} -lnetcdff"/"-lnetcdff ${ar_libs}"/' make_util
  sed -i '8s/FFLAGS = --g/FFLAGS = --g ${fallow_argument}/' Makefile
  sed -i '10s/FFLAGS = -g/FFLAGS = -g ${fallow_argument}/' Makefile
  ./make_util megan_bio_emiss 2>&1 | tee make.bio.log
  ./make_util megan_xform 2>&1 | tee make.xform.log
  ./make_util surfdata_xform 2>&1 | tee make.surfdata.log

  ############################# Anthroprogenic Emissions #########################

  cd "${WRF_FOLDER}"/WRF_CHEM_Tools/ANTHRO_EMIS/ANTHRO/src
  chmod +x make_anthro
  export DIR="${WRF_FOLDER}"/WRF_CHEM_Tools/Libs
  export FC=gfortran
  export NETCDF_DIR=$DIR/NETCDF
  sed -i 's/"${ar_libs} -lnetcdff"/"-lnetcdff ${ar_libs}"/' make_anthro
  sed -i '8s/FFLAGS = --g/FFLAGS = --g ${fallow_argument}/' Makefile
  sed -i '10s/FFLAGS = -g/FFLAGS = -g ${fallow_argument}/' Makefile
  ./make_anthro 2>&1 | tee make.log

  ############################# EDGAR HTAP ######################################
  #  This directory contains EDGAR-HTAP anthropogenic emission files for the
  #  year 2010.  The files are in the MOZCART and MOZART-MOSAIC sub-directories.
  #  The MOZCART files are intended to be used for the WRF MOZCART_KPP chemical
  #  option.  The MOZART-MOSAIC files are intended to be used with the following
  #  WRF chemical options (See read -rme in Folder

  ######################### EPA Anthroprogenic Emissions ########################
  cd "${WRF_FOLDER}"/WRF_CHEM_Tools/EPA_ANTHRO_EMIS/src
  chmod +x make_anthro
  export DIR="${WRF_FOLDER}"/WRF_CHEM_Tools/Libs
  export FC=gfortran
  export NETCDF_DIR=$DIR/NETCDF
  sed -i 's/"${ar_libs} -lnetcdff"/"-lnetcdff ${ar_libs}"/' make_anthro
  sed -i '8s/FFLAGS = --g/FFLAGS = --g ${fallow_argument}/' Makefile
  sed -i '10s/FFLAGS = -g/FFLAGS = -g ${fallow_argument}/' Makefile
  ./make_anthro 2>&1 | tee make.log

  ######################### Weseley EXO Coldens ##################################
  cd "${WRF_FOLDER}"/WRF_CHEM_Tools/wes_coldens
  chmod +x make_util
  export DIR="${WRF_FOLDER}"/WRF_CHEM_Tools/Libs
  export FC=gfortran
  export NETCDF_DIR=$DIR/NETCDF
  sed -i 's/"${ar_libs} -lnetcdff"/"-lnetcdff ${ar_libs}"/' make_util
  sed -i '8s/FFLAGS = --g/FFLAGS = --g ${fallow_argument}/' Makefile
  sed -i '10s/FFLAGS = -g/FFLAGS = -g ${fallow_argument}/' Makefile
  ./make_util wesely 2>&1 | tee make.wesely.log
  ./make_util exo_coldens 2>&1 | tee make.exo.log

  ########################## Aircraft Emissions Preprocessor #####################
  # This is an IDL based preprocessor to create WRF-Chem read -ry aircraft emissions files
  # (wrfchemaircraft_) from a global inventory in netcdf format. Please consult the read -rME file
  # for how to use the preprocessor. The emissions inventory is not included, so the user must
  # provide their own.
  echo " "
  echo "######################################################################"
  echo " Please see script for details about Aircraft Emissions Preprocessor"
  echo "######################################################################"
  echo " "

  ######################## Fire INventory from NCAR (FINN) ###########################
  # Fire INventory from NCAR (FINN): A daily fire emissions product for atmospheric chemistry models
  # https://www2.acom.ucar.edu/modeling/finn-fire-inventory-ncar
  echo " "
  echo "###########################################"
  echo " Please see folder for details about FINN."
  echo "###########################################"
  echo " "

  ######################################### PREP-CHEM-SRC ##############################################
  # PREP-CHEM-SRC is a pollutant emissions numerical too developed at CPTEC/INPE
  # whose function is to create data of atmospheric pollutant emissions from biomass burning,
  # photosynthesis or other forest transformation processes, combustion of oil-based products
  # by vehicles or industry, charcoal production, and many other processes.
  # The system is maintained and developed at CPTEC/INPE by the GMAI group, which not
  # only updates versions of data such as EDGAR, RETRO, MEGAN, etc., but also
  # implements new functionalities such as volcanic emissions which is present now in this
  # version.
  # The purpose of this guide is to present how to install, compile and run the pre-processor.
  # Finally, the steps for utilizing the emissions data in the CCATT-BRAMS, WRF-Chem and
  # FIM-Chem models are presented.
  # We recommend that you read -r the article “PREP-CHEM-SRC – 1.0: a preprocessor of
  # trace gas and aerosol emission fields for regional and global atmospheric chemistry
  # models” (Freitas et al., 2010 - http://www.geosci-model-dev.net/4/419/2011/gmd-4-419-
  # 2011.pdf).
  # Email: mailto:atende.cptec@inpe.br
  # WEB: http://brams.cptec.inpe.br
  # http:// meioambiente.cptec.inpe.br
  # Prep-Chem-Src v1.5.0 (note v1.8.3 is in Beta still)
  #########################################################################################################

  # Downloading PREP-CHEM-SRC-1.5 and untarring files
  mkdir "${WRF_FOLDER}"/WRF_CHEM_Tools/PREP-CHEM-SRC-1.5

  cd "${WRF_FOLDER}"/WRF_CHEM_Tools/Downloads

  wget -c http://ftp.cptec.inpe.br/pesquisa/bramsrd/BRAMS_5.4/PREP-CHEM/PREP-CHEM-SRC-1.5.tar.gz

  env -u LD_LIBRARY_PATH tar -xzf PREP-CHEM-SRC-1.5.tar.gz -C "${WRF_FOLDER}"/WRF_CHEM_Tools/PREP-CHEM-SRC-1.5

  cd "${WRF_FOLDER}"/WRF_CHEM_Tools/PREP-CHEM-SRC-1.5

  # Installation of PREP-CHEM-SRC-1.5

  cd "${WRF_FOLDER}"/WRF_CHEM_Tools/PREP-CHEM-SRC-1.5/bin/build

  sed -i '47s|/scratchin/grupos/catt-brams/shared/libs/gfortran/netcdf-4.1.3|${DIR}/NETCDF|' include.mk.gfortran.wrf          #Changing NETDCF Location
  sed -i '53s|/scratchin/grupos/catt-brams/shared/libs/gfortran/hdf5-1.8.13-serial|${DIR}/grib2|' include.mk.gfortran.wrf     #Changing HDF5 Location
  sed -i '55s|-L/scratchin/grupos/catt-brams/shared/libs/gfortran/zlib-1.2.8/lib|-L${DIR}/grib2/lib|' include.mk.gfortran.wrf #Changing zlib Location
  sed -i '69s|-frecord-marker=4|-frecord-marker=4 ${fallow_argument}|' include.mk.gfortran.wrf                                #Changing adding fallow argument mismatch to fix dummy error

  make OPT=gfortran.wrf CHEM=RADM_WRF_FIM AER=SIMPLE 2>&1 | tee make.log # Compiling and making of PRE-CHEM-SRC-1.5

  # IF statement to check that all files were created.
  cd "${WRF_FOLDER}"/WRF_CHEM_Tools/PREP-CHEM-SRC-1.5/bin
  n=$(ls ./*.exe | wc -l)
  if (($n >= 2)); then
    echo "All expected files created."
    read -r -t 5 -p "Finished installing WRF-CHEM-PREP. I am going to wait for 5 seconds only ..."
  else
    echo "Missing one or more expected files. Exiting the script."
    read -r -p "Please contact script authors for assistance, press 'Enter' to exit script."
    exit
  fi
  echo " "
fi

if [ "$RHL_64bit_Intel" = "1" ]; then
  #############################basic package managment############################
  echo $PASSWD | sudo -S yum install epel-release -y
  echo $PASSWD | sudo -S yum install dnf -y
  echo $PASSWD | sudo -S dnf install epel-release -y
  echo $PASSWD | sudo -S dnf install dnf -y
  echo $PASSWD | sudo -S dnf -y update
  echo $PASSWD | sudo -S dnf -y upgrade
  echo $PASSWD | sudo -S dnf -y install autoconf automake bzip2 bzip2-devel byacc cairo-devel cmake cpp curl curl-devel flex fontconfig-devel gcc-c++ gcc-gfortran git java-11-openjdk java-11-openjdk-devel ksh libX11-devel libXaw-devel libXext-devel libXrender-devel libstdc++-devel libxml2 libxml2-devel m4 nfs-utils perl "perl(XML::LibXML)" pkgconfig pixman-devel python3 python3-devel tcsh time unzip wget
  echo $PASSWD | sudo -S dnf -y groupinstall "Development Tools"

  # download the key to system keyring; this and the following echo command are
  # needed in order to install the Intel compilers

  echo $PASSWD | sudo bash -c 'printf "[oneAPI]\nname=Intel® oneAPI repository\nbaseurl=https://yum.repos.intel.com/oneapi\nenabled=1\ngpgcheck=1\nrepo_gpgcheck=1\ngpgkey=https://yum.repos.intel.com/intel-gpg-keys/GPG-PUB-KEY-INTEL-SW-PRODUCTS.PUB\n" > /etc/yum.repos.d/oneAPI.repo'

  echo $PASSWD | sudo -S mv /tmp/oneAPI.repo /etc/yum.repos.d

  echo $PASSWD | sudo -S dnf install intel-cpp-essentials -y

  # install the Intel compilers
  echo $PASSWD | sudo -S dnf upgrade intel-cpp-essentials -y
  echo $PASSWD | sudo -S dnf install intel-oneapi-base-toolkit -y
  echo $PASSWD | sudo -S dnf install intel-oneapi-hpc-toolkit -y
  echo $PASSWD | sudo -S dnf install intel-oneapi-python -y

  echo $PASSWD | sudo -S dnf update
  echo $PASSWD | sudo -S dnf -y install cmake pkgconfig
  echo $PASSWD | sudo -S dnf groupinstall "Development Tools" -y

  echo $PASSWD | sudo -S dnf -y update
  echo $PASSWD | sudo -S dnf -y upgrade

  # add the Intel compiler file paths to various environment variables
  source /opt/intel/oneapi/setvars.sh --force

  # some of the libraries we install below need one or more of these variables

  export CC=icx
  export CXX=icpx
  export FC=ifx
  export F77=ifx
  export F90=ifx
  export MPIFC=mpiifx
  export MPIF77=mpiifx
  export MPIF90=mpiifx
  export MPICC=mpiicx
  export MPICXX=mpiicpx
  export CFLAGS="-fPIC -fPIE -O3 -Wno-implicit-function-declaration -Wno-incompatible-pointer-types "
  export FFLAGS="-m64"
  export FCFLAGS="-m64"

  #Directory Listings
  export HOME=$(
    cd ~ \
      && pwd
  )
  mkdir $HOME/WRFCHEM_Intel
  export WRF_FOLDER=$HOME/WRFCHEM_Intel
  cd $HOME/WRFCHEM_Intel
  mkdir Downloads
  mkdir Libs
  mkdir Libs/grib2
  mkdir Libs/NETCDF
  mkdir "${WRF_FOLDER}"/WRF_CHEM_Tools
  mkdir "${WRF_FOLDER}"/WRF_CHEM_Tools/Libs
  mkdir "${WRF_FOLDER}"/WRF_CHEM_Tools/Libs/grib2
  mkdir "${WRF_FOLDER}"/WRF_CHEM_Tools/Libs/NETCDF
  mkdir "${WRF_FOLDER}"/WRF_CHEM_Tools/Downloads
  mkdir "${WRF_FOLDER}"/WRF_CHEM_Tools/mozbc
  mkdir "${WRF_FOLDER}"/WRF_CHEM_Tools/megan_bio_emiss
  mkdir "${WRF_FOLDER}"/WRF_CHEM_Tools/megan_bio_data
  mkdir "${WRF_FOLDER}"/WRF_CHEM_Tools/wes_coldens
  mkdir "${WRF_FOLDER}"/WRF_CHEM_Tools/ANTHRO_EMIS
  mkdir "${WRF_FOLDER}"/WRF_CHEM_Tools/EDGAR_HTAP
  mkdir "${WRF_FOLDER}"/WRF_CHEM_Tools/EPA_ANTHRO_EMIS
  mkdir "${WRF_FOLDER}"/WRF_CHEM_Tools/UBC
  mkdir "${WRF_FOLDER}"/WRF_CHEM_Tools/Aircraft
  mkdir "${WRF_FOLDER}"/WRF_CHEM_Tools/FINN
  mkdir "${WRF_FOLDER}"/WRF_CHEM_Tools/Tests
  mkdir "${WRF_FOLDER}"/WRF_CHEM_Tools/Tests/Environment
  mkdir "${WRF_FOLDER}"/WRF_CHEM_Tools/Tests/Compatibility

  export DIR="${WRF_FOLDER}"/WRF_CHEM_Tools/Libs

  ##############################Downloading Libraries############################
  cd "${WRF_FOLDER}"/WRF_CHEM_Tools/Downloads

  wget -c https://github.com/madler/zlib/releases/download/v$Zlib_Version/zlib-$Zlib_Version.tar.gz
  wget -c https://github.com/HDFGroup/hdf5/releases/download/hdf5_$HDF5_Version/hdf5-$HDF5_Version.tar.gz
  wget -c https://github.com/Unidata/netcdf-c/archive/refs/tags/v$Netcdf_C_Version.tar.gz
  wget -c https://github.com/Unidata/netcdf-fortran/archive/refs/tags/v$Netcdf_Fortran_Version.tar.gz
  wget -c https://download.sourceforge.net/libpng/libpng-$Libpng_Version.tar.gz
  wget -c https://www.ece.uvic.ca/~frodo/jasper/software/jasper-$Jasper_Version.zip
  wget -c https://github.com/pmodels/mpich/releases/download/v$Mpich_Version/mpich-$Mpich_Version.tar.gz
  wget -c https://parallel-netcdf.github.io/Release/pnetcdf-$Pnetcdf_Version.tar.gz

  ############################# CPU Core Management ####################################

  export CPU_CORE=$(nproc) # number of available threads on system
  export CPU_6CORE="6"
  export CPU_QUARTER=$(($CPU_CORE / 4)) # quarter of availble cores on system
  # Forces CPU cores to even number to avoid partial core export. ie 7 cores would be 3.5 cores.
  export CPU_QUARTER_EVEN=$(($CPU_QUARTER - ($CPU_QUARTER % 2)))

  # If statement for low core systems.  Forces computers to only use 1 core if there are 4 cores or less on the system.
  if [ $CPU_CORE -le $CPU_6CORE ]; then
    export CPU_QUARTER_EVEN="2"
  else
    export CPU_QUARTER_EVEN=$(($CPU_QUARTER - ($CPU_QUARTER % 2)))
  fi

  echo "##########################################"
  echo "Number of Threads being used $CPU_QUARTER_EVEN"
  echo "##########################################"

  #############################Compilers############################

  #############################zlib############################
  #Uncalling compilers due to comfigure issue with zlib$Zlib_Version
  #With CC & CXX definied ./configure uses different compiler Flags

  cd "${WRF_FOLDER}"/WRF_CHEM_Tools/Downloads
  env -u LD_LIBRARY_PATH tar -xzf zlib-$Zlib_Version.tar.gz
  cd zlib-$Zlib_Version/
  ./configure --prefix=$DIR/grib2 2>&1 | tee configure.log
  make -j $CPU_QUARTER_EVEN 2>&1 | tee make.log
  make -j $CPU_QUARTER_EVEN install 2>&1 | tee make.install.log

  #############################libpng############################
  cd "${WRF_FOLDER}"/WRF_CHEM_Tools/Downloads
  export LDFLAGS=-L$DIR/grib2/lib
  export CPPFLAGS=-I$DIR/grib2/include
  env -u LD_LIBRARY_PATH tar -xzf libpng-$Libpng_Version.tar.gz
  cd libpng-$Libpng_Version/
  CC=$MPICC FC=$MPIFC F77=$MPIF77 F90=$MPIF90 CXX=$MPICXX CFLAGS=$CFLAGS FFLAGS=$FFLAGS FCFLAGS=$FCFLAGS ./configure --prefix=$DIR/grib2 2>&1 | tee configure.log
  make -j $CPU_QUARTER_EVEN 2>&1 | tee make.log
  make -j $CPU_QUARTER_EVEN install 2>&1 | tee make.install.log

  #############################JasPer############################
  cd "${WRF_FOLDER}"/WRF_CHEM_Tools/Downloads
  unzip jasper-$Jasper_Version.zip
  cd jasper-$Jasper_Version/
  CC=$MPICC FC=$MPIFC F77=$MPIF77 F90=$MPIF90 CXX=$MPICXX CFLAGS=$CFLAGS FFLAGS=$FFLAGS FCFLAGS=$FCFLAGS ./configure --prefix=$DIR/grib2 2>&1 | tee configure.log
  make -j $CPU_QUARTER_EVEN 2>&1 | tee make.log
  make -j $CPU_QUARTER_EVEN install 2>&1 | tee make.install.log

  export JASPERLIB=$DIR/grib2/lib
  export JASPERINC=$DIR/grib2/include

  #############################hdf5 library for netcdf4 functionality############################
  cd "${WRF_FOLDER}"/WRF_CHEM_Tools/Downloads
  env -u LD_LIBRARY_PATH tar -xzf hdf5-$HDF5_Version.tar.gz
  cd hdf5-$HDF5_Version
  CC=$MPICC FC=$MPIFC F77=$MPIF77 F90=$MPIF90 CXX=$MPICXX CFLAGS=$CFLAGS FFLAGS=$FFLAGS FCFLAGS=$FCFLAGS ./configure --prefix=$DIR/grib2 --with-zlib=$DIR/grib2 --enable-hl --enable-fortran --enable-parallel 2>&1 | tee configure.log
  make -j $CPU_QUARTER_EVEN 2>&1 | tee make.log
  make -j $CPU_QUARTER_EVEN install 2>&1 | tee make.install.log

  export HDF5=$DIR/grib2
  export PHDF5=$DIR/grib2
  export LD_LIBRARY_PATH=$DIR/grib2/lib:$LD_LIBRARY_PATH

  echo " "

  #############################Install Parallel-netCDF##############################
  #Make file created with half of available cpu cores
  #Hard path for MPI added
  ##################################################################################
  cd "${WRF_FOLDER}"/WRF_CHEM_Tools/Downloads
  env -u LD_LIBRARY_PATH tar -xzf pnetcdf-$Pnetcdf_Version.tar.gz
  cd pnetcdf-$Pnetcdf_Version
  CC=$MPICC FC=$MPIFC F77=$MPIF77 F90=$MPIF90 CXX=$MPICXX CFLAGS=$CFLAGS FFLAGS=$FFLAGS FCFLAGS=$FCFLAGS ./configure --prefix=$DIR/grib2 --enable-shared --enable-static 2>&1 | tee configure.log
  make -j $CPU_QUARTER_EVEN 2>&1 | tee make.log
  make -j $CPU_QUARTER_EVEN install 2>&1 | tee make.install.log

  export PNETCDF=$DIR/grib2

  ##############################Install NETCDF C Library############################
  cd "${WRF_FOLDER}"/WRF_CHEM_Tools/Downloads
  env -u LD_LIBRARY_PATH tar -xzf v$Netcdf_C_Version.tar.gz
  cd netcdf-c-$Netcdf_C_Version/
  export CPPFLAGS=-I$DIR/grib2/include
  export LDFLAGS=-L$DIR/grib2/lib
  export LIBS="-lhdf5_hl -lhdf5 -lz -lcurl -lgcc -lm -ldl -lpnetcdf"
  CC=$MPICC FC=$MPIFC F77=$MPIF77 F90=$MPIF90 CXX=$MPICXX CFLAGS=$CFLAGS FFLAGS=$FFLAGS FCFLAGS=$FCFLAGS ./configure --prefix=$DIR/NETCDF --with-zlib=$DIR/grib2 --disable-dap --enable-netcdf-4 --enable-netcdf4 --enable-shared --enable-static --enable-pnetcdf --enable-cdf5 --enable-parallel-tests 2>&1 | tee configure.log
  make -j $CPU_QUARTER_EVEN 2>&1 | tee make.log
  make -j $CPU_QUARTER_EVEN install 2>&1 | tee make.install.log

  export PATH=$DIR/NETCDF/bin:$PATH
  export NETCDF=$DIR/NETCDF

  ##############################NetCDF fortran library############################
  cd "${WRF_FOLDER}"/WRF_CHEM_Tools/Downloads
  env -u LD_LIBRARY_PATH tar -xzf v$Netcdf_Fortran_Version.tar.gz
  cd netcdf-fortran-$Netcdf_Fortran_Version/
  export LD_LIBRARY_PATH=$DIR/NETCDF/lib:$LD_LIBRARY_PATH
  export CPPFLAGS="-I$DIR/NETCDF/include -I$DIR/grib2/include"
  export LDFLAGS="-L$DIR/NETCDF/lib -L$DIR/grib2/lib"
  export LIBS="-lnetcdf -lpnetcdf -lcurl -lhdf5_hl -lhdf5 -lz -lm -ldl -lgcc"
  CC=$MPICC FC=$MPIFC F77=$MPIF77 F90=$MPIF90 CXX=$MPICXX CFLAGS=$CFLAGS FFLAGS=$FFLAGS FCFLAGS=$FCFLAGS ./configure --prefix=$DIR/NETCDF --enable-netcdf-4 --enable-netcdf4 --enable-shared --enable-static --enable-parallel-tests --enable-hdf5 2>&1 | tee configure.log
  make -j $CPU_QUARTER_EVEN 2>&1 | tee make.log
  make -j $CPU_QUARTER_EVEN install 2>&1 | tee make.install.log

  echo " "
  #################################### System Environment Tests ##############

  cd "${WRF_FOLDER}"/WRF_CHEM_Tools/Downloads
  wget -c https://www2.mmm.ucar.edu/wrf/OnLineTutorial/compile_tutorial/tar_files/Fortran_C_NETCDF_MPI_tests.tar
  wget -c https://www2.mmm.ucar.edu/wrf/OnLineTutorial/compile_tutorial/tar_files/Fortran_C_tests.tar

  env -u LD_LIBRARY_PATH tar -xvf Fortran_C_tests.tar -C "${WRF_FOLDER}"/WRF_CHEM_Tools/Tests/Environment
  env -u LD_LIBRARY_PATH tar -xvf Fortran_C_NETCDF_MPI_tests.tar -C "${WRF_FOLDER}"/WRF_CHEM_Tools/Tests/Compatibility

  export one="1"
  echo " "
  ############## Testing Environment #####

  cd "${WRF_FOLDER}"/WRF_CHEM_Tools/Tests/Environment

  cp ${NETCDF}/include/netcdf.inc .

  echo " "
  echo " "
  echo "Environment Testing "
  echo "Test 1"
  $FC TEST_1_fortran_only_fixed.f
  ./a.out | tee env_test1.txt
  export TEST_PASS=$(grep -w -o -c "SUCCESS" env_test1.txt | awk '{print$1}')
  if [ $TEST_PASS -ge 1 ]; then
    echo "Enviroment Test 1 Passed"
  else
    echo "Environment Compiler Test 1 Failed"
    exit
  fi
  read -r -t 3 -p "I am going to wait for 3 seconds only ..."

  echo " "
  echo "Test 2"
  $FC TEST_2_fortran_only_free.f90
  ./a.out | tee env_test2.txt
  export TEST_PASS=$(grep -w -o -c "SUCCESS" env_test2.txt | awk '{print$1}')
  if [ $TEST_PASS -ge 1 ]; then
    echo "Enviroment Test 2 Passed"
  else
    echo "Environment Compiler Test 2 Failed"
    exit
  fi
  echo " "
  read -r -t 3 -p "I am going to wait for 3 seconds only ..."

  echo " "
  echo "Test 3"
  $CC TEST_3_c_only.c
  ./a.out | tee env_test3.txt
  export TEST_PASS=$(grep -w -o -c "SUCCESS" env_test3.txt | awk '{print$1}')
  if [ $TEST_PASS -ge 1 ]; then
    echo "Enviroment Test 3 Passed"
  else
    echo "Environment Compiler Test 3 Failed"
    exit
  fi
  echo " "
  read -r -t 3 -p "I am going to wait for 3 seconds only ..."

  echo " "
  echo "Test 4"
  $CC -c -m64 TEST_4_fortran+c_c.c
  $FC -c -m64 TEST_4_fortran+c_f.f90
  $FC -m64 TEST_4_fortran+c_f.o TEST_4_fortran+c_c.o
  ./a.out | tee env_test4.txt
  export TEST_PASS=$(grep -w -o -c "SUCCESS" env_test4.txt | awk '{print$1}')
  if [ $TEST_PASS -ge 1 ]; then
    echo "Enviroment Test 4 Passed"
  else
    echo "Environment Compiler Test 4 Failed"
    exit
  fi
  echo " "
  read -r -t 3 -p "I am going to wait for 3 seconds only ..."

  echo " "
  ############## Testing Environment #####

  cd "${WRF_FOLDER}"/WRF_CHEM_Tools/Tests/Compatibility

  cp ${NETCDF}/include/netcdf.inc .

  echo " "
  echo " "
  echo "Library Compatibility Tests "
  echo "Test 1"
  $FC -c 01_fortran+c+netcdf_f.f
  $CC -c 01_fortran+c+netcdf_c.c
  $FC 01_fortran+c+netcdf_f.o 01_fortran+c+netcdf_c.o \
    -L${NETCDF}/lib -lnetcdff -lnetcdf

  ./a.out | tee comp_test1.txt
  export TEST_PASS=$(grep -w -o -c "SUCCESS" comp_test1.txt | awk '{print$1}')
  if [ $TEST_PASS -ge 1 ]; then
    echo "Compatibility Test 1 Passed"
  else
    echo "Compatibility Compiler Test 1 Failed"
    exit
  fi
  echo " "
  read -r -t 3 -p "I am going to wait for 3 seconds only ..."

  echo " "

  echo "Test 2"
  $MPIFC -c 02_fortran+c+netcdf+mpi_f.f
  $MPICC -c 02_fortran+c+netcdf+mpi_c.c
  $MPIFC 02_fortran+c+netcdf+mpi_f.o \
    02_fortran+c+netcdf+mpi_c.o \
    -L${NETCDF}/lib -lnetcdff -lnetcdf

  mpirun ./a.out | tee comp_test2.txt
  export TEST_PASS=$(grep -w -o -c "SUCCESS" comp_test2.txt | awk '{print$1}')
  if [ $TEST_PASS -ge 1 ]; then
    echo "Compatibility Test 2 Passed"
  else
    echo "Compatibility Compiler Test 2 Failed"
    exit
  fi
  echo " "
  read -r -t 3 -p "I am going to wait for 3 seconds only ..."
  echo " "

  echo " All tests completed and passed"
  echo " "
  # Downloading WRF-CHEM Tools and untarring files
  cd "${WRF_FOLDER}"/WRF_CHEM_Tools/Downloads

  wget -c https://www.acom.ucar.edu/wrf-chem/mozbc.tar
  wget -c https://www.acom.ucar.edu/wrf-chem/UBC_inputs.tar
  wget -c https://www.acom.ucar.edu//wrf-chem/megan_bio_emiss.tar
  wget -c https://www.acom.ucar.edu/wrf-chem/megan.data.tar.gz
  wget -c https://www.acom.ucar.edu/wrf-chem/wes-coldens.tar
  wget -c https://www.acom.ucar.edu/wrf-chem/ANTHRO.tar
  wget -c https://www.acom.ucar.edu/webt/wrf-chem/processors/EDGAR-HTAP.tgz
  wget -c https://www.acom.ucar.edu/wrf-chem/EPA_ANTHRO_EMIS.tgz
  wget -c https://www2.acom.ucar.edu/sites/default/files/documents/aircraft_preprocessor_files.tar
  # Downloading FINN
  wget -c https://www.acom.ucar.edu/Data/fire/data/finn2/FINNv2.4_MOD_MOZART_2020_c20210617.txt.gz
  wget -c https://www.acom.ucar.edu/Data/fire/data/finn2/FINNv2.4_MOD_MOZART_2013_c20210617.txt.gz
  wget -c https://www.acom.ucar.edu/Data/fire/data/finn2/FINNv2.4_MODVRS_MOZART_2019_c20210615.txt.gz
  wget -c https://www.acom.ucar.edu/Data/fire/data/fire_emis.tgz
  wget -c https://www.acom.ucar.edu/Data/fire/data/fire_emis_input.tar
  wget -c https://www.acom.ucar.edu/Data/fire/data/TrashEmis.zip

  echo ""
  echo "Unpacking Mozbc."
  env -u LD_LIBRARY_PATH tar -xvf mozbc.tar -C "${WRF_FOLDER}"/WRF_CHEM_Tools/mozbc
  echo ""
  echo "Unpacking MEGAN Bio Emission."
  env -u LD_LIBRARY_PATH tar -xvf megan_bio_emiss.tar -C "${WRF_FOLDER}"/WRF_CHEM_Tools/megan_bio_emiss
  echo ""
  echo "Unpacking MEGAN Bio Emission Data."
  env -u LD_LIBRARY_PATH tar -xzf megan.data.tar.gz -C "${WRF_FOLDER}"/WRF_CHEM_Tools/megan_bio_data
  echo ""
  echo "Unpacking Wes Coldens"
  env -u LD_LIBRARY_PATH tar -xvf wes-coldens.tar -C "${WRF_FOLDER}"/WRF_CHEM_Tools/wes_coldens
  echo ""
  echo "Unpacking Unpacking ANTHRO Emission."
  env -u LD_LIBRARY_PATH tar -xvf ANTHRO.tar -C "${WRF_FOLDER}"/WRF_CHEM_Tools/ANTHRO_EMIS
  echo ""
  echo "Unpacking EDGAR-HTAP."
  env -u LD_LIBRARY_PATH tar -xzf EDGAR-HTAP.tgz -C "${WRF_FOLDER}"/WRF_CHEM_Tools/EDGAR_HTAP
  echo ""
  echo "Unpacking EPA ANTHRO Emission."
  env -u LD_LIBRARY_PATH tar -xzf EPA_ANTHRO_EMIS.tgz -C "${WRF_FOLDER}"/WRF_CHEM_Tools/EPA_ANTHRO_EMIS
  echo ""
  echo "Unpacking Upper Boundary Conditions."
  env -u LD_LIBRARY_PATH tar -xvf UBC_inputs.tar -C "${WRF_FOLDER}"/WRF_CHEM_Tools/UBC
  echo ""
  echo "Unpacking Aircraft Preprocessor Files."
  echo ""
  env -u LD_LIBRARY_PATH tar -xvf aircraft_preprocessor_files.tar -C "${WRF_FOLDER}"/WRF_CHEM_Tools/Aircraft
  echo ""
  echo "Unpacking Fire INventory from NCAR (FINN)"
  env -u LD_LIBRARY_PATH tar -xzf fire_emis.tgz -C "${WRF_FOLDER}"/WRF_CHEM_Tools/FINN
  env -u LD_LIBRARY_PATH tar -xvf fire_emis_input.tar
  env -u LD_LIBRARY_PATH tar -xzf grass_from_img.nc.tgz -C "${WRF_FOLDER}"/WRF_CHEM_Tools/FINN/grid_finn_fire_emis_v2020/src
  env -u LD_LIBRARY_PATH tar -xzf tempfor_from_img.nc.tgz -C "${WRF_FOLDER}"/WRF_CHEM_Tools/FINN/grid_finn_fire_emis_v2020/src
  env -u LD_LIBRARY_PATH tar -xzf shrub_from_img.nc.tgz -C "${WRF_FOLDER}"/WRF_CHEM_Tools/FINN/grid_finn_fire_emis_v2020/src
  env -u LD_LIBRARY_PATH tar -xzf tropfor_from_img.nc.tgz -C "${WRF_FOLDER}"/WRF_CHEM_Tools/FINN/grid_finn_fire_emis_v2020/src

  mv "${WRF_FOLDER}"/WRF_CHEM_Tools/Downloads/FINNv2.4_MOD_MOZART_2020_c20210617.txt.gz "${WRF_FOLDER}"/WRF_CHEM_Tools/FINN
  mv "${WRF_FOLDER}"/WRF_CHEM_Tools/Downloads/FINNv2.4_MOD_MOZART_2013_c20210617.txt.gz "${WRF_FOLDER}"/WRF_CHEM_Tools/FINN
  mv "${WRF_FOLDER}"/WRF_CHEM_Tools/Downloads/FINNv2.4_MODVRS_MOZART_2019_c20210615.txt.gz "${WRF_FOLDER}"/WRF_CHEM_Tools/FINN

  unzip TrashEmis.zip
  mv "${WRF_FOLDER}"/WRF_CHEM_Tools/Downloads/ALL_Emiss_04282014.nc "${WRF_FOLDER}"/WRF_CHEM_Tools/FINN/grid_finn_fire_emis_v2020/src

  cd "${WRF_FOLDER}"/WRF_CHEM_Tools/FINN

  gunzip FINNv2.4_MOD_MOZART_2020_c20210617.txt.gz
  gunzip FINNv2.4_MOD_MOZART_2013_c20210617.txt.gz
  gunzip FINNv2.4_MODVRS_MOZART_2019_c20210615.txt.gz
  ############################Installation of Mozbc #############################
  # Recalling variables from install script to make sure the path is right

  cd "${WRF_FOLDER}"/WRF_CHEM_Tools/mozbc
  chmod +x make_mozbc
  export DIR="${WRF_FOLDER}"/WRF_CHEM_Tools/Libs
  export NETCDF_DIR=$DIR/NETCDF
  sed -i 's/"${ar_libs} -lnetcdff"/"-lnetcdff ${ar_libs}"/' make_mozbc

  ./make_mozbc 2>&1 | tee make.log

  ################## Information on Upper Boundary Conditions ###################

  cd "${WRF_FOLDER}"/WRF_CHEM_Tools/UBC/
  wget -c https://www2.acom.ucar.edu/sites/default/files/documents/8A_2_Barth_WRFWorkshop_11.pdf

  ########################## MEGAN Bio Emission #################################
  # Data for MEGAN Bio Emission located in
  # "${WRF_FOLDER}"/WRF_CHEM_Tools/megan_bio_data

  cd "${WRF_FOLDER}"/WRF_CHEM_Tools/megan_bio_emiss
  chmod +x make_util
  export DIR="${WRF_FOLDER}"/WRF_CHEM_Tools/Libs

  export NETCDF_DIR=$DIR/NETCDF
  sed -i 's/"${ar_libs} -lnetcdff"/"-lnetcdff ${ar_libs}"/' make_util

  ./make_util megan_bio_emiss 2>&1 | tee make.bio.log
  ./make_util megan_xform 2>&1 | tee make.xform.log
  ./make_util surfdata_xform 2>&1 | tee make.surfdata.log

  ############################# Anthroprogenic Emissions #########################

  cd "${WRF_FOLDER}"/WRF_CHEM_Tools/ANTHRO_EMIS/ANTHRO/src
  chmod +x make_anthro
  export DIR="${WRF_FOLDER}"/WRF_CHEM_Tools/Libs

  export NETCDF_DIR=$DIR/NETCDF
  sed -i 's/"${ar_libs} -lnetcdff"/"-lnetcdff ${ar_libs}"/' make_anthro

  ./make_anthro 2>&1 | tee make.log

  ############################# EDGAR HTAP ######################################
  #  This directory contains EDGAR-HTAP anthropogenic emission files for the
  #  year 2010.  The files are in the MOZCART and MOZART-MOSAIC sub-directories.
  #  The MOZCART files are intended to be used for the WRF MOZCART_KPP chemical
  #  option.  The MOZART-MOSAIC files are intended to be used with the following
  #  WRF chemical options (See read -rme in Folder

  ######################### EPA Anthroprogenic Emissions ########################
  cd "${WRF_FOLDER}"/WRF_CHEM_Tools/EPA_ANTHRO_EMIS/src
  chmod +x make_anthro
  export DIR="${WRF_FOLDER}"/WRF_CHEM_Tools/Libs

  export NETCDF_DIR=$DIR/NETCDF
  sed -i 's/"${ar_libs} -lnetcdff"/"-lnetcdff ${ar_libs}"/' make_anthro

  ./make_anthro 2>&1 | tee make.log

  ######################### Weseley EXO Coldens ##################################
  cd "${WRF_FOLDER}"/WRF_CHEM_Tools/wes_coldens
  chmod +x make_util
  export DIR="${WRF_FOLDER}"/WRF_CHEM_Tools/Libs

  export NETCDF_DIR=$DIR/NETCDF
  sed -i 's/"${ar_libs} -lnetcdff"/"-lnetcdff ${ar_libs}"/' make_util

  ./make_util wesely 2>&1 | tee make.wesely.log
  ./make_util exo_coldens 2>&1 | tee make.exo.log

  ########################## Aircraft Emissions Preprocessor #####################
  # This is an IDL based preprocessor to create WRF-Chem read -ry aircraft emissions files
  # (wrfchemaircraft_) from a global inventory in netcdf format. Please consult the read -rME file
  # for how to use the preprocessor. The emissions inventory is not included, so the user must
  # provide their own.
  echo " "
  echo "######################################################################"
  echo " Please see script for details about Aircraft Emissions Preprocessor"
  echo "######################################################################"
  echo " "

  ######################## Fire INventory from NCAR (FINN) ###########################
  # Fire INventory from NCAR (FINN): A daily fire emissions product for atmospheric chemistry models
  # https://www2.acom.ucar.edu/modeling/finn-fire-inventory-ncar
  echo " "
  echo "###########################################"
  echo " Please see folder for details about FINN."
  echo "###########################################"
  echo " "

  #####################################BASH Script Finished##############################
  echo " "
  echo "WRF CHEM Tools & PREP-CHEM-SRC compiled with latest version of NETCDF files available on 03/01/2025"
  echo "If error occurs using WRFCHEM tools please update your NETCDF libraries or reconfigure with older libraries"
  echo "This is a WRC Chem Community tool made by a private user and is not supported by UCAR/NCAR"
  read -r -t 5 -p "BASH Script Finished"
fi

if [ "$Ubuntu_64bit_GNU" = "1" ] && [ "$aarch64" != "1" ]; then

  # Basic Package Management for WRF-CHEM Tools and Processors

  echo $PASSWD | sudo -S apt -y update
  echo $PASSWD | sudo -S apt -y upgrade
  # Basic Package Management for WRF-CHEM Tools and Processors

  echo $PASSWD | sudo -S apt -y update
  echo $PASSWD | sudo -S apt -y upgrade
  release_version=$(lsb_release -r -s)

  # Compare the release version
  if [ "$release_version" = "24.04" ]; then
    # Install Emacs without recommended packages
    echo $PASSWD | sudo -S apt install emacs --no-install-recommends -y
  else
    # Attempt to install Emacs if the release version is not 24.04
    echo "The release version is not 24.04, attempting to install Emacs."
    echo $PASSWD | sudo -S apt install emacs -y
  fi

  echo "$PASSWD" | sudo -S apt -y install bison build-essential byacc cmake csh curl default-jdk default-jre flex libfl-dev g++ gawk gcc gettext gfortran git ksh libcurl4-gnutls-dev libjpeg-dev libncurses6 libncursesw5-dev libpixman-1-dev libpng-dev libtool libxml2 libxml2-dev libxml-libxml-perl m4 make ncview pipenv pkg-config python3 python3-dev python3-pip python3-dateutil tcsh unzip xauth xorg time ghostscript less libbz2-dev libc6-dev libffi-dev libgdbm-dev libopenblas-dev libreadline-dev libssl-dev libtiff-dev libgeotiff-dev tk-dev vim wget

  #Fix any broken installations
  echo $PASSWD | sudo -S apt --fix-broken install

  # make sure some critical packages have been installed
  which cmake pkg-config make gcc g++ gfortran

  #Directory Listings
  export HOME=$(
    cd ~ \
      && pwd
  )
  mkdir $HOME/WRFCHEM
  export WRF_FOLDER=$HOME/WRFCHEM
  cd $HOME/WRFCHEM
  mkdir Downloads
  mkdir Libs
  mkdir Libs/grib2
  mkdir Libs/NETCDF
  mkdir "${WRF_FOLDER}"/WRF_CHEM_Tools
  mkdir "${WRF_FOLDER}"/WRF_CHEM_Tools/Libs
  mkdir "${WRF_FOLDER}"/WRF_CHEM_Tools/Libs/grib2
  mkdir "${WRF_FOLDER}"/WRF_CHEM_Tools/Libs/NETCDF
  mkdir "${WRF_FOLDER}"/WRF_CHEM_Tools/Downloads
  mkdir "${WRF_FOLDER}"/WRF_CHEM_Tools/mozbc
  mkdir "${WRF_FOLDER}"/WRF_CHEM_Tools/megan_bio_emiss
  mkdir "${WRF_FOLDER}"/WRF_CHEM_Tools/megan_bio_data
  mkdir "${WRF_FOLDER}"/WRF_CHEM_Tools/wes_coldens
  mkdir "${WRF_FOLDER}"/WRF_CHEM_Tools/ANTHRO_EMIS
  mkdir "${WRF_FOLDER}"/WRF_CHEM_Tools/EDGAR_HTAP
  mkdir "${WRF_FOLDER}"/WRF_CHEM_Tools/EPA_ANTHRO_EMIS
  mkdir "${WRF_FOLDER}"/WRF_CHEM_Tools/UBC
  mkdir "${WRF_FOLDER}"/WRF_CHEM_Tools/Aircraft
  mkdir "${WRF_FOLDER}"/WRF_CHEM_Tools/FINN
  mkdir "${WRF_FOLDER}"/WRF_CHEM_Tools/Tests
  mkdir "${WRF_FOLDER}"/WRF_CHEM_Tools/Tests/Environment
  mkdir "${WRF_FOLDER}"/WRF_CHEM_Tools/Tests/Compatibility

  ##############################Downloading Libraries############################
  cd "${WRF_FOLDER}"/WRF_CHEM_Tools/Downloads

  wget -c https://github.com/madler/zlib/releases/download/v$Zlib_Version/zlib-$Zlib_Version.tar.gz
  wget -c https://github.com/HDFGroup/hdf5/releases/download/hdf5_$HDF5_Version/hdf5-$HDF5_Version.tar.gz
  wget -c https://github.com/Unidata/netcdf-c/archive/refs/tags/v$Netcdf_C_Version.tar.gz
  wget -c https://github.com/Unidata/netcdf-fortran/archive/refs/tags/v$Netcdf_Fortran_Version.tar.gz
  wget -c https://download.sourceforge.net/libpng/libpng-$Libpng_Version.tar.gz
  wget -c https://www.ece.uvic.ca/~frodo/jasper/software/jasper-$Jasper_Version.zip
  wget -c https://github.com/pmodels/mpich/releases/download/v$Mpich_Version/mpich-$Mpich_Version.tar.gz
  wget -c https://parallel-netcdf.github.io/Release/pnetcdf-$Pnetcdf_Version.tar.gz

  #############################Core Management####################################

  export CPU_CORE=$(nproc) # number of available threads on system
  export CPU_6CORE="6"
  export CPU_QUARTER=$(($CPU_CORE / 4))                          #quarter of availble cores on system
  export CPU_QUARTER_EVEN=$(($CPU_QUARTER - ($CPU_QUARTER % 2))) #Forces CPU cores to even number to avoid partial core export. ie 7 cores would be 3.5 cores.

  if [ $CPU_CORE -le $CPU_6CORE ]; then #If statement for low core systems.  Forces computers to only use 1 core if there are 4 cores or less on the system. then
    export CPU_QUARTER_EVEN="2"
  else
    export CPU_QUARTER_EVEN=$(($CPU_QUARTER - ($CPU_QUARTER % 2)))
  fi

  echo "##########################################"
  echo "Number of Threads being used $CPU_QUARTER_EVEN"
  echo "##########################################"

  echo " "

  #############################Compilers############################
  export DIR="${WRF_FOLDER}"/WRF_CHEM_Tools/Libs
  export CC=gcc
  export CXX=g++
  export FC=gfortran
  export F77=gfortran
  export CFLAGS="-fPIC -fPIE -O3 -Wno-implicit-function-declaration -Wno-incompatible-pointer-types "

  #IF statement for GNU compiler issue
  export GCC_VERSION=$(/usr/bin/gcc -dumpfullversion | awk '{print$1}')
  export GFORTRAN_VERSION=$(/usr/bin/gfortran -dumpfullversion | awk '{print$1}')
  export GPLUSPLUS_VERSION=$(/usr/bin/g++ -dumpfullversion | awk '{print$1}')

  export GCC_VERSION_MAJOR_VERSION=$(echo $GCC_VERSION | awk -F. '{print $1}')
  export GFORTRAN_VERSION_MAJOR_VERSION=$(echo $GFORTRAN_VERSION | awk -F. '{print $1}')
  export GPLUSPLUS_VERSION_MAJOR_VERSION=$(echo $GPLUSPLUS_VERSION | awk -F. '{print $1}')

  export version_10="10"

  if [ $GCC_VERSION_MAJOR_VERSION -ge $version_10 ] || [ $GFORTRAN_VERSION_MAJOR_VERSION -ge $version_10 ] || [ $GPLUSPLUS_VERSION_MAJOR_VERSION -ge $version_10 ]; then
    export fallow_argument=-fallow-argument-mismatch
    export boz_argument=-fallow-invalid-boz
  else
    export fallow_argument=
    export boz_argument=
  fi

  export FFLAGS="$fallow_argument"
  export FCFLAGS="$fallow_argument"

  echo "##########################################"
  echo "FFLAGS = $FFLAGS"
  echo "FCFLAGS = $FCFLAGS"
  echo "CFLAGS = $CFLAGS"
  echo "##########################################"

  #############################zlib############################
  #Uncalling compilers due to comfigure issue with zlib$Zlib_Version
  #With CC & CXX definied ./configure uses different compiler Flags

  cd "${WRF_FOLDER}"/WRF_CHEM_Tools/Downloads
  env -u LD_LIBRARY_PATH tar -xzf zlib-$Zlib_Version.tar.gz
  cd zlib-$Zlib_Version/
  ./configure --prefix=$DIR/grib2 2>&1 | tee configure.log
  make -j $CPU_QUARTER_EVEN 2>&1 | tee make.log
  make -j $CPU_QUARTER_EVEN install 2>&1 | tee make.install.log

  ##############################MPICH############################
  cd "${WRF_FOLDER}"/WRF_CHEM_Tools/Downloads
  env -u LD_LIBRARY_PATH tar -xzf mpich-$Mpich_Version.tar.gz
  cd mpich-$Mpich_Version/
  F90= ./configure --prefix=$DIR/MPICH --with-device=ch3 FFLAGS=$FFLAGS FCFLAGS=$FCFLAGS 2>&1 | tee configure.log
  make -j $CPU_QUARTER_EVEN 2>&1 | tee make.log
  make -j $CPU_QUARTER_EVEN install 2>&1 | tee make.install.log

  export PATH=$DIR/MPICH/bin:$PATH

  export MPIFC=$DIR/MPICH/bin/mpifort
  export MPIF77=$DIR/MPICH/bin/mpifort
  export MPIF90=$DIR/MPICH/bin/mpifort
  export MPICC=$DIR/MPICH/bin/mpicc
  export MPICXX=$DIR/MPICH/bin/mpicxx

  echo " "

  #############################libpng############################
  cd "${WRF_FOLDER}"/WRF_CHEM_Tools/Downloads
  export LDFLAGS=-L$DIR/grib2/lib
  export CPPFLAGS=-I$DIR/grib2/include
  env -u LD_LIBRARY_PATH tar -xzf libpng-$Libpng_Version.tar.gz
  cd libpng-$Libpng_Version/
  CC=$MPICC FC=$MPIFC F77=$MPIF77 F90=$MPIF90 CXX=$MPICXX CFLAGS=$CFLAGS FFLAGS=$FFLAGS FCFLAGS=$FCFLAGS ./configure --prefix=$DIR/grib2 2>&1 | tee configure.log
  make -j $CPU_QUARTER_EVEN 2>&1 | tee make.log
  make -j $CPU_QUARTER_EVEN install 2>&1 | tee make.install.log

  #############################JasPer############################
  cd "${WRF_FOLDER}"/WRF_CHEM_Tools/Downloads
  unzip jasper-$Jasper_Version.zip
  cd jasper-$Jasper_Version/
  CC=$MPICC FC=$MPIFC F77=$MPIF77 F90=$MPIF90 CXX=$MPICXX CFLAGS=$CFLAGS FFLAGS=$FFLAGS FCFLAGS=$FCFLAGS ./configure --prefix=$DIR/grib2 2>&1 | tee configure.log
  make -j $CPU_QUARTER_EVEN 2>&1 | tee make.log
  make -j $CPU_QUARTER_EVEN install 2>&1 | tee make.install.log

  export JASPERLIB=$DIR/grib2/lib
  export JASPERINC=$DIR/grib2/include

  #############################hdf5 library for netcdf4 functionality############################
  cd "${WRF_FOLDER}"/WRF_CHEM_Tools/Downloads
  env -u LD_LIBRARY_PATH tar -xzf hdf5-$HDF5_Version.tar.gz
  cd hdf5-$HDF5_Version
  CC=$MPICC FC=$MPIFC F77=$MPIF77 F90=$MPIF90 CXX=$MPICXX CFLAGS=$CFLAGS FFLAGS=$FFLAGS FCFLAGS=$FCFLAGS ./configure --prefix=$DIR/grib2 --with-zlib=$DIR/grib2 --enable-hl --enable-fortran --enable-parallel 2>&1 | tee configure.log
  make -j $CPU_QUARTER_EVEN 2>&1 | tee make.log
  make -j $CPU_QUARTER_EVEN install 2>&1 | tee make.install.log

  export HDF5=$DIR/grib2
  export PHDF5=$DIR/grib2
  export LD_LIBRARY_PATH=$DIR/grib2/lib:$LD_LIBRARY_PATH

  echo " "

  #############################Install Parallel-netCDF##############################
  #Make file created with half of available cpu cores
  #Hard path for MPI added
  ##################################################################################
  cd "${WRF_FOLDER}"/WRF_CHEM_Tools/Downloads
  env -u LD_LIBRARY_PATH tar -xzf pnetcdf-$Pnetcdf_Version.tar.gz
  cd pnetcdf-$Pnetcdf_Version
  CC=$MPICC FC=$MPIFC F77=$MPIF77 F90=$MPIF90 CXX=$MPICXX CFLAGS=$CFLAGS FFLAGS=$FFLAGS FCFLAGS=$FCFLAGS ./configure --prefix=$DIR/grib2 --enable-shared --enable-static 2>&1 | tee configure.log
  make -j $CPU_QUARTER_EVEN 2>&1 | tee make.log
  make -j $CPU_QUARTER_EVEN install 2>&1 | tee make.install.log

  export PNETCDF=$DIR/grib2

  ##############################Install NETCDF C Library############################
  cd "${WRF_FOLDER}"/WRF_CHEM_Tools/Downloads
  env -u LD_LIBRARY_PATH tar -xzf v$Netcdf_C_Version.tar.gz
  cd netcdf-c-$Netcdf_C_Version/
  export CPPFLAGS=-I$DIR/grib2/include
  export LDFLAGS=-L$DIR/grib2/lib
  export LIBS="-lhdf5_hl -lhdf5 -lz -lcurl -lgfortran -lgcc -lm -ldl -lpnetcdf"
  CC=$MPICC FC=$MPIFC F77=$MPIF77 F90=$MPIF90 CXX=$MPICXX CFLAGS=$CFLAGS FFLAGS=$FFLAGS FCFLAGS=$FCFLAGS ./configure --prefix=$DIR/NETCDF --with-zlib=$DIR/grib2 --disable-dap --enable-netcdf-4 --enable-netcdf4 --enable-shared --enable-static --enable-pnetcdf --enable-cdf5 --enable-parallel-tests 2>&1 | tee configure.log
  make -j $CPU_QUARTER_EVEN 2>&1 | tee make.log
  make -j $CPU_QUARTER_EVEN install 2>&1 | tee make.install.log

  export PATH=$DIR/NETCDF/bin:$PATH
  export NETCDF=$DIR/NETCDF

  ##############################NetCDF fortran library############################
  cd "${WRF_FOLDER}"/WRF_CHEM_Tools/Downloads
  env -u LD_LIBRARY_PATH tar -xzf v$Netcdf_Fortran_Version.tar.gz
  cd netcdf-fortran-$Netcdf_Fortran_Version/
  export LD_LIBRARY_PATH=$DIR/NETCDF/lib:$LD_LIBRARY_PATH
  export CPPFLAGS="-I$DIR/NETCDF/include -I$DIR/grib2/include"
  export LDFLAGS="-L$DIR/NETCDF/lib -L$DIR/grib2/lib"
  export LIBS="-lnetcdf -lpnetcdf -lcurl -lhdf5_hl -lhdf5 -lz -ldl -lgcc -lgfortran"
  CC=$MPICC FC=$MPIFC F77=$MPIF77 F90=$MPIF90 CXX=$MPICXX CFLAGS=$CFLAGS FFLAGS=$FFLAGS FCFLAGS=$FCFLAGS ./configure --prefix=$DIR/NETCDF --enable-netcdf-4 --enable-netcdf4 --enable-shared --enable-static --enable-parallel-tests --enable-hdf5 2>&1 | tee configure.log
  make -j $CPU_QUARTER_EVEN 2>&1 | tee make.log
  make -j $CPU_QUARTER_EVEN install 2>&1 | tee make.install.log

  echo " "
  #################################### System Environment Tests ##############

  cd "${WRF_FOLDER}"/WRF_CHEM_Tools/Downloads
  wget -c https://www2.mmm.ucar.edu/wrf/OnLineTutorial/compile_tutorial/tar_files/Fortran_C_NETCDF_MPI_tests.tar
  wget -c https://www2.mmm.ucar.edu/wrf/OnLineTutorial/compile_tutorial/tar_files/Fortran_C_tests.tar

  env -u LD_LIBRARY_PATH tar -xvf Fortran_C_tests.tar -C "${WRF_FOLDER}"/WRF_CHEM_Tools/Tests/Environment
  env -u LD_LIBRARY_PATH tar -xvf Fortran_C_NETCDF_MPI_tests.tar -C "${WRF_FOLDER}"/WRF_CHEM_Tools/Tests/Compatibility

  export one="1"
  echo " "
  ############## Testing Environment #####

  cd "${WRF_FOLDER}"/WRF_CHEM_Tools/Tests/Environment

  cp ${NETCDF}/include/netcdf.inc .

  echo " "
  echo " "
  echo "Environment Testing "
  echo "Test 1"
  $FC TEST_1_fortran_only_fixed.f
  ./a.out | tee env_test1.txt
  export TEST_PASS=$(grep -w -o -c "SUCCESS" env_test1.txt | awk '{print$1}')
  if [ $TEST_PASS -ge 1 ]; then
    echo "Enviroment Test 1 Passed"
  else
    echo "Environment Compiler Test 1 Failed"
    exit
  fi
  read -r -t 3 -p "I am going to wait for 3 seconds only ..."

  echo " "
  echo "Test 2"
  $FC TEST_2_fortran_only_free.f90
  ./a.out | tee env_test2.txt
  export TEST_PASS=$(grep -w -o -c "SUCCESS" env_test2.txt | awk '{print$1}')
  if [ $TEST_PASS -ge 1 ]; then
    echo "Enviroment Test 2 Passed"
  else
    echo "Environment Compiler Test 2 Failed"
    exit
  fi
  echo " "
  read -r -t 3 -p "I am going to wait for 3 seconds only ..."

  echo " "
  echo "Test 3"
  $CC TEST_3_c_only.c
  ./a.out | tee env_test3.txt
  export TEST_PASS=$(grep -w -o -c "SUCCESS" env_test3.txt | awk '{print$1}')
  if [ $TEST_PASS -ge 1 ]; then
    echo "Enviroment Test 3 Passed"
  else
    echo "Environment Compiler Test 3 Failed"
    exit
  fi
  echo " "
  read -r -t 3 -p "I am going to wait for 3 seconds only ..."

  echo " "
  echo "Test 4"
  $CC -c -m64 TEST_4_fortran+c_c.c
  $FC -c -m64 TEST_4_fortran+c_f.f90
  $FC -m64 TEST_4_fortran+c_f.o TEST_4_fortran+c_c.o
  ./a.out | tee env_test4.txt
  export TEST_PASS=$(grep -w -o -c "SUCCESS" env_test4.txt | awk '{print$1}')
  if [ $TEST_PASS -ge 1 ]; then
    echo "Enviroment Test 4 Passed"
  else
    echo "Environment Compiler Test 4 Failed"
    exit
  fi
  echo " "
  read -r -t 3 -p "I am going to wait for 3 seconds only ..."

  echo " "
  ############## Testing Environment #####

  cd "${WRF_FOLDER}"/WRF_CHEM_Tools/Tests/Compatibility

  cp ${NETCDF}/include/netcdf.inc .

  echo " "
  echo " "
  echo "Library Compatibility Tests "
  echo "Test 1"
  $FC -c 01_fortran+c+netcdf_f.f
  $CC -c 01_fortran+c+netcdf_c.c
  $FC 01_fortran+c+netcdf_f.o 01_fortran+c+netcdf_c.o \
    -L${NETCDF}/lib -lnetcdff -lnetcdf

  ./a.out | tee comp_test1.txt
  export TEST_PASS=$(grep -w -o -c "SUCCESS" comp_test1.txt | awk '{print$1}')
  if [ $TEST_PASS -ge 1 ]; then
    echo "Compatibility Test 1 Passed"
  else
    echo "Compatibility Compiler Test 1 Failed"
    exit
  fi
  echo " "
  read -r -t 3 -p "I am going to wait for 3 seconds only ..."

  echo " "

  echo "Test 2"
  $MPIFC -c 02_fortran+c+netcdf+mpi_f.f
  $MPICC -c 02_fortran+c+netcdf+mpi_c.c
  $MPIFC 02_fortran+c+netcdf+mpi_f.o \
    02_fortran+c+netcdf+mpi_c.o \
    -L${NETCDF}/lib -lnetcdff -lnetcdf

  $DIR/MPICH/bin/mpirun ./a.out | tee comp_test2.txt
  export TEST_PASS=$(grep -w -o -c "SUCCESS" comp_test2.txt | awk '{print$1}')
  if [ $TEST_PASS -ge 1 ]; then
    echo "Compatibility Test 2 Passed"
  else
    echo "Compatibility Compiler Test 2 Failed"
    exit
  fi
  echo " "
  read -r -t 3 -p "I am going to wait for 3 seconds only ..."
  echo " "

  echo " All tests completed and passed"
  echo " "
  # Downloading WRF-CHEM Tools and untarring files
  cd "${WRF_FOLDER}"/WRF_CHEM_Tools/Downloads

  wget -c https://www.acom.ucar.edu/wrf-chem/mozbc.tar
  wget -c https://www.acom.ucar.edu/wrf-chem/UBC_inputs.tar
  wget -c https://www.acom.ucar.edu//wrf-chem/megan_bio_emiss.tar
  wget -c https://www.acom.ucar.edu/wrf-chem/megan.data.tar.gz
  wget -c https://www.acom.ucar.edu/wrf-chem/wes-coldens.tar
  wget -c https://www.acom.ucar.edu/wrf-chem/ANTHRO.tar
  wget -c https://www.acom.ucar.edu/webt/wrf-chem/processors/EDGAR-HTAP.tgz
  wget -c https://www.acom.ucar.edu/wrf-chem/EPA_ANTHRO_EMIS.tgz
  wget -c https://www2.acom.ucar.edu/sites/default/files/documents/aircraft_preprocessor_files.tar
  # Downloading FINN
  wget -c https://www.acom.ucar.edu/Data/fire/data/finn2/FINNv2.4_MOD_MOZART_2020_c20210617.txt.gz
  wget -c https://www.acom.ucar.edu/Data/fire/data/finn2/FINNv2.4_MOD_MOZART_2013_c20210617.txt.gz
  wget -c https://www.acom.ucar.edu/Data/fire/data/finn2/FINNv2.4_MODVRS_MOZART_2019_c20210615.txt.gz
  wget -c https://www.acom.ucar.edu/Data/fire/data/fire_emis.tgz
  wget -c https://www.acom.ucar.edu/Data/fire/data/fire_emis_input.tar
  wget -c https://www.acom.ucar.edu/Data/fire/data/TrashEmis.zip

  echo ""
  echo "Unpacking Mozbc."
  env -u LD_LIBRARY_PATH tar -xvf mozbc.tar -C "${WRF_FOLDER}"/WRF_CHEM_Tools/mozbc
  echo ""
  echo "Unpacking MEGAN Bio Emission."
  env -u LD_LIBRARY_PATH tar -xvf megan_bio_emiss.tar -C "${WRF_FOLDER}"/WRF_CHEM_Tools/megan_bio_emiss
  echo ""
  echo "Unpacking MEGAN Bio Emission Data."
  env -u LD_LIBRARY_PATH tar -xzf megan.data.tar.gz -C "${WRF_FOLDER}"/WRF_CHEM_Tools/megan_bio_data
  echo ""
  echo "Unpacking Wes Coldens"
  env -u LD_LIBRARY_PATH tar -xvf wes-coldens.tar -C "${WRF_FOLDER}"/WRF_CHEM_Tools/wes_coldens
  echo ""
  echo "Unpacking Unpacking ANTHRO Emission."
  env -u LD_LIBRARY_PATH tar -xvf ANTHRO.tar -C "${WRF_FOLDER}"/WRF_CHEM_Tools/ANTHRO_EMIS
  echo ""
  echo "Unpacking EDGAR-HTAP."
  env -u LD_LIBRARY_PATH tar -xzf EDGAR-HTAP.tgz -C "${WRF_FOLDER}"/WRF_CHEM_Tools/EDGAR_HTAP
  echo ""
  echo "Unpacking EPA ANTHRO Emission."
  env -u LD_LIBRARY_PATH tar -xzf EPA_ANTHRO_EMIS.tgz -C "${WRF_FOLDER}"/WRF_CHEM_Tools/EPA_ANTHRO_EMIS
  echo ""
  echo "Unpacking Upper Boundary Conditions."
  env -u LD_LIBRARY_PATH tar -xvf UBC_inputs.tar -C "${WRF_FOLDER}"/WRF_CHEM_Tools/UBC
  echo ""
  echo "Unpacking Aircraft Preprocessor Files."
  echo ""
  env -u LD_LIBRARY_PATH tar -xvf aircraft_preprocessor_files.tar -C "${WRF_FOLDER}"/WRF_CHEM_Tools/Aircraft
  echo ""
  echo "Unpacking Fire INventory from NCAR (FINN)"
  env -u LD_LIBRARY_PATH tar -xzf fire_emis.tgz -C "${WRF_FOLDER}"/WRF_CHEM_Tools/FINN
  env -u LD_LIBRARY_PATH tar -xvf fire_emis_input.tar
  env -u LD_LIBRARY_PATH tar -xzf grass_from_img.nc.tgz -C "${WRF_FOLDER}"/WRF_CHEM_Tools/FINN/grid_finn_fire_emis_v2020/src
  env -u LD_LIBRARY_PATH tar -xzf tempfor_from_img.nc.tgz -C "${WRF_FOLDER}"/WRF_CHEM_Tools/FINN/grid_finn_fire_emis_v2020/src
  env -u LD_LIBRARY_PATH tar -xzf shrub_from_img.nc.tgz -C "${WRF_FOLDER}"/WRF_CHEM_Tools/FINN/grid_finn_fire_emis_v2020/src
  env -u LD_LIBRARY_PATH tar -xzf tropfor_from_img.nc.tgz -C "${WRF_FOLDER}"/WRF_CHEM_Tools/FINN/grid_finn_fire_emis_v2020/src

  mv "${WRF_FOLDER}"/WRF_CHEM_Tools/Downloads/FINNv2.4_MOD_MOZART_2020_c20210617.txt.gz "${WRF_FOLDER}"/WRF_CHEM_Tools/FINN
  mv "${WRF_FOLDER}"/WRF_CHEM_Tools/Downloads/FINNv2.4_MOD_MOZART_2013_c20210617.txt.gz "${WRF_FOLDER}"/WRF_CHEM_Tools/FINN
  mv "${WRF_FOLDER}"/WRF_CHEM_Tools/Downloads/FINNv2.4_MODVRS_MOZART_2019_c20210615.txt.gz "${WRF_FOLDER}"/WRF_CHEM_Tools/FINN

  unzip TrashEmis.zip
  mv "${WRF_FOLDER}"/WRF_CHEM_Tools/Downloads/ALL_Emiss_04282014.nc "${WRF_FOLDER}"/WRF_CHEM_Tools/FINN/grid_finn_fire_emis_v2020/src

  cd "${WRF_FOLDER}"/WRF_CHEM_Tools/FINN

  gunzip FINNv2.4_MOD_MOZART_2020_c20210617.txt.gz
  gunzip FINNv2.4_MOD_MOZART_2013_c20210617.txt.gz
  gunzip FINNv2.4_MODVRS_MOZART_2019_c20210615.txt.gz
  ############################Installation of Mozbc #############################
  # Recalling variables from install script to make sure the path is right

  cd "${WRF_FOLDER}"/WRF_CHEM_Tools/mozbc
  chmod +x make_mozbc
  export DIR="${WRF_FOLDER}"/WRF_CHEM_Tools/Libs
  export FC=gfortran
  export NETCDF_DIR=$DIR/NETCDF
  sed -i 's/"${ar_libs} -lnetcdff"/"-lnetcdff ${ar_libs}"/' make_mozbc
  sed -i '8s/FFLAGS = --g/FFLAGS = --g ${fallow_argument}/' Makefile
  sed -i '10s/FFLAGS = -g/FFLAGS = -g ${fallow_argument}/' Makefile
  ./make_mozbc 2>&1 | tee make.log

  ################## Information on Upper Boundary Conditions ###################

  cd "${WRF_FOLDER}"/WRF_CHEM_Tools/UBC/
  wget -c https://www2.acom.ucar.edu/sites/default/files/documents/8A_2_Barth_WRFWorkshop_11.pdf

  ########################## MEGAN Bio Emission #################################
  # Data for MEGAN Bio Emission located in
  # "${WRF_FOLDER}"/WRF_CHEM_Tools/megan_bio_data

  cd "${WRF_FOLDER}"/WRF_CHEM_Tools/megan_bio_emiss
  chmod +x make_util
  export DIR="${WRF_FOLDER}"/WRF_CHEM_Tools/Libs
  export FC=gfortran
  export NETCDF_DIR=$DIR/NETCDF
  sed -i 's/"${ar_libs} -lnetcdff"/"-lnetcdff ${ar_libs}"/' make_util
  sed -i '8s/FFLAGS = --g/FFLAGS = --g ${fallow_argument}/' Makefile
  sed -i '10s/FFLAGS = -g/FFLAGS = -g ${fallow_argument}/' Makefile
  ./make_util megan_bio_emiss 2>&1 | tee make.bio.log
  ./make_util megan_xform 2>&1 | tee make.xform.log
  ./make_util surfdata_xform 2>&1 | tee make.surfdata.log

  ############################# Anthroprogenic Emissions #########################

  cd "${WRF_FOLDER}"/WRF_CHEM_Tools/ANTHRO_EMIS/ANTHRO/src
  chmod +x make_anthro
  export DIR="${WRF_FOLDER}"/WRF_CHEM_Tools/Libs
  export FC=gfortran
  export NETCDF_DIR=$DIR/NETCDF
  sed -i 's/"${ar_libs} -lnetcdff"/"-lnetcdff ${ar_libs}"/' make_anthro
  sed -i '8s/FFLAGS = --g/FFLAGS = --g ${fallow_argument}/' Makefile
  sed -i '10s/FFLAGS = -g/FFLAGS = -g ${fallow_argument}/' Makefile
  ./make_anthro 2>&1 | tee make.log

  ############################# EDGAR HTAP ######################################
  #  This directory contains EDGAR-HTAP anthropogenic emission files for the
  #  year 2010.  The files are in the MOZCART and MOZART-MOSAIC sub-directories.
  #  The MOZCART files are intended to be used for the WRF MOZCART_KPP chemical
  #  option.  The MOZART-MOSAIC files are intended to be used with the following
  #  WRF chemical options (See read -rme in Folder

  ######################### EPA Anthroprogenic Emissions ########################
  cd "${WRF_FOLDER}"/WRF_CHEM_Tools/EPA_ANTHRO_EMIS/src
  chmod +x make_anthro
  export DIR="${WRF_FOLDER}"/WRF_CHEM_Tools/Libs
  export FC=gfortran
  export NETCDF_DIR=$DIR/NETCDF
  sed -i 's/"${ar_libs} -lnetcdff"/"-lnetcdff ${ar_libs}"/' make_anthro
  sed -i '8s/FFLAGS = --g/FFLAGS = --g ${fallow_argument}/' Makefile
  sed -i '10s/FFLAGS = -g/FFLAGS = -g ${fallow_argument}/' Makefile
  ./make_anthro 2>&1 | tee make.log

  ######################### Weseley EXO Coldens ##################################
  cd "${WRF_FOLDER}"/WRF_CHEM_Tools/wes_coldens
  chmod +x make_util
  export DIR="${WRF_FOLDER}"/WRF_CHEM_Tools/Libs
  export FC=gfortran
  export NETCDF_DIR=$DIR/NETCDF
  sed -i 's/"${ar_libs} -lnetcdff"/"-lnetcdff ${ar_libs}"/' make_util
  sed -i '8s/FFLAGS = --g/FFLAGS = --g ${fallow_argument}/' Makefile
  sed -i '10s/FFLAGS = -g/FFLAGS = -g ${fallow_argument}/' Makefile
  ./make_util wesely 2>&1 | tee make.wesely.log
  ./make_util exo_coldens 2>&1 | tee make.exo.log

  ########################## Aircraft Emissions Preprocessor #####################
  # This is an IDL based preprocessor to create WRF-Chem read -ry aircraft emissions files
  # (wrfchemaircraft_) from a global inventory in netcdf format. Please consult the read -rME file
  # for how to use the preprocessor. The emissions inventory is not included, so the user must
  # provide their own.
  echo " "
  echo "######################################################################"
  echo " Please see script for details about Aircraft Emissions Preprocessor"
  echo "######################################################################"
  echo " "

  ######################## Fire INventory from NCAR (FINN) ###########################
  # Fire INventory from NCAR (FINN): A daily fire emissions product for atmospheric chemistry models
  # https://www2.acom.ucar.edu/modeling/finn-fire-inventory-ncar
  echo " "
  echo "###########################################"
  echo " Please see folder for details about FINN."
  echo "###########################################"
  echo " "

  ######################################### PREP-CHEM-SRC ##############################################
  # PREP-CHEM-SRC is a pollutant emissions numerical too developed at CPTEC/INPE
  # whose function is to create data of atmospheric pollutant emissions from biomass burning,
  # photosynthesis or other forest transformation processes, combustion of oil-based products
  # by vehicles or industry, charcoal production, and many other processes.
  # The system is maintained and developed at CPTEC/INPE by the GMAI group, which not
  # only updates versions of data such as EDGAR, RETRO, MEGAN, etc., but also
  # implements new functionalities such as volcanic emissions which is present now in this
  # version.
  # The purpose of this guide is to present how to install, compile and run the pre-processor.
  # Finally, the steps for utilizing the emissions data in the CCATT-BRAMS, WRF-Chem and
  # FIM-Chem models are presented.
  # We recommend that you read -r the article “PREP-CHEM-SRC – 1.0: a preprocessor of
  # trace gas and aerosol emission fields for regional and global atmospheric chemistry
  # models” (Freitas et al., 2010 - http://www.geosci-model-dev.net/4/419/2011/gmd-4-419-
  # 2011.pdf).
  # Email: mailto:atende.cptec@inpe.br
  # WEB: http://brams.cptec.inpe.br
  # http:// meioambiente.cptec.inpe.br
  # Prep-Chem-Src v1.5.0 (note v1.8.3 is in Beta still)
  #########################################################################################################

  # Downloading PREP-CHEM-SRC-1.5 and untarring files
  mkdir "${WRF_FOLDER}"/WRF_CHEM_Tools/PREP-CHEM-SRC-1.5

  cd "${WRF_FOLDER}"/WRF_CHEM_Tools/Downloads

  wget -c http://ftp.cptec.inpe.br/pesquisa/bramsrd/BRAMS_5.4/PREP-CHEM/PREP-CHEM-SRC-1.5.tar.gz

  env -u LD_LIBRARY_PATH tar -xzf PREP-CHEM-SRC-1.5.tar.gz -C "${WRF_FOLDER}"/WRF_CHEM_Tools/PREP-CHEM-SRC-1.5

  cd "${WRF_FOLDER}"/WRF_CHEM_Tools/PREP-CHEM-SRC-1.5

  # Installation of PREP-CHEM-SRC-1.5

  cd "${WRF_FOLDER}"/WRF_CHEM_Tools/PREP-CHEM-SRC-1.5/bin/build

  sed -i '47s|/scratchin/grupos/catt-brams/shared/libs/gfortran/netcdf-4.1.3|${DIR}/NETCDF|' include.mk.gfortran.wrf          #Changing NETDCF Location
  sed -i '53s|/scratchin/grupos/catt-brams/shared/libs/gfortran/hdf5-1.8.13-serial|${DIR}/grib2|' include.mk.gfortran.wrf     #Changing HDF5 Location
  sed -i '55s|-L/scratchin/grupos/catt-brams/shared/libs/gfortran/zlib-1.2.8/lib|-L${DIR}/grib2/lib|' include.mk.gfortran.wrf #Changing zlib Location
  sed -i '69s|-frecord-marker=4|-frecord-marker=4 ${fallow_argument}|' include.mk.gfortran.wrf                                #Changing adding fallow argument mismatch to fix dummy error

  make OPT=gfortran.wrf CHEM=RADM_WRF_FIM AER=SIMPLE 2>&1 | tee make.log # Compiling and making of PRE-CHEM-SRC-1.5

  # IF statement to check that all files were created.
  cd "${WRF_FOLDER}"/WRF_CHEM_Tools/PREP-CHEM-SRC-1.5/bin
  n=$(ls ./*.exe | wc -l)
  if (($n >= 2)); then
    echo "All expected files created."
    read -r -t 5 -p "Finished installing WRF-CHEM-PREP. I am going to wait for 5 seconds only ..."
  else
    echo "Missing one or more expected files. Exiting the script."
    read -r -p "Please contact script authors for assistance, press 'Enter' to exit script."
    exit
  fi
  echo " "

  #####################################BASH Script Finished##############################
  echo " "
  echo "WRF CHEM Tools & PREP_CHEM_SRC compiled with latest version of NETCDF files available on 03/01/2025"
  echo "If error occurs using WRFCHEM tools please update your NETCDF libraries or reconfigure with older libraries"
  echo "This is a WRC Chem Community tool made by a private user and is not supported by UCAR/NCAR"
  read -r -t 5 -p "BASH Script Finished"

fi

if [ "$Ubuntu_64bit_GNU" = "1" ] && ["$aarch64" = "1" ]; then

  # Basic Package Management for WRF-CHEM Tools and Processors

  echo $PASSWD | sudo -S apt -y update
  echo $PASSWD | sudo -S apt -y upgrade
  # Basic Package Management for WRF-CHEM Tools and Processors

  echo $PASSWD | sudo -S apt -y update
  echo $PASSWD | sudo -S apt -y upgrade
  release_version=$(lsb_release -r -s)

  # Compare the release version
  if [ "$release_version" = "24.04" ]; then
    # Install Emacs without recommended packages
    echo $PASSWD | sudo -S apt install emacs --no-install-recommends -y
  else
    # Attempt to install Emacs if the release version is not 24.04
    echo "The release version is not 24.04, attempting to install Emacs."
    echo $PASSWD | sudo -S apt install emacs -y
  fi

  echo "$PASSWD" | sudo -S apt -y install bison build-essential byacc cmake csh curl default-jdk default-jre flex libfl-dev g++ gawk gcc gettext gfortran git ksh libcurl4-gnutls-dev libjpeg-dev libncurses6 libncursesw5-dev libpixman-1-dev libpng-dev libtool libxml2 libxml2-dev libxml-libxml-perl m4 make ncview pipenv pkg-config python3 python3-dev python3-pip python3-dateutil tcsh unzip xauth xorg time ghostscript less libbz2-dev libc6-dev libffi-dev libgdbm-dev libopenblas-dev libreadline-dev libssl-dev libtiff-dev libgeotiff-dev tk-dev vim wget

  #Fix any broken installations
  echo $PASSWD | sudo -S apt --fix-broken install

  # make sure some critical packages have been installed
  which cmake pkg-config make gcc g++ gfortran

  #Directory Listings
  export HOME=$(
    cd ~ \
      && pwd
  )
  mkdir $HOME/WRFCHEM
  export WRF_FOLDER=$HOME/WRFCHEM
  cd $HOME/WRFCHEM
  mkdir Downloads
  mkdir Libs
  mkdir Libs/grib2
  mkdir Libs/NETCDF
  mkdir "${WRF_FOLDER}"/WRF_CHEM_Tools
  mkdir "${WRF_FOLDER}"/WRF_CHEM_Tools/Libs
  mkdir "${WRF_FOLDER}"/WRF_CHEM_Tools/Libs/grib2
  mkdir "${WRF_FOLDER}"/WRF_CHEM_Tools/Libs/NETCDF
  mkdir "${WRF_FOLDER}"/WRF_CHEM_Tools/Downloads
  mkdir "${WRF_FOLDER}"/WRF_CHEM_Tools/mozbc
  mkdir "${WRF_FOLDER}"/WRF_CHEM_Tools/megan_bio_emiss
  mkdir "${WRF_FOLDER}"/WRF_CHEM_Tools/megan_bio_data
  mkdir "${WRF_FOLDER}"/WRF_CHEM_Tools/wes_coldens
  mkdir "${WRF_FOLDER}"/WRF_CHEM_Tools/ANTHRO_EMIS
  mkdir "${WRF_FOLDER}"/WRF_CHEM_Tools/EDGAR_HTAP
  mkdir "${WRF_FOLDER}"/WRF_CHEM_Tools/EPA_ANTHRO_EMIS
  mkdir "${WRF_FOLDER}"/WRF_CHEM_Tools/UBC
  mkdir "${WRF_FOLDER}"/WRF_CHEM_Tools/Aircraft
  mkdir "${WRF_FOLDER}"/WRF_CHEM_Tools/FINN
  mkdir "${WRF_FOLDER}"/WRF_CHEM_Tools/Tests
  mkdir "${WRF_FOLDER}"/WRF_CHEM_Tools/Tests/Environment
  mkdir "${WRF_FOLDER}"/WRF_CHEM_Tools/Tests/Compatibility

  ##############################Downloading Libraries############################
  cd "${WRF_FOLDER}"/WRF_CHEM_Tools/Downloads

  wget -c https://github.com/madler/zlib/releases/download/v$Zlib_Version/zlib-$Zlib_Version.tar.gz
  wget -c https://github.com/HDFGroup/hdf5/releases/download/hdf5_$HDF5_Version/hdf5-$HDF5_Version.tar.gz
  wget -c https://github.com/Unidata/netcdf-c/archive/refs/tags/v$Netcdf_C_Version.tar.gz
  wget -c https://github.com/Unidata/netcdf-fortran/archive/refs/tags/v$Netcdf_Fortran_Version.tar.gz
  wget -c https://download.sourceforge.net/libpng/libpng-$Libpng_Version.tar.gz
  wget -c https://www.ece.uvic.ca/~frodo/jasper/software/jasper-$Jasper_Version.zip
  wget -c https://github.com/pmodels/mpich/releases/download/v$Mpich_Version/mpich-$Mpich_Version.tar.gz
  wget -c https://parallel-netcdf.github.io/Release/pnetcdf-$Pnetcdf_Version.tar.gz

  #############################Core Management####################################

  export CPU_CORE=$(nproc) # number of available threads on system
  export CPU_6CORE="6"
  export CPU_QUARTER=$(($CPU_CORE / 4))                          #quarter of availble cores on system
  export CPU_QUARTER_EVEN=$(($CPU_QUARTER - ($CPU_QUARTER % 2))) #Forces CPU cores to even number to avoid partial core export. ie 7 cores would be 3.5 cores.

  if [ $CPU_CORE -le $CPU_6CORE ]; then #If statement for low core systems.  Forces computers to only use 1 core if there are 4 cores or less on the system. then
    export CPU_QUARTER_EVEN="2"
  else
    export CPU_QUARTER_EVEN=$(($CPU_QUARTER - ($CPU_QUARTER % 2)))
  fi

  echo "##########################################"
  echo "Number of Threads being used $CPU_QUARTER_EVEN"
  echo "##########################################"

  echo " "

  #############################Compilers############################
  export DIR="${WRF_FOLDER}"/WRF_CHEM_Tools/Libs
  export CC=gcc
  export CXX=g++
  export FC=gfortran
  export F77=gfortran
  export CFLAGS="-fPIC -fPIE -O3 -Wno-implicit-function-declaration -Wno-incompatible-pointer-types "

  #IF statement for GNU compiler issue
  export GCC_VERSION=$(/usr/bin/gcc -dumpfullversion | awk '{print$1}')
  export GFORTRAN_VERSION=$(/usr/bin/gfortran -dumpfullversion | awk '{print$1}')
  export GPLUSPLUS_VERSION=$(/usr/bin/g++ -dumpfullversion | awk '{print$1}')

  export GCC_VERSION_MAJOR_VERSION=$(echo $GCC_VERSION | awk -F. '{print $1}')
  export GFORTRAN_VERSION_MAJOR_VERSION=$(echo $GFORTRAN_VERSION | awk -F. '{print $1}')
  export GPLUSPLUS_VERSION_MAJOR_VERSION=$(echo $GPLUSPLUS_VERSION | awk -F. '{print $1}')

  export version_10="10"

  if [ $GCC_VERSION_MAJOR_VERSION -ge $version_10 ] || [ $GFORTRAN_VERSION_MAJOR_VERSION -ge $version_10 ] || [ $GPLUSPLUS_VERSION_MAJOR_VERSION -ge $version_10 ]; then
    export fallow_argument=-fallow-argument-mismatch
    export boz_argument=-fallow-invalid-boz
  else
    export fallow_argument=
    export boz_argument=
  fi

  export FFLAGS="$fallow_argument"
  export FCFLAGS="$fallow_argument"

  echo "##########################################"
  echo "FFLAGS = $FFLAGS"
  echo "FCFLAGS = $FCFLAGS"
  echo "CFLAGS = $CFLAGS"
  echo "##########################################"

  #############################zlib############################
  #Uncalling compilers due to comfigure issue with zlib$Zlib_Version
  #With CC & CXX definied ./configure uses different compiler Flags

  cd "${WRF_FOLDER}"/WRF_CHEM_Tools/Downloads
  env -u LD_LIBRARY_PATH tar -xzf zlib-$Zlib_Version.tar.gz
  cd zlib-$Zlib_Version/
  ./configure --prefix=$DIR/grib2 2>&1 | tee configure.log
  make -j $CPU_QUARTER_EVEN 2>&1 | tee make.log
  make -j $CPU_QUARTER_EVEN install 2>&1 | tee make.install.log

  ##############################MPICH############################
  cd "${WRF_FOLDER}"/WRF_CHEM_Tools/Downloads
  env -u LD_LIBRARY_PATH tar -xzf mpich-$Mpich_Version.tar.gz
  cd mpich-$Mpich_Version/
  F90= ./configure --prefix=$DIR/MPICH --with-device=ch3 FFLAGS=$FFLAGS FCFLAGS=$FCFLAGS 2>&1 | tee configure.log
  make -j $CPU_QUARTER_EVEN 2>&1 | tee make.log
  make -j $CPU_QUARTER_EVEN install 2>&1 | tee make.install.log

  export PATH=$DIR/MPICH/bin:$PATH

  export MPIFC=$DIR/MPICH/bin/mpifort
  export MPIF77=$DIR/MPICH/bin/mpifort
  export MPIF90=$DIR/MPICH/bin/mpifort
  export MPICC=$DIR/MPICH/bin/mpicc
  export MPICXX=$DIR/MPICH/bin/mpicxx

  echo " "

  #############################libpng############################
  cd "${WRF_FOLDER}"/WRF_CHEM_Tools/Downloads
  export LDFLAGS=-L$DIR/grib2/lib
  export CPPFLAGS=-I$DIR/grib2/include
  env -u LD_LIBRARY_PATH tar -xzf libpng-$Libpng_Version.tar.gz
  cd libpng-$Libpng_Version/
  CC=$MPICC FC=$MPIFC F77=$MPIF77 F90=$MPIF90 CXX=$MPICXX CFLAGS=$CFLAGS FFLAGS=$FFLAGS FCFLAGS=$FCFLAGS ./configure --prefix=$DIR/grib2 2>&1 | tee configure.log
  make -j $CPU_QUARTER_EVEN 2>&1 | tee make.log
  make -j $CPU_QUARTER_EVEN install 2>&1 | tee make.install.log

  #############################JasPer############################
  cd "${WRF_FOLDER}"/WRF_CHEM_Tools/Downloads
  unzip jasper-$Jasper_Version.zip
  cd jasper-$Jasper_Version/
  F77=$MPIF77 F90=$MPIF90 CXX=$MPICXX CFLAGS=$CFLAGS FFLAGS=$FFLAGS FCFLAGS=$FCFLAGS ./configure --build=aarch64-unknown-linux-gnu --host=aarch64-unknown-linux-gnu --prefix="$DIR/grib2" 2>&1 | tee configure.log
  make -j $CPU_QUARTER_EVEN 2>&1 | tee make.log
  make -j $CPU_QUARTER_EVEN install 2>&1 | tee make.install.log

  export JASPERLIB=$DIR/grib2/lib
  export JASPERINC=$DIR/grib2/include

  #############################hdf5 library for netcdf4 functionality############################
  cd "${WRF_FOLDER}"/WRF_CHEM_Tools/Downloads
  env -u LD_LIBRARY_PATH tar -xzf hdf5-$HDF5_Version.tar.gz
  cd hdf5-$HDF5_Version
  CC=$MPICC FC=$MPIFC F77=$MPIF77 F90=$MPIF90 CXX=$MPICXX CFLAGS=$CFLAGS FFLAGS=$FFLAGS FCFLAGS=$FCFLAGS ./configure --prefix=$DIR/grib2 --with-zlib=$DIR/grib2 --enable-hl --enable-fortran --enable-parallel 2>&1 | tee configure.log
  make -j $CPU_QUARTER_EVEN 2>&1 | tee make.log
  make -j $CPU_QUARTER_EVEN install 2>&1 | tee make.install.log

  export HDF5=$DIR/grib2
  export PHDF5=$DIR/grib2
  export LD_LIBRARY_PATH=$DIR/grib2/lib:$LD_LIBRARY_PATH

  echo " "

  #############################Install Parallel-netCDF##############################
  #Make file created with half of available cpu cores
  #Hard path for MPI added
  ##################################################################################
  cd "${WRF_FOLDER}"/WRF_CHEM_Tools/Downloads
  env -u LD_LIBRARY_PATH tar -xzf pnetcdf-$Pnetcdf_Version.tar.gz
  cd pnetcdf-$Pnetcdf_Version
  CC=$MPICC FC=$MPIFC F77=$MPIF77 F90=$MPIF90 CXX=$MPICXX CFLAGS=$CFLAGS FFLAGS=$FFLAGS FCFLAGS=$FCFLAGS ./configure --prefix=$DIR/grib2 --enable-shared --enable-static 2>&1 | tee configure.log
  make -j $CPU_QUARTER_EVEN 2>&1 | tee make.log
  make -j $CPU_QUARTER_EVEN install 2>&1 | tee make.install.log

  export PNETCDF=$DIR/grib2

  ##############################Install NETCDF C Library############################
  cd "${WRF_FOLDER}"/WRF_CHEM_Tools/Downloads
  env -u LD_LIBRARY_PATH tar -xzf v$Netcdf_C_Version.tar.gz
  cd netcdf-c-$Netcdf_C_Version/
  export CPPFLAGS=-I$DIR/grib2/include
  export LDFLAGS=-L$DIR/grib2/lib
  export LIBS="-lhdf5_hl -lhdf5 -lz -lcurl -lgfortran -lgcc -lm -ldl -lpnetcdf"
  CC=$MPICC FC=$MPIFC F77=$MPIF77 F90=$MPIF90 CXX=$MPICXX CFLAGS=$CFLAGS FFLAGS=$FFLAGS FCFLAGS=$FCFLAGS ./configure --prefix=$DIR/NETCDF --with-zlib=$DIR/grib2 --disable-dap --enable-netcdf-4 --enable-netcdf4 --enable-shared --enable-static --enable-pnetcdf --enable-cdf5 --enable-parallel-tests 2>&1 | tee configure.log
  make -j $CPU_QUARTER_EVEN 2>&1 | tee make.log
  make -j $CPU_QUARTER_EVEN install 2>&1 | tee make.install.log

  export PATH=$DIR/NETCDF/bin:$PATH
  export NETCDF=$DIR/NETCDF

  ##############################NetCDF fortran library############################
  cd "${WRF_FOLDER}"/WRF_CHEM_Tools/Downloads
  env -u LD_LIBRARY_PATH tar -xzf v$Netcdf_Fortran_Version.tar.gz
  cd netcdf-fortran-$Netcdf_Fortran_Version/
  export LD_LIBRARY_PATH=$DIR/NETCDF/lib:$LD_LIBRARY_PATH
  export CPPFLAGS="-I$DIR/NETCDF/include -I$DIR/grib2/include"
  export LDFLAGS="-L$DIR/NETCDF/lib -L$DIR/grib2/lib"
  export LIBS="-lnetcdf -lpnetcdf -lcurl -lhdf5_hl -lhdf5 -lz -ldl -lgcc -lgfortran"
  CC=$MPICC FC=$MPIFC F77=$MPIF77 F90=$MPIF90 CXX=$MPICXX CFLAGS=$CFLAGS FFLAGS=$FFLAGS FCFLAGS=$FCFLAGS ./configure --prefix=$DIR/NETCDF --enable-netcdf-4 --enable-netcdf4 --enable-shared --enable-static --enable-parallel-tests --enable-hdf5 2>&1 | tee configure.log
  make -j $CPU_QUARTER_EVEN 2>&1 | tee make.log
  make -j $CPU_QUARTER_EVEN install 2>&1 | tee make.install.log

  echo " "
  #################################### System Environment Tests ##############

  cd "${WRF_FOLDER}"/WRF_CHEM_Tools/Downloads
  wget -c https://www2.mmm.ucar.edu/wrf/OnLineTutorial/compile_tutorial/tar_files/Fortran_C_NETCDF_MPI_tests.tar
  wget -c https://www2.mmm.ucar.edu/wrf/OnLineTutorial/compile_tutorial/tar_files/Fortran_C_tests.tar

  env -u LD_LIBRARY_PATH tar -xvf Fortran_C_tests.tar -C "${WRF_FOLDER}"/WRF_CHEM_Tools/Tests/Environment
  env -u LD_LIBRARY_PATH tar -xvf Fortran_C_NETCDF_MPI_tests.tar -C "${WRF_FOLDER}"/WRF_CHEM_Tools/Tests/Compatibility

  export one="1"
  echo " "
  ############## Testing Environment #####

  cd "${WRF_FOLDER}"/WRF_CHEM_Tools/Tests/Environment

  cp ${NETCDF}/include/netcdf.inc .

  echo " "
  echo " "
  echo "Environment Testing "
  echo "Test 1"
  $FC TEST_1_fortran_only_fixed.f
  ./a.out | tee env_test1.txt
  export TEST_PASS=$(grep -w -o -c "SUCCESS" env_test1.txt | awk '{print$1}')
  if [ $TEST_PASS -ge 1 ]; then
    echo "Enviroment Test 1 Passed"
  else
    echo "Environment Compiler Test 1 Failed"
    exit
  fi
  read -r -t 3 -p "I am going to wait for 3 seconds only ..."

  echo " "
  echo "Test 2"
  $FC TEST_2_fortran_only_free.f90
  ./a.out | tee env_test2.txt
  export TEST_PASS=$(grep -w -o -c "SUCCESS" env_test2.txt | awk '{print$1}')
  if [ $TEST_PASS -ge 1 ]; then
    echo "Enviroment Test 2 Passed"
  else
    echo "Environment Compiler Test 2 Failed"
    exit
  fi
  echo " "
  read -r -t 3 -p "I am going to wait for 3 seconds only ..."

  echo " "
  echo "Test 3"
  $CC TEST_3_c_only.c
  ./a.out | tee env_test3.txt
  export TEST_PASS=$(grep -w -o -c "SUCCESS" env_test3.txt | awk '{print$1}')
  if [ $TEST_PASS -ge 1 ]; then
    echo "Enviroment Test 3 Passed"
  else
    echo "Environment Compiler Test 3 Failed"
    exit
  fi
  echo " "
  read -r -t 3 -p "I am going to wait for 3 seconds only ..."

  echo " "
  echo "Test 4"
  $CC -c -m64 TEST_4_fortran+c_c.c
  $FC -c -m64 TEST_4_fortran+c_f.f90
  $FC -m64 TEST_4_fortran+c_f.o TEST_4_fortran+c_c.o
  ./a.out | tee env_test4.txt
  export TEST_PASS=$(grep -w -o -c "SUCCESS" env_test4.txt | awk '{print$1}')
  if [ $TEST_PASS -ge 1 ]; then
    echo "Enviroment Test 4 Passed"
  else
    echo "Environment Compiler Test 4 Failed"
    exit
  fi
  echo " "
  read -r -t 3 -p "I am going to wait for 3 seconds only ..."

  echo " "
  ############## Testing Environment #####

  cd "${WRF_FOLDER}"/WRF_CHEM_Tools/Tests/Compatibility

  cp ${NETCDF}/include/netcdf.inc .

  echo " "
  echo " "
  echo "Library Compatibility Tests "
  echo "Test 1"
  $FC -c 01_fortran+c+netcdf_f.f
  $CC -c 01_fortran+c+netcdf_c.c
  $FC 01_fortran+c+netcdf_f.o 01_fortran+c+netcdf_c.o \
    -L${NETCDF}/lib -lnetcdff -lnetcdf

  ./a.out | tee comp_test1.txt
  export TEST_PASS=$(grep -w -o -c "SUCCESS" comp_test1.txt | awk '{print$1}')
  if [ $TEST_PASS -ge 1 ]; then
    echo "Compatibility Test 1 Passed"
  else
    echo "Compatibility Compiler Test 1 Failed"
    exit
  fi
  echo " "
  read -r -t 3 -p "I am going to wait for 3 seconds only ..."

  echo " "

  echo "Test 2"
  $MPIFC -c 02_fortran+c+netcdf+mpi_f.f
  $MPICC -c 02_fortran+c+netcdf+mpi_c.c
  $MPIFC 02_fortran+c+netcdf+mpi_f.o \
    02_fortran+c+netcdf+mpi_c.o \
    -L${NETCDF}/lib -lnetcdff -lnetcdf

  $DIR/MPICH/bin/mpirun ./a.out | tee comp_test2.txt
  export TEST_PASS=$(grep -w -o -c "SUCCESS" comp_test2.txt | awk '{print$1}')
  if [ $TEST_PASS -ge 1 ]; then
    echo "Compatibility Test 2 Passed"
  else
    echo "Compatibility Compiler Test 2 Failed"
    exit
  fi
  echo " "
  read -r -t 3 -p "I am going to wait for 3 seconds only ..."
  echo " "

  echo " All tests completed and passed"
  echo " "
  # Downloading WRF-CHEM Tools and untarring files
  cd "${WRF_FOLDER}"/WRF_CHEM_Tools/Downloads

  wget -c https://www.acom.ucar.edu/wrf-chem/mozbc.tar
  wget -c https://www.acom.ucar.edu/wrf-chem/UBC_inputs.tar
  wget -c https://www.acom.ucar.edu//wrf-chem/megan_bio_emiss.tar
  wget -c https://www.acom.ucar.edu/wrf-chem/megan.data.tar.gz
  wget -c https://www.acom.ucar.edu/wrf-chem/wes-coldens.tar
  wget -c https://www.acom.ucar.edu/wrf-chem/ANTHRO.tar
  wget -c https://www.acom.ucar.edu/webt/wrf-chem/processors/EDGAR-HTAP.tgz
  wget -c https://www.acom.ucar.edu/wrf-chem/EPA_ANTHRO_EMIS.tgz
  wget -c https://www2.acom.ucar.edu/sites/default/files/documents/aircraft_preprocessor_files.tar
  # Downloading FINN
  wget -c https://www.acom.ucar.edu/Data/fire/data/finn2/FINNv2.4_MOD_MOZART_2020_c20210617.txt.gz
  wget -c https://www.acom.ucar.edu/Data/fire/data/finn2/FINNv2.4_MOD_MOZART_2013_c20210617.txt.gz
  wget -c https://www.acom.ucar.edu/Data/fire/data/finn2/FINNv2.4_MODVRS_MOZART_2019_c20210615.txt.gz
  wget -c https://www.acom.ucar.edu/Data/fire/data/fire_emis.tgz
  wget -c https://www.acom.ucar.edu/Data/fire/data/fire_emis_input.tar
  wget -c https://www.acom.ucar.edu/Data/fire/data/TrashEmis.zip

  echo ""
  echo "Unpacking Mozbc."
  env -u LD_LIBRARY_PATH tar -xvf mozbc.tar -C "${WRF_FOLDER}"/WRF_CHEM_Tools/mozbc
  echo ""
  echo "Unpacking MEGAN Bio Emission."
  env -u LD_LIBRARY_PATH tar -xvf megan_bio_emiss.tar -C "${WRF_FOLDER}"/WRF_CHEM_Tools/megan_bio_emiss
  echo ""
  echo "Unpacking MEGAN Bio Emission Data."
  env -u LD_LIBRARY_PATH tar -xzf megan.data.tar.gz -C "${WRF_FOLDER}"/WRF_CHEM_Tools/megan_bio_data
  echo ""
  echo "Unpacking Wes Coldens"
  env -u LD_LIBRARY_PATH tar -xvf wes-coldens.tar -C "${WRF_FOLDER}"/WRF_CHEM_Tools/wes_coldens
  echo ""
  echo "Unpacking Unpacking ANTHRO Emission."
  env -u LD_LIBRARY_PATH tar -xvf ANTHRO.tar -C "${WRF_FOLDER}"/WRF_CHEM_Tools/ANTHRO_EMIS
  echo ""
  echo "Unpacking EDGAR-HTAP."
  env -u LD_LIBRARY_PATH tar -xzf EDGAR-HTAP.tgz -C "${WRF_FOLDER}"/WRF_CHEM_Tools/EDGAR_HTAP
  echo ""
  echo "Unpacking EPA ANTHRO Emission."
  env -u LD_LIBRARY_PATH tar -xzf EPA_ANTHRO_EMIS.tgz -C "${WRF_FOLDER}"/WRF_CHEM_Tools/EPA_ANTHRO_EMIS
  echo ""
  echo "Unpacking Upper Boundary Conditions."
  env -u LD_LIBRARY_PATH tar -xvf UBC_inputs.tar -C "${WRF_FOLDER}"/WRF_CHEM_Tools/UBC
  echo ""
  echo "Unpacking Aircraft Preprocessor Files."
  echo ""
  env -u LD_LIBRARY_PATH tar -xvf aircraft_preprocessor_files.tar -C "${WRF_FOLDER}"/WRF_CHEM_Tools/Aircraft
  echo ""
  echo "Unpacking Fire INventory from NCAR (FINN)"
  env -u LD_LIBRARY_PATH tar -xzf fire_emis.tgz -C "${WRF_FOLDER}"/WRF_CHEM_Tools/FINN
  env -u LD_LIBRARY_PATH tar -xvf fire_emis_input.tar
  env -u LD_LIBRARY_PATH tar -xzf grass_from_img.nc.tgz -C "${WRF_FOLDER}"/WRF_CHEM_Tools/FINN/grid_finn_fire_emis_v2020/src
  env -u LD_LIBRARY_PATH tar -xzf tempfor_from_img.nc.tgz -C "${WRF_FOLDER}"/WRF_CHEM_Tools/FINN/grid_finn_fire_emis_v2020/src
  env -u LD_LIBRARY_PATH tar -xzf shrub_from_img.nc.tgz -C "${WRF_FOLDER}"/WRF_CHEM_Tools/FINN/grid_finn_fire_emis_v2020/src
  env -u LD_LIBRARY_PATH tar -xzf tropfor_from_img.nc.tgz -C "${WRF_FOLDER}"/WRF_CHEM_Tools/FINN/grid_finn_fire_emis_v2020/src

  mv "${WRF_FOLDER}"/WRF_CHEM_Tools/Downloads/FINNv2.4_MOD_MOZART_2020_c20210617.txt.gz "${WRF_FOLDER}"/WRF_CHEM_Tools/FINN
  mv "${WRF_FOLDER}"/WRF_CHEM_Tools/Downloads/FINNv2.4_MOD_MOZART_2013_c20210617.txt.gz "${WRF_FOLDER}"/WRF_CHEM_Tools/FINN
  mv "${WRF_FOLDER}"/WRF_CHEM_Tools/Downloads/FINNv2.4_MODVRS_MOZART_2019_c20210615.txt.gz "${WRF_FOLDER}"/WRF_CHEM_Tools/FINN

  unzip TrashEmis.zip
  mv "${WRF_FOLDER}"/WRF_CHEM_Tools/Downloads/ALL_Emiss_04282014.nc "${WRF_FOLDER}"/WRF_CHEM_Tools/FINN/grid_finn_fire_emis_v2020/src

  cd "${WRF_FOLDER}"/WRF_CHEM_Tools/FINN

  gunzip FINNv2.4_MOD_MOZART_2020_c20210617.txt.gz
  gunzip FINNv2.4_MOD_MOZART_2013_c20210617.txt.gz
  gunzip FINNv2.4_MODVRS_MOZART_2019_c20210615.txt.gz
  ############################Installation of Mozbc #############################
  # Recalling variables from install script to make sure the path is right

  cd "${WRF_FOLDER}"/WRF_CHEM_Tools/mozbc
  chmod +x make_mozbc
  export DIR="${WRF_FOLDER}"/WRF_CHEM_Tools/Libs
  export FC=gfortran
  export NETCDF_DIR=$DIR/NETCDF
  sed -i 's/"${ar_libs} -lnetcdff"/"-lnetcdff ${ar_libs}"/' make_mozbc
  sed -i '8s/FFLAGS = --g/FFLAGS = --g ${fallow_argument}/' Makefile
  sed -i '10s/FFLAGS = -g/FFLAGS = -g ${fallow_argument}/' Makefile
  ./make_mozbc 2>&1 | tee make.log

  ################## Information on Upper Boundary Conditions ###################

  cd "${WRF_FOLDER}"/WRF_CHEM_Tools/UBC/
  wget -c https://www2.acom.ucar.edu/sites/default/files/documents/8A_2_Barth_WRFWorkshop_11.pdf

  ########################## MEGAN Bio Emission #################################
  # Data for MEGAN Bio Emission located in
  # "${WRF_FOLDER}"/WRF_CHEM_Tools/megan_bio_data

  cd "${WRF_FOLDER}"/WRF_CHEM_Tools/megan_bio_emiss
  chmod +x make_util
  export DIR="${WRF_FOLDER}"/WRF_CHEM_Tools/Libs
  export FC=gfortran
  export NETCDF_DIR=$DIR/NETCDF
  sed -i 's/"${ar_libs} -lnetcdff"/"-lnetcdff ${ar_libs}"/' make_util
  sed -i '8s/FFLAGS = --g/FFLAGS = --g ${fallow_argument}/' Makefile
  sed -i '10s/FFLAGS = -g/FFLAGS = -g ${fallow_argument}/' Makefile
  ./make_util megan_bio_emiss 2>&1 | tee make.bio.log
  ./make_util megan_xform 2>&1 | tee make.xform.log
  ./make_util surfdata_xform 2>&1 | tee make.surfdata.log

  ############################# Anthroprogenic Emissions #########################

  cd "${WRF_FOLDER}"/WRF_CHEM_Tools/ANTHRO_EMIS/ANTHRO/src
  chmod +x make_anthro
  export DIR="${WRF_FOLDER}"/WRF_CHEM_Tools/Libs
  export FC=gfortran
  export NETCDF_DIR=$DIR/NETCDF
  sed -i 's/"${ar_libs} -lnetcdff"/"-lnetcdff ${ar_libs}"/' make_anthro
  sed -i '8s/FFLAGS = --g/FFLAGS = --g ${fallow_argument}/' Makefile
  sed -i '10s/FFLAGS = -g/FFLAGS = -g ${fallow_argument}/' Makefile
  ./make_anthro 2>&1 | tee make.log

  ############################# EDGAR HTAP ######################################
  #  This directory contains EDGAR-HTAP anthropogenic emission files for the
  #  year 2010.  The files are in the MOZCART and MOZART-MOSAIC sub-directories.
  #  The MOZCART files are intended to be used for the WRF MOZCART_KPP chemical
  #  option.  The MOZART-MOSAIC files are intended to be used with the following
  #  WRF chemical options (See read -rme in Folder

  ######################### EPA Anthroprogenic Emissions ########################
  cd "${WRF_FOLDER}"/WRF_CHEM_Tools/EPA_ANTHRO_EMIS/src
  chmod +x make_anthro
  export DIR="${WRF_FOLDER}"/WRF_CHEM_Tools/Libs
  export FC=gfortran
  export NETCDF_DIR=$DIR/NETCDF
  sed -i 's/"${ar_libs} -lnetcdff"/"-lnetcdff ${ar_libs}"/' make_anthro
  sed -i '8s/FFLAGS = --g/FFLAGS = --g ${fallow_argument}/' Makefile
  sed -i '10s/FFLAGS = -g/FFLAGS = -g ${fallow_argument}/' Makefile
  ./make_anthro 2>&1 | tee make.log

  ######################### Weseley EXO Coldens ##################################
  cd "${WRF_FOLDER}"/WRF_CHEM_Tools/wes_coldens
  chmod +x make_util
  export DIR="${WRF_FOLDER}"/WRF_CHEM_Tools/Libs
  export FC=gfortran
  export NETCDF_DIR=$DIR/NETCDF
  sed -i 's/"${ar_libs} -lnetcdff"/"-lnetcdff ${ar_libs}"/' make_util
  sed -i '8s/FFLAGS = --g/FFLAGS = --g ${fallow_argument}/' Makefile
  sed -i '10s/FFLAGS = -g/FFLAGS = -g ${fallow_argument}/' Makefile
  ./make_util wesely 2>&1 | tee make.wesely.log
  ./make_util exo_coldens 2>&1 | tee make.exo.log

  ########################## Aircraft Emissions Preprocessor #####################
  # This is an IDL based preprocessor to create WRF-Chem read -ry aircraft emissions files
  # (wrfchemaircraft_) from a global inventory in netcdf format. Please consult the read -rME file
  # for how to use the preprocessor. The emissions inventory is not included, so the user must
  # provide their own.
  echo " "
  echo "######################################################################"
  echo " Please see script for details about Aircraft Emissions Preprocessor"
  echo "######################################################################"
  echo " "

  ######################## Fire INventory from NCAR (FINN) ###########################
  # Fire INventory from NCAR (FINN): A daily fire emissions product for atmospheric chemistry models
  # https://www2.acom.ucar.edu/modeling/finn-fire-inventory-ncar
  echo " "
  echo "###########################################"
  echo " Please see folder for details about FINN."
  echo "###########################################"
  echo " "

  ######################################### PREP-CHEM-SRC ##############################################
  # PREP-CHEM-SRC is a pollutant emissions numerical too developed at CPTEC/INPE
  # whose function is to create data of atmospheric pollutant emissions from biomass burning,
  # photosynthesis or other forest transformation processes, combustion of oil-based products
  # by vehicles or industry, charcoal production, and many other processes.
  # The system is maintained and developed at CPTEC/INPE by the GMAI group, which not
  # only updates versions of data such as EDGAR, RETRO, MEGAN, etc., but also
  # implements new functionalities such as volcanic emissions which is present now in this
  # version.
  # The purpose of this guide is to present how to install, compile and run the pre-processor.
  # Finally, the steps for utilizing the emissions data in the CCATT-BRAMS, WRF-Chem and
  # FIM-Chem models are presented.
  # We recommend that you read -r the article “PREP-CHEM-SRC – 1.0: a preprocessor of
  # trace gas and aerosol emission fields for regional and global atmospheric chemistry
  # models” (Freitas et al., 2010 - http://www.geosci-model-dev.net/4/419/2011/gmd-4-419-
  # 2011.pdf).
  # Email: mailto:atende.cptec@inpe.br
  # WEB: http://brams.cptec.inpe.br
  # http:// meioambiente.cptec.inpe.br
  # Prep-Chem-Src v1.5.0 (note v1.8.3 is in Beta still)
  #########################################################################################################

  # Downloading PREP-CHEM-SRC-1.5 and untarring files
  mkdir "${WRF_FOLDER}"/WRF_CHEM_Tools/PREP-CHEM-SRC-1.5

  cd "${WRF_FOLDER}"/WRF_CHEM_Tools/Downloads

  wget -c http://ftp.cptec.inpe.br/pesquisa/bramsrd/BRAMS_5.4/PREP-CHEM/PREP-CHEM-SRC-1.5.tar.gz

  env -u LD_LIBRARY_PATH tar -xzf PREP-CHEM-SRC-1.5.tar.gz -C "${WRF_FOLDER}"/WRF_CHEM_Tools/PREP-CHEM-SRC-1.5

  cd "${WRF_FOLDER}"/WRF_CHEM_Tools/PREP-CHEM-SRC-1.5

  # Installation of PREP-CHEM-SRC-1.5

  cd "${WRF_FOLDER}"/WRF_CHEM_Tools/PREP-CHEM-SRC-1.5/bin/build

  sed -i '47s|/scratchin/grupos/catt-brams/shared/libs/gfortran/netcdf-4.1.3|${DIR}/NETCDF|' include.mk.gfortran.wrf          #Changing NETDCF Location
  sed -i '53s|/scratchin/grupos/catt-brams/shared/libs/gfortran/hdf5-1.8.13-serial|${DIR}/grib2|' include.mk.gfortran.wrf     #Changing HDF5 Location
  sed -i '55s|-L/scratchin/grupos/catt-brams/shared/libs/gfortran/zlib-1.2.8/lib|-L${DIR}/grib2/lib|' include.mk.gfortran.wrf #Changing zlib Location
  sed -i '69s|-frecord-marker=4|-frecord-marker=4 ${fallow_argument}|' include.mk.gfortran.wrf                                #Changing adding fallow argument mismatch to fix dummy error

  make OPT=gfortran.wrf CHEM=RADM_WRF_FIM AER=SIMPLE 2>&1 | tee make.log # Compiling and making of PRE-CHEM-SRC-1.5

  # IF statement to check that all files were created.
  cd "${WRF_FOLDER}"/WRF_CHEM_Tools/PREP-CHEM-SRC-1.5/bin
  n=$(ls ./*.exe | wc -l)
  if (($n >= 2)); then
    echo "All expected files created."
    read -r -t 5 -p "Finished installing WRF-CHEM-PREP. I am going to wait for 5 seconds only ..."
  else
    echo "Missing one or more expected files. Exiting the script."
    read -r -p "Please contact script authors for assistance, press 'Enter' to exit script."
    exit
  fi
  echo " "

  #####################################BASH Script Finished##############################
  echo " "
  echo "WRF CHEM Tools & PREP_CHEM_SRC compiled with latest version of NETCDF files available on 03/01/2025"
  echo "If error occurs using WRFCHEM tools please update your NETCDF libraries or reconfigure with older libraries"
  echo "This is a WRC Chem Community tool made by a private user and is not supported by UCAR/NCAR"
  read -r -t 5 -p "BASH Script Finished"

fi

if [ "$Ubuntu_64bit_Intel" = "1" ]; then

  echo $PASSWD | sudo -S apt -y update
  echo $PASSWD | sudo -S apt -y upgrade

  # download the key to system keyring; this and the following echo command are
  # needed in order to install the Intel compilers
  wget -O- https://apt.repos.intel.com/intel-gpg-keys/GPG-PUB-KEY-INTEL-SW-PRODUCTS.PUB \
    | gpg --dearmor | sudo tee /usr/share/keyrings/oneapi-archive-keyring.gpg > /dev/null

  # add signed entry to apt sources and configure the APT client to use Intel repository:
  echo "deb [signed-by=/usr/share/keyrings/oneapi-archive-keyring.gpg] https://apt.repos.intel.com/oneapi all main" | sudo tee /etc/apt/sources.list.d/oneAPI.list

  # this update should get the Intel package info from the Intel repository
  echo $PASSWD | sudo -S apt -y update

  # Basic Package Management for WRF-CHEM Tools and Processors

  echo $PASSWD | sudo -S apt -y update
  echo $PASSWD | sudo -S apt -y upgrade
  release_version=$(lsb_release -r -s)

  # Compare the release version
  if [ "$release_version" = "24.04" ]; then
    # Install Emacs without recommended packages
    echo $PASSWD | sudo -S apt install emacs --no-install-recommends -y
  else
    # Attempt to install Emacs if the release version is not 24.04
    echo "The release version is not 24.04, attempting to install Emacs."
    echo $PASSWD | sudo -S apt install emacs -y
  fi

  echo "$PASSWD" | sudo -S apt -y install bison build-essential byacc cmake csh curl default-jdk default-jre flex libfl-dev g++ gawk gcc gettext gfortran git ksh libcurl4-gnutls-dev libjpeg-dev libncurses6 libncursesw5-dev libpixman-1-dev libpng-dev libtool libxml2 libxml2-dev libxml-libxml-perl m4 make ncview pipenv pkg-config python3 python3-dev python3-pip python3-dateutil tcsh unzip xauth xorg time ghostscript less libbz2-dev libc6-dev libffi-dev libgdbm-dev libopenblas-dev libreadline-dev libssl-dev libtiff-dev libgeotiff-dev tk-dev vim wget

  # install the Intel compilers
  echo $PASSWD | sudo -S apt -y install intel-basekit
  echo $PASSWD | sudo -S apt -y install intel-hpckit
  echo $PASSWD | sudo -S apt -y install intel-oneapi-python

  echo $PASSWD | sudo -S apt -y update
  echo $PASSWD | sudo -S apt -y upgrade

  #Fix any broken installations
  echo $PASSWD | sudo -S apt --fix-broken install

  # make sure some critical packages have been installed
  which cmake pkg-config make gcc g++ gfortran

  # add the Intel compiler file paths to various environment variables
  source /opt/intel/oneapi/setvars.sh --force

  # some of the libraries we install below need one or more of these variables
  # some of the libraries we install below need one or more of these variables
  export CC=icx
  export CXX=icpx
  export FC=ifx
  export F77=ifx
  export F90=ifx
  export MPIFC=mpiifx
  export MPIF77=mpiifx
  export MPIF90=mpiifx
  export MPICC=mpiicx
  export MPICXX=mpiicpx
  export CFLAGS="-fPIC -fPIE -O3 -Wno-implicit-function-declaration -Wno-incompatible-pointer-types "
  export FFLAGS="-m64"
  export FCFLAGS="-m64"

  #Directory Listings
  export HOME=$(
    cd ~ \
      && pwd
  )
  mkdir $HOME/WRFCHEM_Intel
  export WRF_FOLDER=$HOME/WRFCHEM_Intel
  cd $HOME/WRFCHEM_Intel
  mkdir Downloads
  mkdir Libs
  mkdir Libs/grib2
  mkdir Libs/NETCDF
  mkdir "${WRF_FOLDER}"/WRF_CHEM_Tools
  mkdir "${WRF_FOLDER}"/WRF_CHEM_Tools/Libs
  mkdir "${WRF_FOLDER}"/WRF_CHEM_Tools/Libs/grib2
  mkdir "${WRF_FOLDER}"/WRF_CHEM_Tools/Libs/NETCDF
  mkdir "${WRF_FOLDER}"/WRF_CHEM_Tools/Downloads
  mkdir "${WRF_FOLDER}"/WRF_CHEM_Tools/mozbc
  mkdir "${WRF_FOLDER}"/WRF_CHEM_Tools/megan_bio_emiss
  mkdir "${WRF_FOLDER}"/WRF_CHEM_Tools/megan_bio_data
  mkdir "${WRF_FOLDER}"/WRF_CHEM_Tools/wes_coldens
  mkdir "${WRF_FOLDER}"/WRF_CHEM_Tools/ANTHRO_EMIS
  mkdir "${WRF_FOLDER}"/WRF_CHEM_Tools/EDGAR_HTAP
  mkdir "${WRF_FOLDER}"/WRF_CHEM_Tools/EPA_ANTHRO_EMIS
  mkdir "${WRF_FOLDER}"/WRF_CHEM_Tools/UBC
  mkdir "${WRF_FOLDER}"/WRF_CHEM_Tools/Aircraft
  mkdir "${WRF_FOLDER}"/WRF_CHEM_Tools/FINN
  mkdir "${WRF_FOLDER}"/WRF_CHEM_Tools/Tests
  mkdir "${WRF_FOLDER}"/WRF_CHEM_Tools/Tests/Environment
  mkdir "${WRF_FOLDER}"/WRF_CHEM_Tools/Tests/Compatibility

  export DIR="${WRF_FOLDER}"/WRF_CHEM_Tools/Libs

  ##############################Downloading Libraries############################
  cd "${WRF_FOLDER}"/WRF_CHEM_Tools/Downloads

  wget -c https://github.com/madler/zlib/releases/download/v$Zlib_Version/zlib-$Zlib_Version.tar.gz
  wget -c https://github.com/HDFGroup/hdf5/releases/download/hdf5_$HDF5_Version/hdf5-$HDF5_Version.tar.gz
  wget -c https://github.com/Unidata/netcdf-c/archive/refs/tags/v$Netcdf_C_Version.tar.gz
  wget -c https://github.com/Unidata/netcdf-fortran/archive/refs/tags/v$Netcdf_Fortran_Version.tar.gz
  wget -c https://download.sourceforge.net/libpng/libpng-$Libpng_Version.tar.gz
  wget -c https://www.ece.uvic.ca/~frodo/jasper/software/jasper-$Jasper_Version.zip
  wget -c https://parallel-netcdf.github.io/Release/pnetcdf-$Pnetcdf_Version.tar.gz

  #############################Core Management####################################

  export CPU_CORE=$(nproc) # number of available threads on system
  export CPU_6CORE="6"
  export CPU_QUARTER=$(($CPU_CORE / 4))                          #quarter of availble cores on system
  export CPU_QUARTER_EVEN=$(($CPU_QUARTER - ($CPU_QUARTER % 2))) #Forces CPU cores to even number to avoid partial core export. ie 7 cores would be 3.5 cores.

  if [ $CPU_CORE -le $CPU_6CORE ]; then #If statement for low core systems.  Forces computers to only use 1 core if there are 4 cores or less on the system. then
    export CPU_QUARTER_EVEN="2"
  else
    export CPU_QUARTER_EVEN=$(($CPU_QUARTER - ($CPU_QUARTER % 2)))
  fi

  echo "##########################################"
  echo "Number of Threads being used $CPU_QUARTER_EVEN"
  echo "##########################################"

  echo " "

  #############################Compilers############################

  #############################zlib############################
  #Uncalling compilers due to comfigure issue with zlib$Zlib_Version
  #With CC & CXX definied ./configure uses different compiler Flags

  cd "${WRF_FOLDER}"/WRF_CHEM_Tools/Downloads
  env -u LD_LIBRARY_PATH tar -xzf zlib-$Zlib_Version.tar.gz
  cd zlib-$Zlib_Version/
  ./configure --prefix=$DIR/grib2 2>&1 | tee configure.log
  make -j $CPU_QUARTER_EVEN 2>&1 | tee make.log
  make -j $CPU_QUARTER_EVEN install 2>&1 | tee make.install.log

  #############################libpng############################
  cd "${WRF_FOLDER}"/WRF_CHEM_Tools/Downloads
  export LDFLAGS=-L$DIR/grib2/lib
  export CPPFLAGS=-I$DIR/grib2/include
  env -u LD_LIBRARY_PATH tar -xzf libpng-$Libpng_Version.tar.gz
  cd libpng-$Libpng_Version/
  CC=$MPICC FC=$MPIFC F77=$MPIF77 F90=$MPIF90 CXX=$MPICXX CFLAGS=$CFLAGS FFLAGS=$FFLAGS FCFLAGS=$FCFLAGS ./configure --prefix=$DIR/grib2 2>&1 | tee configure.log
  make -j $CPU_QUARTER_EVEN 2>&1 | tee make.log
  make -j $CPU_QUARTER_EVEN install 2>&1 | tee make.install.log

  #############################JasPer############################
  cd "${WRF_FOLDER}"/WRF_CHEM_Tools/Downloads
  unzip jasper-$Jasper_Version.zip
  cd jasper-$Jasper_Version/
  CC=$MPICC FC=$MPIFC F77=$MPIF77 F90=$MPIF90 CXX=$MPICXX CFLAGS=$CFLAGS FFLAGS=$FFLAGS FCFLAGS=$FCFLAGS ./configure --prefix=$DIR/grib2 2>&1 | tee configure.log
  make -j $CPU_QUARTER_EVEN 2>&1 | tee make.log
  make -j $CPU_QUARTER_EVEN install 2>&1 | tee make.install.log

  export JASPERLIB=$DIR/grib2/lib
  export JASPERINC=$DIR/grib2/include

  #############################hdf5 library for netcdf4 functionality############################
  cd "${WRF_FOLDER}"/WRF_CHEM_Tools/Downloads
  env -u LD_LIBRARY_PATH tar -xzf hdf5-$HDF5_Version.tar.gz
  cd hdf5-$HDF5_Version
  CC=$MPICC FC=$MPIFC F77=$MPIF77 F90=$MPIF90 CXX=$MPICXX CFLAGS=$CFLAGS FFLAGS=$FFLAGS FCFLAGS=$FCFLAGS ./configure --prefix=$DIR/grib2 --with-zlib=$DIR/grib2 --enable-hl --enable-fortran --enable-parallel 2>&1 | tee configure.log
  make -j $CPU_QUARTER_EVEN 2>&1 | tee make.log
  make -j $CPU_QUARTER_EVEN install 2>&1 | tee make.install.log

  export HDF5=$DIR/grib2
  export PHDF5=$DIR/grib2
  export LD_LIBRARY_PATH=$DIR/grib2/lib:$LD_LIBRARY_PATH

  echo " "

  #############################Install Parallel-netCDF##############################
  #Make file created with half of available cpu cores
  #Hard path for MPI added
  ##################################################################################
  cd "${WRF_FOLDER}"/WRF_CHEM_Tools/Downloads
  env -u LD_LIBRARY_PATH tar -xzf pnetcdf-$Pnetcdf_Version.tar.gz
  cd pnetcdf-$Pnetcdf_Version
  CC=$MPICC FC=$MPIFC F77=$MPIF77 F90=$MPIF90 CXX=$MPICXX CFLAGS=$CFLAGS FFLAGS=$FFLAGS FCFLAGS=$FCFLAGS ./configure --prefix=$DIR/grib2 --enable-shared --enable-static 2>&1 | tee configure.log
  make -j $CPU_QUARTER_EVEN 2>&1 | tee make.log
  make -j $CPU_QUARTER_EVEN install 2>&1 | tee make.install.log

  export PNETCDF=$DIR/grib2

  ##############################Install NETCDF C Library############################
  cd "${WRF_FOLDER}"/WRF_CHEM_Tools/Downloads
  env -u LD_LIBRARY_PATH tar -xzf v$Netcdf_C_Version.tar.gz
  cd netcdf-c-$Netcdf_C_Version/
  export CPPFLAGS=-I$DIR/grib2/include
  export LDFLAGS=-L$DIR/grib2/lib
  export LIBS="-lhdf5_hl -lhdf5 -lz -lcurl -lgcc -lm -ldl -lpnetcdf"
  CC=$MPICC FC=$MPIFC F77=$MPIF77 F90=$MPIF90 CXX=$MPICXX CFLAGS=$CFLAGS FFLAGS=$FFLAGS FCFLAGS=$FCFLAGS ./configure --prefix=$DIR/NETCDF --with-zlib=$DIR/grib2 --disable-dap --enable-netcdf-4 --enable-netcdf4 --enable-shared --enable-static --enable-pnetcdf --enable-cdf5 --enable-parallel-tests 2>&1 | tee configure.log
  make -j $CPU_QUARTER_EVEN 2>&1 | tee make.log
  make -j $CPU_QUARTER_EVEN install 2>&1 | tee make.install.log

  export PATH=$DIR/NETCDF/bin:$PATH
  export NETCDF=$DIR/NETCDF

  ##############################NetCDF fortran library############################
  cd "${WRF_FOLDER}"/WRF_CHEM_Tools/Downloads
  env -u LD_LIBRARY_PATH tar -xzf v$Netcdf_Fortran_Version.tar.gz
  cd netcdf-fortran-$Netcdf_Fortran_Version/
  export LD_LIBRARY_PATH=$DIR/NETCDF/lib:$LD_LIBRARY_PATH
  export CPPFLAGS="-I$DIR/NETCDF/include -I$DIR/grib2/include"
  export LDFLAGS="-L$DIR/NETCDF/lib -L$DIR/grib2/lib"
  export LIBS="-lnetcdf -lpnetcdf -lcurl -lhdf5_hl -lhdf5 -lz -lm -ldl -lgcc"
  CC=$MPICC FC=$MPIFC F77=$MPIF77 F90=$MPIF90 CXX=$MPICXX CFLAGS=$CFLAGS FFLAGS=$FFLAGS FCFLAGS=$FCFLAGS ./configure --prefix=$DIR/NETCDF --enable-netcdf-4 --enable-netcdf4 --enable-shared --enable-static --enable-parallel-tests --enable-hdf5 2>&1 | tee configure.log
  make -j $CPU_QUARTER_EVEN 2>&1 | tee make.log
  make -j $CPU_QUARTER_EVEN install 2>&1 | tee make.install.log

  echo " "
  #################################### System Environment Tests ##############

  cd "${WRF_FOLDER}"/WRF_CHEM_Tools/Downloads
  wget -c https://www2.mmm.ucar.edu/wrf/OnLineTutorial/compile_tutorial/tar_files/Fortran_C_NETCDF_MPI_tests.tar
  wget -c https://www2.mmm.ucar.edu/wrf/OnLineTutorial/compile_tutorial/tar_files/Fortran_C_tests.tar

  env -u LD_LIBRARY_PATH tar -xvf Fortran_C_tests.tar -C "${WRF_FOLDER}"/WRF_CHEM_Tools/Tests/Environment
  env -u LD_LIBRARY_PATH tar -xvf Fortran_C_NETCDF_MPI_tests.tar -C "${WRF_FOLDER}"/WRF_CHEM_Tools/Tests/Compatibility

  export one="1"
  echo " "
  ############## Testing Environment #####

  cd "${WRF_FOLDER}"/WRF_CHEM_Tools/Tests/Environment

  cp ${NETCDF}/include/netcdf.inc .

  echo " "
  echo " "
  echo "Environment Testing "
  echo "Test 1"
  $FC TEST_1_fortran_only_fixed.f
  ./a.out | tee env_test1.txt
  export TEST_PASS=$(grep -w -o -c "SUCCESS" env_test1.txt | awk '{print$1}')
  if [ $TEST_PASS -ge 1 ]; then
    echo "Enviroment Test 1 Passed"
  else
    echo "Environment Compiler Test 1 Failed"
    exit
  fi
  read -r -t 3 -p "I am going to wait for 3 seconds only ..."

  echo " "
  echo "Test 2"
  $FC TEST_2_fortran_only_free.f90
  ./a.out | tee env_test2.txt
  export TEST_PASS=$(grep -w -o -c "SUCCESS" env_test2.txt | awk '{print$1}')
  if [ $TEST_PASS -ge 1 ]; then
    echo "Enviroment Test 2 Passed"
  else
    echo "Environment Compiler Test 2 Failed"
    exit
  fi
  echo " "
  read -r -t 3 -p "I am going to wait for 3 seconds only ..."

  echo " "
  echo "Test 3"
  $CC TEST_3_c_only.c
  ./a.out | tee env_test3.txt
  export TEST_PASS=$(grep -w -o -c "SUCCESS" env_test3.txt | awk '{print$1}')
  if [ $TEST_PASS -ge 1 ]; then
    echo "Enviroment Test 3 Passed"
  else
    echo "Environment Compiler Test 3 Failed"
    exit
  fi
  echo " "
  read -r -t 3 -p "I am going to wait for 3 seconds only ..."

  echo " "
  echo "Test 4"
  $CC -c -m64 TEST_4_fortran+c_c.c
  $FC -c -m64 TEST_4_fortran+c_f.f90
  $FC -m64 TEST_4_fortran+c_f.o TEST_4_fortran+c_c.o
  ./a.out | tee env_test4.txt
  export TEST_PASS=$(grep -w -o -c "SUCCESS" env_test4.txt | awk '{print$1}')
  if [ $TEST_PASS -ge 1 ]; then
    echo "Enviroment Test 4 Passed"
  else
    echo "Environment Compiler Test 4 Failed"
    exit
  fi
  echo " "
  read -r -t 3 -p "I am going to wait for 3 seconds only ..."

  echo " "
  ############## Testing Environment #####

  cd "${WRF_FOLDER}"/WRF_CHEM_Tools/Tests/Compatibility

  cp ${NETCDF}/include/netcdf.inc .

  echo " "
  echo " "
  echo "Library Compatibility Tests "
  echo "Test 1"
  $FC -c 01_fortran+c+netcdf_f.f
  $CC -c 01_fortran+c+netcdf_c.c
  $FC 01_fortran+c+netcdf_f.o 01_fortran+c+netcdf_c.o \
    -L${NETCDF}/lib -lnetcdff -lnetcdf

  ./a.out | tee comp_test1.txt
  export TEST_PASS=$(grep -w -o -c "SUCCESS" comp_test1.txt | awk '{print$1}')
  if [ $TEST_PASS -ge 1 ]; then
    echo "Compatibility Test 1 Passed"
  else
    echo "Compatibility Compiler Test 1 Failed"
    exit
  fi
  echo " "
  read -r -t 3 -p "I am going to wait for 3 seconds only ..."

  echo " "

  echo "Test 2"
  $MPIFC -c 02_fortran+c+netcdf+mpi_f.f
  $MPICC -c 02_fortran+c+netcdf+mpi_c.c
  $MPIFC 02_fortran+c+netcdf+mpi_f.o \
    02_fortran+c+netcdf+mpi_c.o \
    -L${NETCDF}/lib -lnetcdff -lnetcdf

  mpirun ./a.out | tee comp_test2.txt
  export TEST_PASS=$(grep -w -o -c "SUCCESS" comp_test2.txt | awk '{print$1}')
  if [ $TEST_PASS -ge 1 ]; then
    echo "Compatibility Test 2 Passed"
  else
    echo "Compatibility Compiler Test 2 Failed"
    exit
  fi
  echo " "
  read -r -t 3 -p "I am going to wait for 3 seconds only ..."
  echo " "

  echo " All tests completed and passed"
  echo " "
  # Downloading WRF-CHEM Tools and untarring files
  cd "${WRF_FOLDER}"/WRF_CHEM_Tools/Downloads

  wget -c https://www.acom.ucar.edu/wrf-chem/mozbc.tar
  wget -c https://www.acom.ucar.edu/wrf-chem/UBC_inputs.tar
  wget -c https://www.acom.ucar.edu//wrf-chem/megan_bio_emiss.tar
  wget -c https://www.acom.ucar.edu/wrf-chem/megan.data.tar.gz
  wget -c https://www.acom.ucar.edu/wrf-chem/wes-coldens.tar
  wget -c https://www.acom.ucar.edu/wrf-chem/ANTHRO.tar
  wget -c https://www.acom.ucar.edu/webt/wrf-chem/processors/EDGAR-HTAP.tgz
  wget -c https://www.acom.ucar.edu/wrf-chem/EPA_ANTHRO_EMIS.tgz
  wget -c https://www2.acom.ucar.edu/sites/default/files/documents/aircraft_preprocessor_files.tar
  # Downloading FINN
  wget -c https://www.acom.ucar.edu/Data/fire/data/finn2/FINNv2.4_MOD_MOZART_2020_c20210617.txt.gz
  wget -c https://www.acom.ucar.edu/Data/fire/data/finn2/FINNv2.4_MOD_MOZART_2013_c20210617.txt.gz
  wget -c https://www.acom.ucar.edu/Data/fire/data/finn2/FINNv2.4_MODVRS_MOZART_2019_c20210615.txt.gz
  wget -c https://www.acom.ucar.edu/Data/fire/data/fire_emis.tgz
  wget -c https://www.acom.ucar.edu/Data/fire/data/fire_emis_input.tar
  wget -c https://www.acom.ucar.edu/Data/fire/data/TrashEmis.zip

  echo ""
  echo "Unpacking Mozbc."
  env -u LD_LIBRARY_PATH tar -xvf mozbc.tar -C "${WRF_FOLDER}"/WRF_CHEM_Tools/mozbc
  echo ""
  echo "Unpacking MEGAN Bio Emission."
  env -u LD_LIBRARY_PATH tar -xvf megan_bio_emiss.tar -C "${WRF_FOLDER}"/WRF_CHEM_Tools/megan_bio_emiss
  echo ""
  echo "Unpacking MEGAN Bio Emission Data."
  env -u LD_LIBRARY_PATH tar -xzf megan.data.tar.gz -C "${WRF_FOLDER}"/WRF_CHEM_Tools/megan_bio_data
  echo ""
  echo "Unpacking Wes Coldens"
  env -u LD_LIBRARY_PATH tar -xvf wes-coldens.tar -C "${WRF_FOLDER}"/WRF_CHEM_Tools/wes_coldens
  echo ""
  echo "Unpacking Unpacking ANTHRO Emission."
  env -u LD_LIBRARY_PATH tar -xvf ANTHRO.tar -C "${WRF_FOLDER}"/WRF_CHEM_Tools/ANTHRO_EMIS
  echo ""
  echo "Unpacking EDGAR-HTAP."
  env -u LD_LIBRARY_PATH tar -xzf EDGAR-HTAP.tgz -C "${WRF_FOLDER}"/WRF_CHEM_Tools/EDGAR_HTAP
  echo ""
  echo "Unpacking EPA ANTHRO Emission."
  env -u LD_LIBRARY_PATH tar -xzf EPA_ANTHRO_EMIS.tgz -C "${WRF_FOLDER}"/WRF_CHEM_Tools/EPA_ANTHRO_EMIS
  echo ""
  echo "Unpacking Upper Boundary Conditions."
  env -u LD_LIBRARY_PATH tar -xvf UBC_inputs.tar -C "${WRF_FOLDER}"/WRF_CHEM_Tools/UBC
  echo ""
  echo "Unpacking Aircraft Preprocessor Files."
  echo ""
  env -u LD_LIBRARY_PATH tar -xvf aircraft_preprocessor_files.tar -C "${WRF_FOLDER}"/WRF_CHEM_Tools/Aircraft
  echo ""
  echo "Unpacking Fire INventory from NCAR (FINN)"
  env -u LD_LIBRARY_PATH tar -xzf fire_emis.tgz -C "${WRF_FOLDER}"/WRF_CHEM_Tools/FINN
  env -u LD_LIBRARY_PATH tar -xvf fire_emis_input.tar
  env -u LD_LIBRARY_PATH tar -xzf grass_from_img.nc.tgz -C "${WRF_FOLDER}"/WRF_CHEM_Tools/FINN/grid_finn_fire_emis_v2020/src
  env -u LD_LIBRARY_PATH tar -xzf tempfor_from_img.nc.tgz -C "${WRF_FOLDER}"/WRF_CHEM_Tools/FINN/grid_finn_fire_emis_v2020/src
  env -u LD_LIBRARY_PATH tar -xzf shrub_from_img.nc.tgz -C "${WRF_FOLDER}"/WRF_CHEM_Tools/FINN/grid_finn_fire_emis_v2020/src
  env -u LD_LIBRARY_PATH tar -xzf tropfor_from_img.nc.tgz -C "${WRF_FOLDER}"/WRF_CHEM_Tools/FINN/grid_finn_fire_emis_v2020/src

  mv "${WRF_FOLDER}"/WRF_CHEM_Tools/Downloads/FINNv2.4_MOD_MOZART_2020_c20210617.txt.gz "${WRF_FOLDER}"/WRF_CHEM_Tools/FINN
  mv "${WRF_FOLDER}"/WRF_CHEM_Tools/Downloads/FINNv2.4_MOD_MOZART_2013_c20210617.txt.gz "${WRF_FOLDER}"/WRF_CHEM_Tools/FINN
  mv "${WRF_FOLDER}"/WRF_CHEM_Tools/Downloads/FINNv2.4_MODVRS_MOZART_2019_c20210615.txt.gz "${WRF_FOLDER}"/WRF_CHEM_Tools/FINN

  unzip TrashEmis.zip
  mv "${WRF_FOLDER}"/WRF_CHEM_Tools/Downloads/ALL_Emiss_04282014.nc "${WRF_FOLDER}"/WRF_CHEM_Tools/FINN/grid_finn_fire_emis_v2020/src

  cd "${WRF_FOLDER}"/WRF_CHEM_Tools/FINN

  gunzip FINNv2.4_MOD_MOZART_2020_c20210617.txt.gz
  gunzip FINNv2.4_MOD_MOZART_2013_c20210617.txt.gz
  gunzip FINNv2.4_MODVRS_MOZART_2019_c20210615.txt.gz
  ############################Installation of Mozbc #############################
  # Recalling variables from install script to make sure the path is right

  cd "${WRF_FOLDER}"/WRF_CHEM_Tools/mozbc
  chmod +x make_mozbc
  export DIR="${WRF_FOLDER}"/WRF_CHEM_Tools/Libs
  export NETCDF_DIR=$DIR/NETCDF
  sed -i 's/"${ar_libs} -lnetcdff"/"-lnetcdff ${ar_libs}"/' make_mozbc

  ./make_mozbc 2>&1 | tee make.log

  ################## Information on Upper Boundary Conditions ###################

  cd "${WRF_FOLDER}"/WRF_CHEM_Tools/UBC/
  wget -c https://www2.acom.ucar.edu/sites/default/files/documents/8A_2_Barth_WRFWorkshop_11.pdf

  ########################## MEGAN Bio Emission #################################
  # Data for MEGAN Bio Emission located in
  # "${WRF_FOLDER}"/WRF_CHEM_Tools/megan_bio_data

  cd "${WRF_FOLDER}"/WRF_CHEM_Tools/megan_bio_emiss
  chmod +x make_util
  export DIR="${WRF_FOLDER}"/WRF_CHEM_Tools/Libs

  export NETCDF_DIR=$DIR/NETCDF
  sed -i 's/"${ar_libs} -lnetcdff"/"-lnetcdff ${ar_libs}"/' make_util

  ./make_util megan_bio_emiss 2>&1 | tee make.bio.log
  ./make_util megan_xform 2>&1 | tee make.xform.log
  ./make_util surfdata_xform 2>&1 | tee make.surfdata.log

  ############################# Anthroprogenic Emissions #########################

  cd "${WRF_FOLDER}"/WRF_CHEM_Tools/ANTHRO_EMIS/ANTHRO/src
  chmod +x make_anthro
  export DIR="${WRF_FOLDER}"/WRF_CHEM_Tools/Libs

  export NETCDF_DIR=$DIR/NETCDF
  sed -i 's/"${ar_libs} -lnetcdff"/"-lnetcdff ${ar_libs}"/' make_anthro

  ./make_anthro 2>&1 | tee make.log

  ############################# EDGAR HTAP ######################################
  #  This directory contains EDGAR-HTAP anthropogenic emission files for the
  #  year 2010.  The files are in the MOZCART and MOZART-MOSAIC sub-directories.
  #  The MOZCART files are intended to be used for the WRF MOZCART_KPP chemical
  #  option.  The MOZART-MOSAIC files are intended to be used with the following
  #  WRF chemical options (See read -rme in Folder

  ######################### EPA Anthroprogenic Emissions ########################
  cd "${WRF_FOLDER}"/WRF_CHEM_Tools/EPA_ANTHRO_EMIS/src
  chmod +x make_anthro
  export DIR="${WRF_FOLDER}"/WRF_CHEM_Tools/Libs

  export NETCDF_DIR=$DIR/NETCDF
  sed -i 's/"${ar_libs} -lnetcdff"/"-lnetcdff ${ar_libs}"/' make_anthro

  ./make_anthro 2>&1 | tee make.log

  ######################### Weseley EXO Coldens ##################################
  cd "${WRF_FOLDER}"/WRF_CHEM_Tools/wes_coldens
  chmod +x make_util
  export DIR="${WRF_FOLDER}"/WRF_CHEM_Tools/Libs

  export NETCDF_DIR=$DIR/NETCDF
  sed -i 's/"${ar_libs} -lnetcdff"/"-lnetcdff ${ar_libs}"/' make_util

  ./make_util wesely 2>&1 | tee make.wesely.log
  ./make_util exo_coldens 2>&1 | tee make.exo.log

  ########################## Aircraft Emissions Preprocessor #####################
  # This is an IDL based preprocessor to create WRF-Chem read -ry aircraft emissions files
  # (wrfchemaircraft_) from a global inventory in netcdf format. Please consult the read -rME file
  # for how to use the preprocessor. The emissions inventory is not included, so the user must
  # provide their own.
  echo " "
  echo "######################################################################"
  echo " Please see script for details about Aircraft Emissions Preprocessor"
  echo "######################################################################"
  echo " "

  ######################## Fire INventory from NCAR (FINN) ###########################
  # Fire INventory from NCAR (FINN): A daily fire emissions product for atmospheric chemistry models
  # https://www2.acom.ucar.edu/modeling/finn-fire-inventory-ncar
  echo " "
  echo "###########################################"
  echo " Please see folder for details about FINN."
  echo "###########################################"
  echo " "

  #####################################BASH Script Finished##############################
  echo " "
  echo "WRF CHEM Tools & PREP-CHEM-SRC compiled with latest version of NETCDF files available on 03/01/2025"
  echo "If error occurs using WRFCHEM tools please update your NETCDF libraries or reconfigure with older libraries"
  echo "This is a WRC Chem Community tool made by a private user and is not supported by UCAR/NCAR"
  read -r -t 5 -p "BASH Script Finished"

fi

if [ "$macos_64bit_GNU" = "1" ] && [ "$MAC_CHIP" = "Intel" ]; then

  #############################basic package managment############################
  brew cleanup -s
  brew update
  outdated_packages=$(brew outdated --quiet)

  # List of packages to check/install
  packages=(
    "autoconf" "automake" "bison" "byacc" "cmake" "curl" "flex" "gcc@13"
    "gedit" "git" "gnu-sed" "java" "ksh"
    "libtool" "m4" "make" "python@3.10" "snapcraft" "tcsh" "wget"
    "xauth" "xorgproto" "xorgrgb" "xquartz"
  )

  for pkg in "${packages[@]}"; do
    if brew list "$pkg" &> /dev/null; then
      echo "$pkg is already installed."
      if [[ $outdated_packages == *"$pkg"* ]]; then
        echo "$pkg has a newer version available. Upgrading..."
        brew upgrade "$pkg"
      fi
    else
      echo "$pkg is not installed. Installing..."
      brew install "$pkg"
    fi
    sleep 1
  done

  ##############################Directory Listing############################

  export HOME=$(
    cd ~ \
      && pwd
  )
  mkdir $HOME/WRFCHEM
  export WRF_FOLDER=$HOME/WRFCHEM
  cd "${WRF_FOLDER}"/
  mkdir Downloads
  mkdir WRFDA
  mkdir Libs
  mkdir -p Libs/grib2
  mkdir -p Libs/NETCDF
  mkdir -p Tests/Environment
  mkdir -p Tests/Compatibility
  mkdir "${WRF_FOLDER}"/WRF_CHEM_Tools
  mkdir "${WRF_FOLDER}"/WRF_CHEM_Tools/Libs
  mkdir "${WRF_FOLDER}"/WRF_CHEM_Tools/Libs/grib2
  mkdir "${WRF_FOLDER}"/WRF_CHEM_Tools/Libs/NETCDF
  mkdir "${WRF_FOLDER}"/WRF_CHEM_Tools/Downloads
  mkdir "${WRF_FOLDER}"/WRF_CHEM_Tools/mozbc
  mkdir "${WRF_FOLDER}"/WRF_CHEM_Tools/megan_bio_emiss
  mkdir "${WRF_FOLDER}"/WRF_CHEM_Tools/megan_bio_data
  mkdir "${WRF_FOLDER}"/WRF_CHEM_Tools/wes_coldens
  mkdir "${WRF_FOLDER}"/WRF_CHEM_Tools/ANTHRO_EMIS
  mkdir "${WRF_FOLDER}"/WRF_CHEM_Tools/EDGAR_HTAP
  mkdir "${WRF_FOLDER}"/WRF_CHEM_Tools/EPA_ANTHRO_EMIS
  mkdir "${WRF_FOLDER}"/WRF_CHEM_Tools/UBC
  mkdir "${WRF_FOLDER}"/WRF_CHEM_Tools/Aircraft
  mkdir "${WRF_FOLDER}"/WRF_CHEM_Tools/FINN
  mkdir "${WRF_FOLDER}"/WRF_CHEM_Tools/Tests
  mkdir "${WRF_FOLDER}"/WRF_CHEM_Tools/Tests/Environment
  mkdir "${WRF_FOLDER}"/WRF_CHEM_Tools/Tests/Compatibility

  export DIR="${WRF_FOLDER}"/WRF_CHEM_Tools/Libs

  #############################Core Management####################################
  export CPU_CORE=$(sysctl -n hw.ncpu) # number of available threads on system
  export CPU_6CORE="6"
  export CPU_QUARTER=$(($CPU_CORE / 4))
  #1/2 of availble cores on system
  export CPU_QUARTER_EVEN=$(($CPU_QUARTER - ($CPU_QUARTER % 2)))
  #Forces CPU cores to even number to avoid partial core export. ie 7 cores would be 3.5 cores.

  if [ $CPU_CORE -le $CPU_6CORE ]; then #If statement for low core systems.  Forces computers to only use 1 core if there are 4 cores or less on the system. then
    export CPU_QUARTER_EVEN="2"
  else
    export CPU_QUARTER_EVEN=$(($CPU_QUARTER - ($CPU_QUARTER % 2)))
  fi

  echo "##########################################"
  echo "Number of Threads being used $CPU_QUARTER_EVEN"
  echo "##########################################"
  echo " "

  ##############################Downloading Libraries############################

  cd "${WRF_FOLDER}"/WRF_CHEM_Tools/Downloads
  wget -c https://github.com/madler/zlib/releases/download/v$Zlib_Version/zlib-$Zlib_Version.tar.gz
  wget -c https://github.com/HDFGroup/hdf5/releases/download/hdf5_$HDF5_Version/hdf5-$HDF5_Version.tar.gz
  wget -c https://github.com/Unidata/netcdf-c/archive/refs/tags/v$Netcdf_C_Version.tar.gz
  wget -c https://github.com/Unidata/netcdf-fortran/archive/refs/tags/v$Netcdf_Fortran_Version.tar.gz
  wget -c https://download.sourceforge.net/libpng/libpng-$Libpng_Version.tar.gz
  wget -c https://www.ece.uvic.ca/~frodo/jasper/software/jasper-$Jasper_Version.zip
  wget -c https://github.com/pmodels/mpich/releases/download/v$Mpich_Version/mpich-$Mpich_Version.tar.gz
  wget -c https://parallel-netcdf.github.io/Release/pnetcdf-$Pnetcdf_Version.tar.gz

  echo " "

  #############################Compilers############################

  # Find the highest version of GCC in /usr/local/bin

  latest_gcc=$(ls /usr/local/bin/gcc-* 2> /dev/null | grep -o 'gcc-[0-9]*' | sort -V | tail -n 1)
  latest_gpp=$(ls /usr/local/bin/g++-* 2> /dev/null | grep -o 'g++-[0-9]*' | sort -V | tail -n 1)
  latest_gfortran=$(ls /usr/local/bin/gfortran-* 2> /dev/null | grep -o 'gfortran-[0-9]*' | sort -V | tail -n 1)

  # Display the chosen versions
  echo "Selected gcc version: $latest_gcc"
  echo "Selected g++ version: $latest_gpp"
  echo "Selected gfortran version: $latest_gfortran"

  export CC=/usr/local/bin/$latest_gcc
  export CXX=/usr/local/bin/$latest_gpp
  export FC=/usr/local/bin/$latest_gfortran
  export F77=/usr/local/bin/$latest_gfortran

  echo " "

  #IF statement for GNU compiler issue
  export GCC_VERSION=$(/usr/local/bin/$latest_gcc -dumpfullversion | awk '{print$1}')
  export GFORTRAN_VERSION=$(/usr/local/bin/$latest_gfortran -dumpfullversion | awk '{print$1}')
  export GPLUSPLUS_VERSION=$(/usr/local/bin/$latest_gpp -dumpfullversion | awk '{print$1}')

  export GCC_VERSION_MAJOR_VERSION=$(echo $GCC_VERSION | awk -F. '{print $1}')
  export GFORTRAN_VERSION_MAJOR_VERSION=$(echo $GFORTRAN_VERSION | awk -F. '{print $1}')
  export GPLUSPLUS_VERSION_MAJOR_VERSION=$(echo $GPLUSPLUS_VERSION | awk -F. '{print $1}')

  export version_10="10"

  if [ $GCC_VERSION_MAJOR_VERSION -ge $version_10 ] || [ $GFORTRAN_VERSION_MAJOR_VERSION -ge $version_10 ] || [ $GPLUSPLUS_VERSION_MAJOR_VERSION -ge $version_10 ]; then
    export fallow_argument=-fallow-argument-mismatch
    export boz_argument=-fallow-invalid-boz
  else
    export fallow_argument=
    export boz_argument=
  fi

  export FFLAGS="$fallow_argument"
  export FCFLAGS="$fallow_argument"

  # Export compiler environment variables
  export CC=/usr/local/bin/gcc-13
  export CXX=/usr/local/bin/g++-13
  export FC=/usr/local/bin/gfortran-13
  export F77=/usr/local/bin/gfortran-13
  export CFLAGS="-fPIC -fPIE -Wno-implicit-function-declaration -Wno-incompatible-function-pointer-types -Wno-incompatible-pointer-types -Wall"

  # --- critical macOS SDK wiring for Homebrew GCC (fixes _bounds.h) ---
  export SDKROOT="$(xcrun --sdk macosx --show-sdk-path)"

  export CPPFLAGS="${CPPFLAGS:+$CPPFLAGS }--sysroot=\"$SDKROOT\" -isysroot \"$SDKROOT\""
  export CFLAGS="${CFLAGS:+$CFLAGS }--sysroot=\"$SDKROOT\" -isysroot \"$SDKROOT\""
  export CXXFLAGS="${CXXFLAGS:+$CXXFLAGS }--sysroot=\"$SDKROOT\" -isysroot \"$SDKROOT\""
  export LDFLAGS="${LDFLAGS:+$LDFLAGS }--sysroot=\"$SDKROOT\" -isysroot \"$SDKROOT\""

  echo "CC=$CC"
  echo "CXX=$CXX"
  echo "FC=$FC"
  echo "SDKROOT=$SDKROOT"
  echo "CFLAGS=$CFLAGS"
  echo "CPPFLAGS=$CPPFLAGS"
  echo "LDFLAGS=$LDFLAGS"

  #############################zlib############################
  #Uncalling compilers due to comfigure issue with zlib1.2.12
  #With CC & CXX definied ./configure uses different compiler Flags

  cd "${WRF_FOLDER}"/WRF_CHEM_Tools/Downloads
  env -u LD_LIBRARY_PATH tar -xzf zlib-$Zlib_Version.tar.gz
  cd zlib-$Zlib_Version/
  ./configure --prefix=$DIR/grib2 2>&1 | tee configure.log
  make -j $CPU_QUARTER_EVEN 2>&1 | tee make.log
  make -j $CPU_QUARTER_EVEN install 2>&1 | tee make.install.log

  echo " "

  ##############################MPICH############################
  cd "${WRF_FOLDER}"/WRF_CHEM_Tools/Downloads
  env -u LD_LIBRARY_PATH tar -xzf mpich-$Mpich_Version.tar.gz
  cd mpich-$Mpich_Version/
  F90= ./configure --prefix=$DIR/MPICH --with-device=ch3 FFLAGS=$FFLAGS FCFLAGS=$FCFLAGS 2>&1 | tee configure.log
  make -j $CPU_QUARTER_EVEN 2>&1 | tee make.log
  make -j $CPU_QUARTER_EVEN install 2>&1 | tee make.install.log

  export PATH=$DIR/MPICH/bin:$PATH

  export MPIFC=$DIR/MPICH/bin/mpifort
  export MPIF77=$DIR/MPICH/bin/mpifort
  export MPIF90=$DIR/MPICH/bin/mpifort
  export MPICC=$DIR/MPICH/bin/mpicc
  export MPICXX=$DIR/MPICH/bin/mpicxx

  echo " "

  #############################libpng############################
  cd "${WRF_FOLDER}"/WRF_CHEM_Tools/Downloads
  export LDFLAGS=-L$DIR/grib2/lib
  export CPPFLAGS=-I$DIR/grib2/include
  env -u LD_LIBRARY_PATH tar -xzf libpng-$Libpng_Version.tar.gz
  cd libpng-$Libpng_Version/
  CC=$MPICC FC=$MPIFC F77=$MPIF77 F90=$MPIF90 CXX=$MPICXX CFLAGS=$CFLAGS FFLAGS=$FFLAGS FCFLAGS=$FCFLAGS ./configure --prefix=$DIR/grib2 2>&1 | tee configure.log
  make -j $CPU_QUARTER_EVEN 2>&1 | tee make.log
  make -j $CPU_QUARTER_EVEN install 2>&1 | tee make.install.log

  echo " "
  #############################JasPer############################

  cd "${WRF_FOLDER}"/WRF_CHEM_Tools/Downloads
  unzip jasper-$Jasper_Version.zip
  cd jasper-$Jasper_Version/
  CC=$MPICC FC=$MPIFC F77=$MPIF77 F90=$MPIF90 CXX=$MPICXX CFLAGS=$CFLAGS FFLAGS=$FFLAGS FCFLAGS=$FCFLAGS ./configure --prefix=$DIR/grib2 2>&1 | tee configure.log
  make -j $CPU_QUARTER_EVEN 2>&1 | tee make.log
  make -j $CPU_QUARTER_EVEN install 2>&1 | tee make.install.log
  export JASPERLIB=$DIR/grib2/lib
  export JASPERINC=$DIR/grib2/include

  echo " "
  #############################hdf5 library for netcdf4 functionality############################

  cd "${WRF_FOLDER}"/WRF_CHEM_Tools/Downloads
  env -u LD_LIBRARY_PATH tar -xzf hdf5-$HDF5_Version.tar.gz
  cd hdf5-$HDF5_Version
  CC=$MPICC FC=$MPIFC F77=$MPIF77 F90=$MPIF90 CXX=$MPICXX CFLAGS=$CFLAGS FFLAGS=$FFLAGS FCFLAGS=$FCFLAGS ./configure --prefix=$DIR/grib2 --with-zlib=$DIR/grib2 --enable-hl --enable-fortran --enable-parallel 2>&1 | tee configure.log
  make -j $CPU_QUARTER_EVEN 2>&1 | tee make.log
  make -j $CPU_QUARTER_EVEN install 2>&1 | tee make.install.log

  export HDF5=$DIR/grib2
  export PHDF5=$DIR/grib2
  export LD_LIBRARY_PATH=$DIR/grib2/lib:$LD_LIBRARY_PATH

  echo " "

  #############################Install Parallel-netCDF##############################
  #Make file created with half of available cpu cores
  #Hard path for MPI added
  ##################################################################################
  cd "${WRF_FOLDER}"/WRF_CHEM_Tools/Downloads
  env -u LD_LIBRARY_PATH tar -xzf pnetcdf-$Pnetcdf_Version.tar.gz
  cd pnetcdf-$Pnetcdf_Version
  export MPIFC=$DIR/MPICH/bin/mpifort
  export MPIF77=$DIR/MPICH/bin/mpifort
  export MPIF90=$DIR/MPICH/bin/mpifort
  export MPICC=$DIR/MPICH/bin/mpicc
  export MPICXX=$DIR/MPICH/bin/mpicxx
  ./configure --prefix=$DIR/grib2 --enable-shared --enable-static 2>&1 | tee configure.log
  make -j $CPU_QUARTER_EVEN 2>&1 | tee make.log
  make -j $CPU_QUARTER_EVEN install 2>&1 | tee make.install.log

  export PNETCDF=$DIR/grib2

  ##############################Install NETCDF C Library############################
  cd "${WRF_FOLDER}"/WRF_CHEM_Tools/Downloads
  env -u LD_LIBRARY_PATH tar -xzf v$Netcdf_C_Version.tar.gz
  cd netcdf-c-$Netcdf_C_Version/
  export CPPFLAGS=-I$DIR/grib2/include
  export LDFLAGS=-L$DIR/grib2/lib
  export LIBS="-lhdf5_hl -lhdf5 -lz -lcurl -lgfortran -lgcc -lm -ldl -lpnetcdf"
  CC=$MPICC FC=$MPIFC F77=$MPIF77 F90=$MPIF90 CXX=$MPICXX CFLAGS=$CFLAGS FFLAGS=$FFLAGS FCFLAGS=$FCFLAGS ./configure --prefix=$DIR/NETCDF --disable-dap --enable-netcdf-4 --enable-netcdf4 --enable-shared --enable-static --enable-pnetcdf --enable-cdf5 --enable-parallel-tests 2>&1 | tee configure.log
  make -j $CPU_QUARTER_EVEN 2>&1 | tee make.log
  make -j $CPU_QUARTER_EVEN install 2>&1 | tee make.make.log

  export PATH=$DIR/NETCDF/bin:$PATH
  export NETCDF=$DIR/NETCDF
  echo " "

  ##############################NetCDF fortran library############################
  cd "${WRF_FOLDER}"/WRF_CHEM_Tools/Downloads
  env -u LD_LIBRARY_PATH tar -xzf v$Netcdf_Fortran_Version.tar.gz
  cd netcdf-fortran-$Netcdf_Fortran_Version/
  export LD_LIBRARY_PATH=$DIR/NETCDF/lib:$LD_LIBRARY_PATH
  export CPPFLAGS="-I$DIR/NETCDF/include -I$DIR/grib2/include"
  export LDFLAGS="-L$DIR/NETCDF/lib -L$DIR/grib2/lib"
  export LIBS="-lnetcdf -lpnetcdf -lcurl -lhdf5_hl -lhdf5 -lz -lm -ldl -lgcc -lgfortran"
  CC=$MPICC FC=$MPIFC F77=$MPIF77 F90=$MPIF90 CXX=$MPICXX CFLAGS=$CFLAGS FFLAGS=$FFLAGS FCFLAGS=$FCFLAGS ./configure --prefix=$DIR/NETCDF --enable-netcdf-4 --enable-netcdf4 --enable-shared --enable-static --enable-parallel-tests --enable-hdf5 2>&1 | tee configure.log
  make -j $CPU_QUARTER_EVEN 2>&1 | tee make.log
  make -j $CPU_QUARTER_EVEN install 2>&1 | tee make.install.log

  echo " "
  #################################### System Environment Tests ##############

  cd "${WRF_FOLDER}"/WRF_CHEM_Tools/Downloads
  wget -c https://www2.mmm.ucar.edu/wrf/OnLineTutorial/compile_tutorial/tar_files/Fortran_C_NETCDF_MPI_tests.tar
  wget -c https://www2.mmm.ucar.edu/wrf/OnLineTutorial/compile_tutorial/tar_files/Fortran_C_tests.tar

  env -u LD_LIBRARY_PATH tar -xvf Fortran_C_tests.tar -C "${WRF_FOLDER}"/WRF_CHEM_Tools/Tests/Environment
  env -u LD_LIBRARY_PATH tar -xvf Fortran_C_NETCDF_MPI_tests.tar -C "${WRF_FOLDER}"/WRF_CHEM_Tools/Tests/Compatibility

  export one="1"
  echo " "
  ############## Testing Environment #####

  cd "${WRF_FOLDER}"/WRF_CHEM_Tools/Tests/Environment

  cp ${NETCDF}/include/netcdf.inc .

  echo " "
  echo " "
  echo "Environment Testing "
  echo "Test 1"
  $FC TEST_1_fortran_only_fixed.f
  ./a.out | tee env_test1.txt
  export TEST_PASS=$(grep -w -o -c "SUCCESS" env_test1.txt | awk '{print$1}')
  if [ $TEST_PASS -ge 1 ]; then
    echo "Enviroment Test 1 Passed"
  else
    echo "Environment Compiler Test 1 Failed"
    exit
  fi
  read -r -t 3 -p "I am going to wait for 3 seconds only ..."

  echo " "
  echo "Test 2"
  $FC TEST_2_fortran_only_free.f90
  ./a.out | tee env_test2.txt
  export TEST_PASS=$(grep -w -o -c "SUCCESS" env_test2.txt | awk '{print$1}')
  if [ $TEST_PASS -ge 1 ]; then
    echo "Enviroment Test 2 Passed"
  else
    echo "Environment Compiler Test 2 Failed"
    exit
  fi
  echo " "
  read -r -t 3 -p "I am going to wait for 3 seconds only ..."

  echo " "
  echo "Test 3"
  $CC TEST_3_c_only.c
  ./a.out | tee env_test3.txt
  export TEST_PASS=$(grep -w -o -c "SUCCESS" env_test3.txt | awk '{print$1}')
  if [ $TEST_PASS -ge 1 ]; then
    echo "Enviroment Test 3 Passed"
  else
    echo "Environment Compiler Test 3 Failed"
    exit
  fi
  echo " "
  read -r -t 3 -p "I am going to wait for 3 seconds only ..."

  echo " "
  echo "Test 4"
  $CC -c -m64 TEST_4_fortran+c_c.c
  $FC -c -m64 TEST_4_fortran+c_f.f90
  $FC -m64 TEST_4_fortran+c_f.o TEST_4_fortran+c_c.o
  ./a.out | tee env_test4.txt
  export TEST_PASS=$(grep -w -o -c "SUCCESS" env_test4.txt | awk '{print$1}')
  if [ $TEST_PASS -ge 1 ]; then
    echo "Enviroment Test 4 Passed"
  else
    echo "Environment Compiler Test 4 Failed"
    exit
  fi
  echo " "
  read -r -t 3 -p "I am going to wait for 3 seconds only ..."

  echo " "
  ############## Testing Environment #####

  cd "${WRF_FOLDER}"/WRF_CHEM_Tools/Tests/Compatibility

  cp ${NETCDF}/include/netcdf.inc .

  echo " "
  echo " "
  echo "Library Compatibility Tests "
  echo "Test 1"
  $FC -c 01_fortran+c+netcdf_f.f
  $CC -c 01_fortran+c+netcdf_c.c
  $FC 01_fortran+c+netcdf_f.o 01_fortran+c+netcdf_c.o \
    -L${NETCDF}/lib -lnetcdff -lnetcdf

  ./a.out | tee comp_test1.txt
  export TEST_PASS=$(grep -w -o -c "SUCCESS" comp_test1.txt | awk '{print$1}')
  if [ $TEST_PASS -ge 1 ]; then
    echo "Compatibility Test 1 Passed"
  else
    echo "Compatibility Compiler Test 1 Failed"
    exit
  fi
  echo " "
  read -r -t 3 -p "I am going to wait for 3 seconds only ..."

  echo " "

  echo "Test 2"
  $MPIFC -c 02_fortran+c+netcdf+mpi_f.f
  $MPICC -c 02_fortran+c+netcdf+mpi_c.c
  $MPIFC 02_fortran+c+netcdf+mpi_f.o \
    02_fortran+c+netcdf+mpi_c.o \
    -L${NETCDF}/lib -lnetcdff -lnetcdf

  $DIR/MPICH/bin/mpirun ./a.out | tee comp_test2.txt
  export TEST_PASS=$(grep -w -o -c "SUCCESS" comp_test2.txt | awk '{print$1}')
  if [ $TEST_PASS -ge 1 ]; then
    echo "Compatibility Test 2 Passed"
  else
    echo "Compatibility Compiler Test 2 Failed"
    exit
  fi
  echo " "
  read -r -t 3 -p "I am going to wait for 3 seconds only ..."
  echo " "

  echo " All tests completed and passed"
  echo " "
  # Downloading WRF-CHEM Tools and untarring files
  cd "${WRF_FOLDER}"/WRF_CHEM_Tools/Downloads

  wget -c https://www.acom.ucar.edu/wrf-chem/mozbc.tar
  wget -c https://www.acom.ucar.edu/wrf-chem/UBC_inputs.tar
  wget -c https://www.acom.ucar.edu//wrf-chem/megan_bio_emiss.tar
  wget -c https://www.acom.ucar.edu/wrf-chem/megan.data.tar.gz
  wget -c https://www.acom.ucar.edu/wrf-chem/wes-coldens.tar
  wget -c https://www.acom.ucar.edu/wrf-chem/ANTHRO.tar
  wget -c https://www.acom.ucar.edu/webt/wrf-chem/processors/EDGAR-HTAP.tgz
  wget -c https://www.acom.ucar.edu/wrf-chem/EPA_ANTHRO_EMIS.tgz
  wget -c https://www2.acom.ucar.edu/sites/default/files/documents/aircraft_preprocessor_files.tar
  # Downloading FINN
  wget -c https://www.acom.ucar.edu/Data/fire/data/finn2/FINNv2.4_MOD_MOZART_2020_c20210617.txt.gz
  wget -c https://www.acom.ucar.edu/Data/fire/data/finn2/FINNv2.4_MOD_MOZART_2013_c20210617.txt.gz
  wget -c https://www.acom.ucar.edu/Data/fire/data/finn2/FINNv2.4_MODVRS_MOZART_2019_c20210615.txt.gz
  wget -c https://www.acom.ucar.edu/Data/fire/data/fire_emis.tgz
  wget -c https://www.acom.ucar.edu/Data/fire/data/fire_emis_input.tar
  wget -c https://www.acom.ucar.edu/Data/fire/data/TrashEmis.zip

  echo ""
  echo "Unpacking Mozbc."
  env -u LD_LIBRARY_PATH tar -xvf mozbc.tar -C "${WRF_FOLDER}"/WRF_CHEM_Tools/mozbc
  echo ""
  echo "Unpacking MEGAN Bio Emission."
  env -u LD_LIBRARY_PATH tar -xvf megan_bio_emiss.tar -C "${WRF_FOLDER}"/WRF_CHEM_Tools/megan_bio_emiss
  echo ""
  echo "Unpacking MEGAN Bio Emission Data."
  env -u LD_LIBRARY_PATH tar -xzf megan.data.tar.gz -C "${WRF_FOLDER}"/WRF_CHEM_Tools/megan_bio_data
  echo ""
  echo "Unpacking Wes Coldens"
  env -u LD_LIBRARY_PATH tar -xvf wes-coldens.tar -C "${WRF_FOLDER}"/WRF_CHEM_Tools/wes_coldens
  echo ""
  echo "Unpacking Unpacking ANTHRO Emission."
  env -u LD_LIBRARY_PATH tar -xvf ANTHRO.tar -C "${WRF_FOLDER}"/WRF_CHEM_Tools/ANTHRO_EMIS
  echo ""
  echo "Unpacking EDGAR-HTAP."
  env -u LD_LIBRARY_PATH tar -xzf EDGAR-HTAP.tgz -C "${WRF_FOLDER}"/WRF_CHEM_Tools/EDGAR_HTAP
  echo ""
  echo "Unpacking EPA ANTHRO Emission."
  env -u LD_LIBRARY_PATH tar -xzf EPA_ANTHRO_EMIS.tgz -C "${WRF_FOLDER}"/WRF_CHEM_Tools/EPA_ANTHRO_EMIS
  echo ""
  echo "Unpacking Upper Boundary Conditions."
  env -u LD_LIBRARY_PATH tar -xvf UBC_inputs.tar -C "${WRF_FOLDER}"/WRF_CHEM_Tools/UBC
  echo ""
  echo "Unpacking Aircraft Preprocessor Files."
  echo ""
  env -u LD_LIBRARY_PATH tar -xvf aircraft_preprocessor_files.tar -C "${WRF_FOLDER}"/WRF_CHEM_Tools/Aircraft
  echo ""
  echo "Unpacking Fire INventory from NCAR (FINN)"
  env -u LD_LIBRARY_PATH tar -xzf fire_emis.tgz -C "${WRF_FOLDER}"/WRF_CHEM_Tools/FINN
  env -u LD_LIBRARY_PATH tar -xvf fire_emis_input.tar
  env -u LD_LIBRARY_PATH tar -xzf grass_from_img.nc.tgz -C "${WRF_FOLDER}"/WRF_CHEM_Tools/FINN/grid_finn_fire_emis_v2020/src
  env -u LD_LIBRARY_PATH tar -xzf tempfor_from_img.nc.tgz -C "${WRF_FOLDER}"/WRF_CHEM_Tools/FINN/grid_finn_fire_emis_v2020/src
  env -u LD_LIBRARY_PATH tar -xzf shrub_from_img.nc.tgz -C "${WRF_FOLDER}"/WRF_CHEM_Tools/FINN/grid_finn_fire_emis_v2020/src
  env -u LD_LIBRARY_PATH tar -xzf tropfor_from_img.nc.tgz -C "${WRF_FOLDER}"/WRF_CHEM_Tools/FINN/grid_finn_fire_emis_v2020/src

  mv "${WRF_FOLDER}"/WRF_CHEM_Tools/Downloads/FINNv2.4_MOD_MOZART_2020_c20210617.txt.gz "${WRF_FOLDER}"/WRF_CHEM_Tools/FINN
  mv "${WRF_FOLDER}"/WRF_CHEM_Tools/Downloads/FINNv2.4_MOD_MOZART_2013_c20210617.txt.gz "${WRF_FOLDER}"/WRF_CHEM_Tools/FINN
  mv "${WRF_FOLDER}"/WRF_CHEM_Tools/Downloads/FINNv2.4_MODVRS_MOZART_2019_c20210615.txt.gz "${WRF_FOLDER}"/WRF_CHEM_Tools/FINN

  unzip TrashEmis.zip
  mv "${WRF_FOLDER}"/WRF_CHEM_Tools/Downloads/ALL_Emiss_04282014.nc "${WRF_FOLDER}"/WRF_CHEM_Tools/FINN/grid_finn_fire_emis_v2020/src

  cd "${WRF_FOLDER}"/WRF_CHEM_Tools/FINN

  gunzip FINNv2.4_MOD_MOZART_2020_c20210617.txt.gz
  gunzip FINNv2.4_MOD_MOZART_2013_c20210617.txt.gz
  gunzip FINNv2.4_MODVRS_MOZART_2019_c20210615.txt.gz
  ############################Installation of Mozbc #############################
  export fallow_argument=-fallow-argument-mismatch
  export boz_argument=-fallow-invalid-boz

  # Recalling variables from install script to make sure the path is right

  cd "${WRF_FOLDER}"/WRF_CHEM_Tools/mozbc
  chmod +x make_mozbc
  export DIR="${WRF_FOLDER}"/WRF_CHEM_Tools/Libs
  export FC=gfortran
  export NETCDF_DIR=$DIR/NETCDF
  sed -i'' -e 's/"${ar_libs} -lnetcdff"/"-lnetcdff ${ar_libs}"/' make_mozbc
  sed -i'' -e '8s/FFLAGS = --g/FFLAGS = --g ${fallow_argument}/' Makefile
  sed -i'' -e '10s/FFLAGS = -g/FFLAGS = -g ${fallow_argument}/' Makefile
  ./make_mozbc 2>&1 | tee make.log

  ################## Information on Upper Boundary Conditions ###################

  cd "${WRF_FOLDER}"/WRF_CHEM_Tools/UBC/
  wget -c https://www2.acom.ucar.edu/sites/default/files/documents/8A_2_Barth_WRFWorkshop_11.pdf

  ########################## MEGAN Bio Emission #################################
  # Data for MEGAN Bio Emission located in
  # "${WRF_FOLDER}"/WRF_CHEM_Tools/megan_bio_data

  cd "${WRF_FOLDER}"/WRF_CHEM_Tools/megan_bio_emiss
  chmod +x make_util
  export DIR="${WRF_FOLDER}"/WRF_CHEM_Tools/Libs
  export FC=gfortran
  export NETCDF_DIR=$DIR/NETCDF
  sed -i'' -e 's/"${ar_libs} -lnetcdff"/"-lnetcdff ${ar_libs}"/' make_util
  sed -i'' -e '8s/FFLAGS = --g/FFLAGS = --g ${fallow_argument}/' Makefile
  sed -i'' -e '10s/FFLAGS = -g/FFLAGS = -g ${fallow_argument}/' Makefile
  ./make_util megan_bio_emiss 2>&1 | tee make.bio.log
  ./make_util megan_xform 2>&1 | tee make.xform.log
  ./make_util surfdata_xform 2>&1 | tee make.surfdata.log

  ############################# Anthroprogenic Emissions #########################

  cd "${WRF_FOLDER}"/WRF_CHEM_Tools/ANTHRO_EMIS/ANTHRO/src
  chmod +x make_anthro
  export DIR="${WRF_FOLDER}"/WRF_CHEM_Tools/Libs
  export FC=gfortran
  export NETCDF_DIR=$DIR/NETCDF
  sed -i'' -e 's/"${ar_libs} -lnetcdff"/"-lnetcdff ${ar_libs}"/' make_anthro
  sed -i'' -e '8s/FFLAGS = --g/FFLAGS = --g ${fallow_argument}/' Makefile
  sed -i'' -e '10s/FFLAGS = -g/FFLAGS = -g ${fallow_argument}/' Makefile
  ./make_anthro 2>&1 | tee make.log

  ############################# EDGAR HTAP ######################################
  #  This directory contains EDGAR-HTAP anthropogenic emission files for the
  #  year 2010.  The files are in the MOZCART and MOZART-MOSAIC sub-directories.
  #  The MOZCART files are intended to be used for the WRF MOZCART_KPP chemical
  #  option.  The MOZART-MOSAIC files are intended to be used with the following
  #  WRF chemical options (See read -rme in Folder

  ######################### EPA Anthroprogenic Emissions ########################
  cd "${WRF_FOLDER}"/WRF_CHEM_Tools/EPA_ANTHRO_EMIS/src
  chmod +x make_anthro
  export DIR="${WRF_FOLDER}"/WRF_CHEM_Tools/Libs
  export FC=gfortran
  export NETCDF_DIR=$DIR/NETCDF
  sed -i'' -e 's/"${ar_libs} -lnetcdff"/"-lnetcdff ${ar_libs}"/' make_anthro
  sed -i'' -e '8s/FFLAGS = --g/FFLAGS = --g ${fallow_argument}/' Makefile
  sed -i'' -e '10s/FFLAGS = -g/FFLAGS = -g ${fallow_argument}/' Makefile
  ./make_anthro 2>&1 | tee make.log

  ######################### Weseley EXO Coldens ##################################
  cd "${WRF_FOLDER}"/WRF_CHEM_Tools/wes_coldens
  chmod +x make_util
  export DIR="${WRF_FOLDER}"/WRF_CHEM_Tools/Libs
  export FC=gfortran
  export NETCDF_DIR=$DIR/NETCDF
  sed -i'' -e 's/"${ar_libs} -lnetcdff"/"-lnetcdff ${ar_libs}"/' make_util
  sed -i'' -e '8s/FFLAGS = --g/FFLAGS = --g ${fallow_argument}/' Makefile
  sed -i'' -e '10s/FFLAGS = -g/FFLAGS = -g ${fallow_argument}/' Makefile
  ./make_util wesely 2>&1 | tee make.wesley.log
  ./make_util exo_coldens 2>&1 | tee make.exo.log

  ########################## Aircraft Emissions Preprocessor #####################
  # This is an IDL based preprocessor to create WRF-Chem read -ry aircraft emissions files
  # (wrfchemaircraft_) from a global inventory in netcdf format. Please consult the read -rME file
  # for how to use the preprocessor. The emissions inventory is not included, so the user must
  # provide their own.
  echo " "
  echo "######################################################################"
  echo " Please see script for details about Aircraft Emissions Preprocessor"
  echo "######################################################################"
  echo " "

  ######################## Fire INventory from NCAR (FINN) ###########################
  # Fire INventory from NCAR (FINN): A daily fire emissions product for atmospheric chemistry models
  # https://www2.acom.ucar.edu/modeling/finn-fire-inventory-ncar
  echo " "
  echo "###########################################"
  echo " Please see folder for details about FINN."
  echo "###########################################"
  echo " "
  #####################################BASH Script Finished##############################
  echo " "
  echo "WRF CHEM Tools compiled with latest version of NETCDF files available on 03/01/2025"
  echo "If error occurs using WRFCHEM tools please update your NETCDF libraries or reconfigure with older libraries"
  echo "This is a WRC Chem Community tool made by a private user and is not supported by UCAR/NCAR"
  echo "BASH Script Finished"

fi

if [ "$macos_64bit_GNU" = "1" ] && [ "$MAC_CHIP" = "ARM" ]; then

  #############################basic package managment############################
  brew cleanup -s
  brew update
  outdated_packages=$(brew outdated --quiet)

  # List of packages to check/install
  packages=(
    "autoconf" "automake" "bison" "byacc" "cmake" "curl" "flex" "gcc@13"
    "gedit" "git" "gnu-sed" "java" "ksh"
    "libtool" "m4" "make" "python@3.10" "snapcraft" "tcsh" "wget"
    "xauth" "xorgproto" "xorgrgb" "xquartz"
  )

  for pkg in "${packages[@]}"; do
    if brew list "$pkg" &> /dev/null; then
      echo "$pkg is already installed."
      if [[ $outdated_packages == *"$pkg"* ]]; then
        echo "$pkg has a newer version available. Upgrading..."
        brew upgrade "$pkg"
      fi
    else
      echo "$pkg is not installed. Installing..."
      brew install "$pkg"
    fi
    sleep 1
  done

  ##############################Directory Listing############################

  export HOME=$(
    cd ~ \
      && pwd
  )
  mkdir $HOME/WRFCHEM
  export WRF_FOLDER=$HOME/WRFCHEM
  cd "${WRF_FOLDER}"/
  mkdir Downloads
  mkdir WRFDA
  mkdir Libs
  mkdir -p Libs/grib2
  mkdir -p Libs/NETCDF
  mkdir -p Tests/Environment
  mkdir -p Tests/Compatibility
  mkdir "${WRF_FOLDER}"/WRF_CHEM_Tools
  mkdir "${WRF_FOLDER}"/WRF_CHEM_Tools/Libs
  mkdir "${WRF_FOLDER}"/WRF_CHEM_Tools/Libs/grib2
  mkdir "${WRF_FOLDER}"/WRF_CHEM_Tools/Libs/NETCDF
  mkdir "${WRF_FOLDER}"/WRF_CHEM_Tools/Downloads
  mkdir "${WRF_FOLDER}"/WRF_CHEM_Tools/mozbc
  mkdir "${WRF_FOLDER}"/WRF_CHEM_Tools/megan_bio_emiss
  mkdir "${WRF_FOLDER}"/WRF_CHEM_Tools/megan_bio_data
  mkdir "${WRF_FOLDER}"/WRF_CHEM_Tools/wes_coldens
  mkdir "${WRF_FOLDER}"/WRF_CHEM_Tools/ANTHRO_EMIS
  mkdir "${WRF_FOLDER}"/WRF_CHEM_Tools/EDGAR_HTAP
  mkdir "${WRF_FOLDER}"/WRF_CHEM_Tools/EPA_ANTHRO_EMIS
  mkdir "${WRF_FOLDER}"/WRF_CHEM_Tools/UBC
  mkdir "${WRF_FOLDER}"/WRF_CHEM_Tools/Aircraft
  mkdir "${WRF_FOLDER}"/WRF_CHEM_Tools/FINN
  mkdir "${WRF_FOLDER}"/WRF_CHEM_Tools/Tests
  mkdir "${WRF_FOLDER}"/WRF_CHEM_Tools/Tests/Environment
  mkdir "${WRF_FOLDER}"/WRF_CHEM_Tools/Tests/Compatibility

  export DIR="${WRF_FOLDER}"/WRF_CHEM_Tools/Libs

  #############################Core Management####################################
  export CPU_CORE=$(sysctl -n hw.ncpu) # number of available threads on system
  export CPU_6CORE="6"
  export CPU_QUARTER=$(($CPU_CORE / 4))
  #1/2 of availble cores on system
  export CPU_QUARTER_EVEN=$(($CPU_QUARTER - ($CPU_QUARTER % 2)))
  #Forces CPU cores to even number to avoid partial core export. ie 7 cores would be 3.5 cores.

  if [ $CPU_CORE -le $CPU_6CORE ]; then #If statement for low core systems.  Forces computers to only use 1 core if there are 4 cores or less on the system. then
    export CPU_QUARTER_EVEN="2"
  else
    export CPU_QUARTER_EVEN=$(($CPU_QUARTER - ($CPU_QUARTER % 2)))
  fi

  echo "##########################################"
  echo "Number of Threads being used $CPU_QUARTER_EVEN"
  echo "##########################################"
  echo " "

  ##############################Downloading Libraries############################

  cd "${WRF_FOLDER}"/WRF_CHEM_Tools/Downloads
  wget -c https://github.com/madler/zlib/releases/download/v$Zlib_Version/zlib-$Zlib_Version.tar.gz
  wget -c https://github.com/HDFGroup/hdf5/releases/download/hdf5_$HDF5_Version/hdf5-$HDF5_Version.tar.gz
  wget -c https://github.com/Unidata/netcdf-c/archive/refs/tags/v$Netcdf_C_Version.tar.gz
  wget -c https://github.com/Unidata/netcdf-fortran/archive/refs/tags/v$Netcdf_Fortran_Version.tar.gz
  wget -c https://download.sourceforge.net/libpng/libpng-$Libpng_Version.tar.gz
  wget -c https://www.ece.uvic.ca/~frodo/jasper/software/jasper-$Jasper_Version.zip
  wget -c https://github.com/pmodels/mpich/releases/download/v$Mpich_Version/mpich-$Mpich_Version.tar.gz
  wget -c https://parallel-netcdf.github.io/Release/pnetcdf-$Pnetcdf_Version.tar.gz

  echo " "

  #############################Compilers############################
  # Unlink previous GCC, G++, and GFortran symlinks in Homebrew path to avoid conflicts
  echo $PASSWD | sudo -S unlink /opt/homebrew/bin/gfortran
  echo $PASSWD | sudo -S unlink /opt/homebrew/bin/gcc
  echo $PASSWD | sudo -S unlink /opt/homebrew/bin/g++

  # Source the bashrc to ensure environment variables are loaded
  source ~/.bashrc

  # Check current versions of gcc, g++, and gfortran (this should show no version if unlinked)
  gcc --version
  g++ --version
  gfortran --version

  # Navigate to the Homebrew binaries directory
  cd /opt/homebrew/bin

  # Find the latest version of GCC, G++, and GFortran
  latest_gcc=$(ls /opt/homebrew/bin/gcc-* 2> /dev/null | grep -o 'gcc-[0-9]*' | sort -V | tail -n 1)
  latest_gpp=$(ls /opt/homebrew/bin/g++-* 2> /dev/null | grep -o 'g++-[0-9]*' | sort -V | tail -n 1)
  latest_gfortran=$(ls /opt/homebrew/bin/gfortran-* 2> /dev/null | grep -o 'gfortran-[0-9]*' | sort -V | tail -n 1)

  # Display the chosen versions
  echo "Selected gcc version: $latest_gcc"
  echo "Selected g++ version: $latest_gpp"
  echo "Selected gfortran version: $latest_gfortran"

  export CC=/opt/homebrew/bin/$latest_gcc
  export CXX=/opt/homebrew/bin/$latest_gpp
  export FC=/opt/homebrew/bin/$latest_gfortran
  export F77=/opt/homebrew/bin/$latest_gfortran

  echo " "

  #IF statement for GNU compiler issue
  export GCC_VERSION=$(/opt/homebrew/bin/$latest_gcc -dumpfullversion | awk '{print$1}')
  export GFORTRAN_VERSION=$(/opt/homebrew/bin/$latest_gfortran -dumpfullversion | awk '{print$1}')
  export GPLUSPLUS_VERSION=$(/opt/homebrew/bin/$latest_gpp -dumpfullversion | awk '{print$1}')

  export GCC_VERSION_MAJOR_VERSION=$(echo $GCC_VERSION | awk -F. '{print $1}')
  export GFORTRAN_VERSION_MAJOR_VERSION=$(echo $GFORTRAN_VERSION | awk -F. '{print $1}')
  export GPLUSPLUS_VERSION_MAJOR_VERSION=$(echo $GPLUSPLUS_VERSION | awk -F. '{print $1}')

  export version_10="10"

  if [ $GCC_VERSION_MAJOR_VERSION -ge $version_10 ] || [ $GFORTRAN_VERSION_MAJOR_VERSION -ge $version_10 ] || [ $GPLUSPLUS_VERSION_MAJOR_VERSION -ge $version_10 ]; then
    export fallow_argument=-fallow-argument-mismatch
    export boz_argument=-fallow-invalid-boz
  else
    export fallow_argument=
    export boz_argument=
  fi

  export FFLAGS="$fallow_argument"
  export FCFLAGS="$fallow_argument"

  # Export compiler environment variables
  export CC=/usr/local/bin/gcc-13
  export CXX=/usr/local/bin/g++-13
  export FC=/usr/local/bin/gfortran-13
  export F77=/usr/local/bin/gfortran-13
  export CFLAGS="-fPIC -fPIE -Wno-implicit-function-declaration -Wno-incompatible-function-pointer-types -Wno-incompatible-pointer-types -Wall"

  # --- critical macOS SDK wiring for Homebrew GCC (fixes _bounds.h) ---
  export SDKROOT="$(xcrun --sdk macosx --show-sdk-path)"

  export CPPFLAGS="${CPPFLAGS:+$CPPFLAGS }--sysroot=\"$SDKROOT\" -isysroot \"$SDKROOT\""
  export CFLAGS="${CFLAGS:+$CFLAGS }--sysroot=\"$SDKROOT\" -isysroot \"$SDKROOT\""
  export CXXFLAGS="${CXXFLAGS:+$CXXFLAGS }--sysroot=\"$SDKROOT\" -isysroot \"$SDKROOT\""
  export LDFLAGS="${LDFLAGS:+$LDFLAGS }--sysroot=\"$SDKROOT\" -isysroot \"$SDKROOT\""

  echo "CC=$CC"
  echo "CXX=$CXX"
  echo "FC=$FC"
  echo "SDKROOT=$SDKROOT"
  echo "CFLAGS=$CFLAGS"
  echo "CPPFLAGS=$CPPFLAGS"
  echo "LDFLAGS=$LDFLAGS"

  #############################zlib############################
  #Uncalling compilers due to comfigure issue with zlib1.2.12
  #With CC & CXX definied ./configure uses different compiler Flags

  cd "${WRF_FOLDER}"/WRF_CHEM_Tools/Downloads
  env -u LD_LIBRARY_PATH tar -xzf zlib-$Zlib_Version.tar.gz
  cd zlib-$Zlib_Version/
  ./configure --prefix=$DIR/grib2 2>&1 | tee configure.log
  make -j $CPU_QUARTER_EVEN 2>&1 | tee make.log
  make -j $CPU_QUARTER_EVEN install 2>&1 | tee make.install.log

  echo " "

  ##############################MPICH############################
  cd "${WRF_FOLDER}"/WRF_CHEM_Tools/Downloads
  env -u LD_LIBRARY_PATH tar -xzf mpich-$Mpich_Version.tar.gz
  cd mpich-$Mpich_Version/"${WRF_FOLDER}"/WRF_CHEM_Tools/Tests/Compatibility
  F90= ./configure --prefix=$DIR/MPICH --with-device=ch3 FFLAGS=$FFLAGS FCFLAGS=$FCFLAGS 2>&1 | tee configure.log
  make -j $CPU_QUARTER_EVEN 2>&1 | tee make.log
  make -j $CPU_QUARTER_EVEN install 2>&1 | tee make.make.log

  export PATH=$DIR/MPICH/bin:$PATH

  export MPIFC=$DIR/MPICH/bin/mpifort
  export MPIF77=$DIR/MPICH/bin/mpifort
  export MPIF90=$DIR/MPICH/bin/mpifort
  export MPICC=$DIR/MPICH/bin/mpicc
  export MPICXX=$DIR/MPICH/bin/mpicxx

  echo " "

  #############################libpng############################
  cd "${WRF_FOLDER}"/WRF_CHEM_Tools/Downloads
  export LDFLAGS=-L$DIR/grib2/lib
  export CPPFLAGS=-I$DIR/grib2/include
  env -u LD_LIBRARY_PATH tar -xzf libpng-$Libpng_Version.tar.gz
  cd libpng-$Libpng_Version/
  CC=$MPICC FC=$MPIFC F77=$MPIF77 F90=$MPIF90 CXX=$MPICXX CFLAGS=$CFLAGS FFLAGS=$FFLAGS FCFLAGS=$FCFLAGS ./configure --prefix=$DIR/grib2 2>&1 | tee configure.log
  make -j $CPU_QUARTER_EVEN 2>&1 | tee make.log
  make -j $CPU_QUARTER_EVEN install 2>&1 | tee make.install.log

  echo " "
  #############################JasPer############################

  cd "${WRF_FOLDER}"/WRF_CHEM_Tools/Downloads
  unzip jasper-$Jasper_Version.zip
  cd jasper-$Jasper_Version/
  CC=$MPICC FC=$MPIFC F77=$MPIF77 F90=$MPIF90 CXX=$MPICXX CFLAGS=$CFLAGS FFLAGS=$FFLAGS FCFLAGS=$FCFLAGS ./configure --prefix=$DIR/grib2 2>&1 | tee configure.log
  make -j $CPU_QUARTER_EVEN 2>&1 | tee make.log
  make -j $CPU_QUARTER_EVEN install 2>&1 | tee make.install.log
  export JASPERLIB=$DIR/grib2/lib
  export JASPERINC=$DIR/grib2/include

  echo " "
  #############################hdf5 library for netcdf4 functionality############################

  cd "${WRF_FOLDER}"/WRF_CHEM_Tools/Downloads
  env -u LD_LIBRARY_PATH tar -xzf hdf5-$HDF5_Version.tar.gz
  cd hdf5-$HDF5_Version
  CC=$MPICC FC=$MPIFC F77=$MPIF77 F90=$MPIF90 CXX=$MPICXX CFLAGS=$CFLAGS FFLAGS=$FFLAGS FCFLAGS=$FCFLAGS ./configure --prefix=$DIR/grib2 --with-zlib=$DIR/grib2 --enable-hl --enable-fortran --enable-parallel 2>&1 | tee configure.log
  make -j $CPU_QUARTER_EVEN 2>&1 | tee make.log
  make -j $CPU_QUARTER_EVEN install 2>&1 | tee make.install.log

  export HDF5=$DIR/grib2
  export PHDF5=$DIR/grib2
  export LD_LIBRARY_PATH=$DIR/grib2/lib:$LD_LIBRARY_PATH

  echo " "

  #############################Install Parallel-netCDF##############################
  #Make file created with half of available cpu cores
  #Hard path for MPI added
  ##################################################################################
  cd "${WRF_FOLDER}"/WRF_CHEM_Tools/Downloads
  env -u LD_LIBRARY_PATH tar -xzf pnetcdf-$Pnetcdf_Version.tar.gz
  cd pnetcdf-$Pnetcdf_Version
  export MPIFC=$DIR/MPICH/bin/mpifort
  export MPIF77=$DIR/MPICH/bin/mpifort
  export MPIF90=$DIR/MPICH/bin/mpifort
  export MPICC=$DIR/MPICH/bin/mpicc
  export MPICXX=$DIR/MPICH/bin/mpicxx
  ./configure --prefix=$DIR/grib2 --enable-shared --enable-static 2>&1 | tee configure.log
  make -j $CPU_QUARTER_EVEN 2>&1 | tee make.log
  make -j $CPU_QUARTER_EVEN install 2>&1 | tee make.install.log

  export PNETCDF=$DIR/grib2

  ##############################Install NETCDF C Library############################
  cd "${WRF_FOLDER}"/WRF_CHEM_Tools/Downloads
  env -u LD_LIBRARY_PATH tar -xzf v$Netcdf_C_Version.tar.gz
  cd netcdf-c-$Netcdf_C_Version/
  export CPPFLAGS=-I$DIR/grib2/include
  export LDFLAGS=-L$DIR/grib2/lib
  export LIBS="-lhdf5_hl -lhdf5 -lz -lcurl -lgfortran -lgcc -lm -ldl -lpnetcdf"
  CC=$MPICC FC=$MPIFC F77=$MPIF77 F90=$MPIF90 CXX=$MPICXX CFLAGS=$CFLAGS FFLAGS=$FFLAGS FCFLAGS=$FCFLAGS ./configure --prefix=$DIR/NETCDF --disable-dap --enable-netcdf-4 --enable-netcdf4 --enable-shared --enable-static --enable-pnetcdf --enable-cdf5 --enable-parallel-tests 2>&1 | tee configure.log
  make -j $CPU_QUARTER_EVEN 2>&1 | tee make.log
  make -j $CPU_QUARTER_EVEN install 2>&1 | tee make.install.log

  export PATH=$DIR/NETCDF/bin:$PATH
  export NETCDF=$DIR/NETCDF
  echo " "

  ##############################NetCDF fortran library############################
  cd "${WRF_FOLDER}"/WRF_CHEM_Tools/Downloads
  env -u LD_LIBRARY_PATH tar -xzf v$Netcdf_Fortran_Version.tar.gz
  cd netcdf-fortran-$Netcdf_Fortran_Version/
  export LD_LIBRARY_PATH=$DIR/NETCDF/lib:$LD_LIBRARY_PATH
  export CPPFLAGS="-I$DIR/NETCDF/include -I$DIR/grib2/include"
  export LDFLAGS="-L$DIR/NETCDF/lib -L$DIR/grib2/lib"
  export LIBS="-lnetcdf -lpnetcdf -lcurl -lhdf5_hl -lhdf5 -lz -lm -ldl -lgcc -lgfortran"
  CC=$MPICC FC=$MPIFC F77=$MPIF77 F90=$MPIF90 CXX=$MPICXX CFLAGS=$CFLAGS FFLAGS=$FFLAGS FCFLAGS=$FCFLAGS ./configure --prefix=$DIR/NETCDF --enable-netcdf-4 --enable-netcdf4 --enable-shared --enable-static --enable-parallel-tests --enable-hdf5 2>&1 | tee configure.log
  make -j $CPU_QUARTER_EVEN 2>&1 | tee make.log
  make -j $CPU_QUARTER_EVEN install 2>&1 | tee make.install.log

  echo " "
  #################################### System Environment Tests ##############

  cd "${WRF_FOLDER}"/WRF_CHEM_Tools/Downloads
  wget -c https://www2.mmm.ucar.edu/wrf/OnLineTutorial/compile_tutorial/tar_files/Fortran_C_NETCDF_MPI_tests.tar
  wget -c https://www2.mmm.ucar.edu/wrf/OnLineTutorial/compile_tutorial/tar_files/Fortran_C_tests.tar

  env -u LD_LIBRARY_PATH tar -xvf Fortran_C_tests.tar -C "${WRF_FOLDER}"/WRF_CHEM_Tools/Tests/Environment
  env -u LD_LIBRARY_PATH tar -xvf Fortran_C_NETCDF_MPI_tests.tar -C "${WRF_FOLDER}"/WRF_CHEM_Tools/Tests/Compatibility

  export one="1"
  echo " "
  ############## Testing Environment #####

  cd "${WRF_FOLDER}"/WRF_CHEM_Tools/Tests/Environment

  cp ${NETCDF}/include/netcdf.inc .

  echo " "
  echo " "
  echo "Environment Testing "
  echo "Test 1"
  $FC TEST_1_fortran_only_fixed.f
  ./a.out | tee env_test1.txt
  export TEST_PASS=$(grep -w -o -c "SUCCESS" env_test1.txt | awk '{print$1}')
  if [ $TEST_PASS -ge 1 ]; then
    echo "Enviroment Test 1 Passed"
  else
    echo "Environment Compiler Test 1 Failed"
    exit
  fi
  read -r -t 3 -p "I am going to wait for 3 seconds only ..."

  echo " "
  echo "Test 2"
  $FC TEST_2_fortran_only_free.f90
  ./a.out | tee env_test2.txt
  export TEST_PASS=$(grep -w -o -c "SUCCESS" env_test2.txt | awk '{print$1}')
  if [ $TEST_PASS -ge 1 ]; then
    echo "Enviroment Test 2 Passed"
  else
    echo "Environment Compiler Test 2 Failed"
    exit
  fi
  echo " "
  read -r -t 3 -p "I am going to wait for 3 seconds only ..."

  echo " "
  echo "Test 3"
  $CC TEST_3_c_only.c
  ./a.out | tee env_test3.txt
  export TEST_PASS=$(grep -w -o -c "SUCCESS" env_test3.txt | awk '{print$1}')
  if [ $TEST_PASS -ge 1 ]; then
    echo "Enviroment Test 3 Passed"
  else
    echo "Environment Compiler Test 3 Failed"
    exit
  fi
  echo " "
  read -r -t 3 -p "I am going to wait for 3 seconds only ..."

  echo " "
  echo "Test 4"
  $CC -c -m64 TEST_4_fortran+c_c.c
  $FC -c -m64 TEST_4_fortran+c_f.f90
  $FC -m64 TEST_4_fortran+c_f.o TEST_4_fortran+c_c.o
  ./a.out | tee env_test4.txt
  export TEST_PASS=$(grep -w -o -c "SUCCESS" env_test4.txt | awk '{print$1}')
  if [ $TEST_PASS -ge 1 ]; then
    echo "Enviroment Test 4 Passed"
  else
    echo "Environment Compiler Test 4 Failed"
    exit
  fi
  echo " "
  read -r -t 3 -p "I am going to wait for 3 seconds only ..."

  echo " "
  ############## Testing Environment #####

  cd "${WRF_FOLDER}"/WRF_CHEM_Tools/Tests/Compatibility

  cp ${NETCDF}/include/netcdf.inc .

  echo " "
  echo " "
  echo "Library Compatibility Tests "
  echo "Test 1"
  $FC -c 01_fortran+c+netcdf_f.f
  $CC -c 01_fortran+c+netcdf_c.c
  $FC 01_fortran+c+netcdf_f.o 01_fortran+c+netcdf_c.o \
    -L${NETCDF}/lib -lnetcdff -lnetcdf

  ./a.out | tee comp_test1.txt
  export TEST_PASS=$(grep -w -o -c "SUCCESS" comp_test1.txt | awk '{print$1}')
  if [ $TEST_PASS -ge 1 ]; then
    echo "Compatibility Test 1 Passed"
  else
    echo "Compatibility Compiler Test 1 Failed"
    exit
  fi
  echo " "
  read -r -t 3 -p "I am going to wait for 3 seconds only ..."

  echo " "

  echo "Test 2"
  $MPIFC -c 02_fortran+c+netcdf+mpi_f.f
  $MPICC -c 02_fortran+c+netcdf+mpi_c.c
  $MPIFC 02_fortran+c+netcdf+mpi_f.o \
    02_fortran+c+netcdf+mpi_c.o \
    -L${NETCDF}/lib -lnetcdff -lnetcdf

  $DIR/MPICH/bin/mpirun ./a.out | tee comp_test2.txt
  export TEST_PASS=$(grep -w -o -c "SUCCESS" comp_test2.txt | awk '{print$1}')
  if [ $TEST_PASS -ge 1 ]; then
    echo "Compatibility Test 2 Passed"
  else
    echo "Compatibility Compiler Test 2 Failed"
    exit
  fi
  echo " "
  read -r -t 3 -p "I am going to wait for 3 seconds only ..."
  echo " "

  echo " All tests completed and passed"
  echo " "
  # Downloading WRF-CHEM Tools and untarring files
  cd "${WRF_FOLDER}"/WRF_CHEM_Tools/Downloads

  wget -c https://www.acom.ucar.edu/wrf-chem/mozbc.tar
  wget -c https://www.acom.ucar.edu/wrf-chem/UBC_inputs.tar
  wget -c https://www.acom.ucar.edu//wrf-chem/megan_bio_emiss.tar
  wget -c https://www.acom.ucar.edu/wrf-chem/megan.data.tar.gz
  wget -c https://www.acom.ucar.edu/wrf-chem/wes-coldens.tar
  wget -c https://www.acom.ucar.edu/wrf-chem/ANTHRO.tar
  wget -c https://www.acom.ucar.edu/webt/wrf-chem/processors/EDGAR-HTAP.tgz
  wget -c https://www.acom.ucar.edu/wrf-chem/EPA_ANTHRO_EMIS.tgz
  wget -c https://www2.acom.ucar.edu/sites/default/files/documents/aircraft_preprocessor_files.tar
  # Downloading FINN
  wget -c https://www.acom.ucar.edu/Data/fire/data/finn2/FINNv2.4_MOD_MOZART_2020_c20210617.txt.gz
  wget -c https://www.acom.ucar.edu/Data/fire/data/finn2/FINNv2.4_MOD_MOZART_2013_c20210617.txt.gz
  wget -c https://www.acom.ucar.edu/Data/fire/data/finn2/FINNv2.4_MODVRS_MOZART_2019_c20210615.txt.gz
  wget -c https://www.acom.ucar.edu/Data/fire/data/fire_emis.tgz
  wget -c https://www.acom.ucar.edu/Data/fire/data/fire_emis_input.tar
  wget -c https://www.acom.ucar.edu/Data/fire/data/TrashEmis.zip

  echo ""
  echo "Unpacking Mozbc."
  env -u LD_LIBRARY_PATH tar -xvf mozbc.tar -C "${WRF_FOLDER}"/WRF_CHEM_Tools/mozbc
  echo ""
  echo "Unpacking MEGAN Bio Emission."
  env -u LD_LIBRARY_PATH tar -xvf megan_bio_emiss.tar -C "${WRF_FOLDER}"/WRF_CHEM_Tools/megan_bio_emiss
  echo ""
  echo "Unpacking MEGAN Bio Emission Data."
  env -u LD_LIBRARY_PATH tar -xzf megan.data.tar.gz -C "${WRF_FOLDER}"/WRF_CHEM_Tools/megan_bio_data
  echo ""
  echo "Unpacking Wes Coldens"
  env -u LD_LIBRARY_PATH tar -xvf wes-coldens.tar -C "${WRF_FOLDER}"/WRF_CHEM_Tools/wes_coldens
  echo ""
  echo "Unpacking Unpacking ANTHRO Emission."
  env -u LD_LIBRARY_PATH tar -xvf ANTHRO.tar -C "${WRF_FOLDER}"/WRF_CHEM_Tools/ANTHRO_EMIS
  echo ""
  echo "Unpacking EDGAR-HTAP."
  env -u LD_LIBRARY_PATH tar -xzf EDGAR-HTAP.tgz -C "${WRF_FOLDER}"/WRF_CHEM_Tools/EDGAR_HTAP
  echo ""
  echo "Unpacking EPA ANTHRO Emission."
  env -u LD_LIBRARY_PATH tar -xzf EPA_ANTHRO_EMIS.tgz -C "${WRF_FOLDER}"/WRF_CHEM_Tools/EPA_ANTHRO_EMIS
  echo ""
  echo "Unpacking Upper Boundary Conditions."
  env -u LD_LIBRARY_PATH tar -xvf UBC_inputs.tar -C "${WRF_FOLDER}"/WRF_CHEM_Tools/UBC
  echo ""
  echo "Unpacking Aircraft Preprocessor Files."
  echo ""
  env -u LD_LIBRARY_PATH tar -xvf aircraft_preprocessor_files.tar -C "${WRF_FOLDER}"/WRF_CHEM_Tools/Aircraft
  echo ""
  echo "Unpacking Fire INventory from NCAR (FINN)"
  env -u LD_LIBRARY_PATH tar -xzf fire_emis.tgz -C "${WRF_FOLDER}"/WRF_CHEM_Tools/FINN
  env -u LD_LIBRARY_PATH tar -xvf fire_emis_input.tar
  env -u LD_LIBRARY_PATH tar -xzf grass_from_img.nc.tgz -C "${WRF_FOLDER}"/WRF_CHEM_Tools/FINN/grid_finn_fire_emis_v2020/src
  env -u LD_LIBRARY_PATH tar -xzf tempfor_from_img.nc.tgz -C "${WRF_FOLDER}"/WRF_CHEM_Tools/FINN/grid_finn_fire_emis_v2020/src
  env -u LD_LIBRARY_PATH tar -xzf shrub_from_img.nc.tgz -C "${WRF_FOLDER}"/WRF_CHEM_Tools/FINN/grid_finn_fire_emis_v2020/src
  env -u LD_LIBRARY_PATH tar -xzf tropfor_from_img.nc.tgz -C "${WRF_FOLDER}"/WRF_CHEM_Tools/FINN/grid_finn_fire_emis_v2020/src

  mv "${WRF_FOLDER}"/WRF_CHEM_Tools/Downloads/FINNv2.4_MOD_MOZART_2020_c20210617.txt.gz "${WRF_FOLDER}"/WRF_CHEM_Tools/FINN
  mv "${WRF_FOLDER}"/WRF_CHEM_Tools/Downloads/FINNv2.4_MOD_MOZART_2013_c20210617.txt.gz "${WRF_FOLDER}"/WRF_CHEM_Tools/FINN
  mv "${WRF_FOLDER}"/WRF_CHEM_Tools/Downloads/FINNv2.4_MODVRS_MOZART_2019_c20210615.txt.gz "${WRF_FOLDER}"/WRF_CHEM_Tools/FINN

  unzip TrashEmis.zip
  mv "${WRF_FOLDER}"/WRF_CHEM_Tools/Downloads/ALL_Emiss_04282014.nc "${WRF_FOLDER}"/WRF_CHEM_Tools/FINN/grid_finn_fire_emis_v2020/src

  cd "${WRF_FOLDER}"/WRF_CHEM_Tools/FINN

  gunzip FINNv2.4_MOD_MOZART_2020_c20210617.txt.gz
  gunzip FINNv2.4_MOD_MOZART_2013_c20210617.txt.gz
  gunzip FINNv2.4_MODVRS_MOZART_2019_c20210615.txt.gz
  ############################Installation of Mozbc #############################
  export fallow_argument=-fallow-argument-mismatch
  export boz_argument=-fallow-invalid-boz

  # Recalling variables from install script to make sure the path is right

  cd "${WRF_FOLDER}"/WRF_CHEM_Tools/mozbc
  chmod +x make_mozbc
  export DIR="${WRF_FOLDER}"/WRF_CHEM_Tools/Libs
  export FC=gfortran
  export NETCDF_DIR=$DIR/NETCDF
  sed -i'' -e 's/"${ar_libs} -lnetcdff"/"-lnetcdff ${ar_libs}"/' make_mozbc
  sed -i'' -e '8s/FFLAGS = --g/FFLAGS = --g ${fallow_argument}/' Makefile
  sed -i'' -e '10s/FFLAGS = -g/FFLAGS = -g ${fallow_argument}/' Makefile
  ./make_mozbc 2>&1 | tee make.log

  ################## Information on Upper Boundary Conditions ###################

  cd "${WRF_FOLDER}"/WRF_CHEM_Tools/UBC/
  wget -c https://www2.acom.ucar.edu/sites/default/files/documents/8A_2_Barth_WRFWorkshop_11.pdf

  ########################## MEGAN Bio Emission #################################
  # Data for MEGAN Bio Emission located in
  # "${WRF_FOLDER}"/WRF_CHEM_Tools/megan_bio_data

  cd "${WRF_FOLDER}"/WRF_CHEM_Tools/megan_bio_emiss
  chmod +x make_util
  export DIR="${WRF_FOLDER}"/WRF_CHEM_Tools/Libs
  export FC=gfortran
  export NETCDF_DIR=$DIR/NETCDF
  sed -i'' -e 's/"${ar_libs} -lnetcdff"/"-lnetcdff ${ar_libs}"/' make_util
  sed -i'' -e '8s/FFLAGS = --g/FFLAGS = --g ${fallow_argument}/' Makefile
  sed -i'' -e '10s/FFLAGS = -g/FFLAGS = -g ${fallow_argument}/' Makefile
  ./make_util megan_bio_emiss 2>&1 | tee make.bio.log
  ./make_util megan_xform 2>&1 | tee make.xform.log
  ./make_util surfdata_xform 2>&1 | tee make.surfdata.log

  ############################# Anthroprogenic Emissions #########################

  cd "${WRF_FOLDER}"/WRF_CHEM_Tools/ANTHRO_EMIS/ANTHRO/src
  chmod +x make_anthro
  export DIR="${WRF_FOLDER}"/WRF_CHEM_Tools/Libs
  export FC=gfortran
  export NETCDF_DIR=$DIR/NETCDF
  sed -i'' -e 's/"${ar_libs} -lnetcdff"/"-lnetcdff ${ar_libs}"/' make_anthro
  sed -i'' -e '8s/FFLAGS = --g/FFLAGS = --g ${fallow_argument}/' Makefile
  sed -i'' -e '10s/FFLAGS = -g/FFLAGS = -g ${fallow_argument}/' Makefile
  ./make_anthro 2>&1 | tee make.log

  ############################# EDGAR HTAP ######################################
  #  This directory contains EDGAR-HTAP anthropogenic emission files for the
  #  year 2010.  The files are in the MOZCART and MOZART-MOSAIC sub-directories.
  #  The MOZCART files are intended to be used for the WRF MOZCART_KPP chemical
  #  option.  The MOZART-MOSAIC files are intended to be used with the following
  #  WRF chemical options (See read -rme in Folder

  ######################### EPA Anthroprogenic Emissions ########################
  cd "${WRF_FOLDER}"/WRF_CHEM_Tools/EPA_ANTHRO_EMIS/src
  chmod +x make_anthro
  export DIR="${WRF_FOLDER}"/WRF_CHEM_Tools/Libs
  export FC=gfortran
  export NETCDF_DIR=$DIR/NETCDF
  sed -i'' -e 's/"${ar_libs} -lnetcdff"/"-lnetcdff ${ar_libs}"/' make_anthro
  sed -i'' -e '8s/FFLAGS = --g/FFLAGS = --g ${fallow_argument}/' Makefile
  sed -i'' -e '10s/FFLAGS = -g/FFLAGS = -g ${fallow_argument}/' Makefile
  ./make_anthro 2>&1 | tee make.log

  ######################### Weseley EXO Coldens ##################################
  cd "${WRF_FOLDER}"/WRF_CHEM_Tools/wes_coldens
  chmod +x make_util
  export DIR="${WRF_FOLDER}"/WRF_CHEM_Tools/Libs
  export FC=gfortran
  export NETCDF_DIR=$DIR/NETCDF
  sed -i'' -e 's/"${ar_libs} -lnetcdff"/"-lnetcdff ${ar_libs}"/' make_util
  sed -i'' -e '8s/FFLAGS = --g/FFLAGS = --g ${fallow_argument}/' Makefile
  sed -i'' -e '10s/FFLAGS = -g/FFLAGS = -g ${fallow_argument}/' Makefile
  ./make_util wesely 2>&1 | tee make.wesley.log
  ./make_util exo_coldens 2>&1 | tee make.exo.log

  ########################## Aircraft Emissions Preprocessor #####################
  # This is an IDL based preprocessor to create WRF-Chem read -ry aircraft emissions files
  # (wrfchemaircraft_) from a global inventory in netcdf format. Please consult the read -rME file
  # for how to use the preprocessor. The emissions inventory is not included, so the user must
  # provide their own.
  echo " "
  echo "######################################################################"
  echo " Please see script for details about Aircraft Emissions Preprocessor"
  echo "######################################################################"
  echo " "

  ######################## Fire INventory from NCAR (FINN) ###########################
  # Fire INventory from NCAR (FINN): A daily fire emissions product for atmospheric chemistry models
  # https://www2.acom.ucar.edu/modeling/finn-fire-inventory-ncar
  echo " "
  echo "###########################################"
  echo " Please see folder for details about FINN."
  echo "###########################################"
  echo " "
  #####################################BASH Script Finished##############################
  echo " "
  echo "WRF CHEM Tools compiled with latest version of NETCDF files available on 03/01/2025"
  echo "If error occurs using WRFCHEM tools please update your NETCDF libraries or reconfigure with older libraries"
  echo "This is a WRC Chem Community tool made by a private user and is not supported by UCAR/NCAR"
  echo "BASH Script Finished"

fi

#####################################BASH Script Finished##############################

end=$(date)
END=$(date +"%s")
DIFF=$(($END - $START))
echo "Install Start Time: ${start}"
echo "Install End Time: ${end}"
echo "Install Duration: $(($DIFF / 3600)) hours $((($DIFF % 3600) / 60)) minutes $(($DIFF % 60)) seconds"
echo ""
echo ""
############################### Citation Requirement  ####################
echo " "
echo " The GitHub software WRF-MOSIT (Version 2.1.1) by W. Hatheway (2023)"
echo " "
echo "It is important to note that any usage or publication that incorporates or references this software must include a proper citation to acknowledge the work of the author."
echo " "
echo -e "This is not only a matter of respect and academic integrity, but also a \e[31mrequirement\e[0m set by the author. Please ensure to adhere to this guideline when using this software."
echo " "
echo -e "\e[31mCitation: Hatheway, W., Snoun, H., ur Rehman, H., & Mwanthi, A. WRF-MOSIT: a modular and cross-platform tool for configuring and installing the WRF model [Computer software]. https://doi.org/10.1007/s12145-023-01136-y]\e[0m"

echo " "
read -p "Press enter to continue"

