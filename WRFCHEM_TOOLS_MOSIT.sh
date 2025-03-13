#!/bin/bash

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
export HDF5_Version=1.14.4
export HDF5_Sub_Version=3
export Zlib_Version=1.3.1
export Netcdf_C_Version=4.9.2
export Netcdf_Fortran_Version=4.6.1
export Mpich_Version=4.2.3
export Libpng_Version=1.6.39
export Jasper_Version=1.900.1
export Pnetcdf_Version=1.13.0

############################### System Architecture Type #################
# Determine if the system is 32 or 64-bit based on the architecture
##########################################################################
export SYS_ARCH=$(uname -m)

if [ "$SYS_ARCH" = "x86_64" ] || [ "$SYS_ARCH" = "arm64" ]; then
	export SYSTEMBIT="64"
else
	export SYSTEMBIT="32"
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
#################################################################
if [ "$SYSTEMOS" = "Linux" ]; then
	if [ -f /etc/os-release ]; then
		# Extract the distribution name and version from /etc/os-release
		export DISTRO_NAME=$(grep -w "NAME" /etc/os-release | cut -d'=' -f2 | tr -d '"')
		export DISTRO_VERSION=$(grep -w "VERSION_ID" /etc/os-release | cut -d'=' -f2 | tr -d '"')

		echo "Operating system detected: $DISTRO_NAME, Version: $DISTRO_VERSION"

	 # Check if dnf or yum is installed (dnf is used on newer systems, yum on older ones)
        if command -v dnf >/dev/null 2>&1; then
            echo "dnf is installed."
            export SYSTEMOS="RHL"  # Set SYSTEMOS to RHL if dnf is detected
        elif command -v yum >/dev/null 2>&1; then
            echo "yum is installed."
            export SYSTEMOS="RHL"  # Set SYSTEMOS to RHL if yum is detected
        else
            echo "No package manager (dnf or yum) found."
        fi
	else
		echo "Unable to detect the Linux distribution version."
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
        echo "Your system is a 64-bit version of RHL Based Linux Kernel."
        echo "Intel compilers are not compatible with this script."
        echo "Setting compiler to GNU."
        export RHL_64bit_GNU=1
        echo "RHL_64bit_GNU=$RHL_64bit_GNU"

        # Check for the version of the GNU compiler (gcc)
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
# Check for 64-bit Linux system (Debian/Ubuntu)
if [ "$SYSTEMBIT" = "64" ] && [ "$SYSTEMOS" = "Linux" ]; then
	echo "Your system is a 64-bit version of Debian Linux Kernel."
	echo ""

	# Check if Ubuntu_64bit_Intel or Ubuntu_64bit_GNU environment variables are set
	if [ -n "$Ubuntu_64bit_Intel" ] || [ -n "$Ubuntu_64bit_GNU" ]; then
		echo "The environment variable Ubuntu_64bit_Intel/GNU is already set."
	else
		echo "The environment variable Ubuntu_64bit_Intel/GNU is not set."

		# Prompt user to select a compiler (Intel or GNU)
		while read -r -p "Which compiler do you want to use?
            - Intel
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
	echo "Setting compiler to GNU..."

	# Check if macos_64bit_GNU environment variable is set
	if [ -v macos_64bit_GNU ]; then
		echo "The environment variable macos_64bit_GNU is already set."
	else
		echo "Setting environment variable macos_64bit_GNU."
		export macos_64bit_GNU=1

		# Ensure Xcode Command Line Tools are installed
		if ! xcode-select --print-path &>/dev/null; then
			echo "Installing Xcode Command Line Tools..."
			xcode-select --install
		fi

		# Install Homebrew for Intel Macs in /usr/local
		echo "Installing Homebrew..."
		/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"

		echo 'eval "$(/usr/local/bin/brew shellenv)"' >>~/.profile
		eval "$(/usr/local/bin/brew shellenv)"

		chsh -s /bin/bash
	fi
fi

# Check for 64-bit ARM-based MacOS system (M1, M2 chips)
if [ "$SYSTEMBIT" = "64" ] && [ "$SYSTEMOS" = "MacOS" ] && [ "$MAC_CHIP" = "ARM" ]; then
	echo "Your system is a 64-bit version of macOS with an ARM chip (M1/M2)."
	echo "Intel compilers are not compatible with this script."
	echo "Setting compiler to GNU..."

	# Check if macos_64bit_GNU environment variable is set
	if [ -v macos_64bit_GNU ]; then
		echo "The environment variable macos_64bit_GNU is already set."
	else
		echo "Setting environment variable macos_64bit_GNU."
		export macos_64bit_GNU=1

		# Ensure Xcode Command Line Tools are installed
		if ! xcode-select --print-path &>/dev/null; then
			echo "Installing Xcode Command Line Tools..."
			xcode-select --install
		fi

		# Install Homebrew for ARM Macs in /opt/homebrew
		echo "Installing Homebrew..."
		/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"

		echo 'eval "$(/opt/homebrew/bin/brew shellenv)"' >>~/.profile
		eval "$(/opt/homebrew/bin/brew shellenv)"

		chsh -s /bin/bash
	fi
fi

############################# Enter sudo users information #############################
echo "--------------------------------------------------"
if [[ -n "$PASSWD" ]]; then
	echo "Using existing password."
	echo "--------------------------------------------------"
else
	while true; do
		echo -e "\nPassword is only saved locally and will not be seen when typing."
		# Prompt for the initial password
		read -r -s -p "Please enter your sudo password: " password1
		echo -e "\nPlease re-enter your password to verify:"
		# Prompt for password verification
		read -r -s password2

		# Check if the passwords match
		if [[ "$password1" == "$password2" ]]; then
			export PASSWD=$password1
			echo -e "\n--------------------------------------------------"
			echo "Password verified successfully."
			break
		else
			echo -e "\n--------------------------------------------------"
			echo "Passwords do not match. Please enter the passwords again."
			echo "--------------------------------------------------"
		fi
	done
	echo -e "\nBeginning Installation\n"
fi

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
		cd
		pwd
	)

	#Basic Package Management for Model Evaluation Tools (MET)
	echo $PASSWD | sudo -S yum install epel-release -y
	echo $PASSWD | sudo -S yum install dnf -y
	echo $PASSWD | sudo -S dnf install epel-release -y
	echo $PASSWD | sudo -S dnf -y update
	echo $PASSWD | sudo -S dnf -y upgrade
	echo $PASSWD | sudo -S dnf -y install gcc gcc-gfortran gcc-c++ cpp automake autoconf unzip java-11-openjdk java-11-openjdk-devel bzip2 time nfs-utils perl tcsh ksh git python3 mlocate wget git m4 pkgconfig mlocate libX11-devel libxml2 unzip bzip2 time nfs-utils perl tcsh wget m4 mlocate libX11-devel.x86_64 libXext-devel libXrender-devel fontconfig-devel libXext-devel libXrender-devel fontconfig-devel curl-devel cmake cairo-devel pixman-devel bzip2-devel byacc flex libXmu-devel libXt-devel libXaw libXaw-devel python3 python3-devel libXmu-devel curl-devel m4 bzip2 time nfs-utils perl tcsh mlocate libX11-devel libxml2
	echo $PASSWD | sudo -S dnf -y install python3-dateutil
	echo $PASSWD | sudo -S dnf -y groupinstall "Development Tools"
	echo $PASSWD | sudo -S dnf -y update
	echo $PASSWD | sudo -S dnf -y upgrade
	echo " "

	#Directory Listings
	export HOME=$(
		cd
		pwd
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
	wget -c https://github.com/HDFGroup/hdf5/releases/download/hdf5_$HDF5_Version.$HDF5_Sub_Version/hdf5-$HDF5_Version-$HDF5_Sub_Version.tar.gz
	wget -c https://github.com/Unidata/netcdf-c/archive/refs/tags/v$Netcdf_C_Version.tar.gz
	wget -c https://github.com/Unidata/netcdf-fortran/archive/refs/tags/v$Netcdf_Fortran_Version.tar.gz
	wget -c https://download.sourceforge.net/libpng/libpng-$Libpng_Version.tar.gz
	wget -c https://www.ece.uvic.ca/~frodo/jasper/software/jasper-$Jasper_Version.zip
	wget -c https://github.com/pmodels/mpich/releases/download/v$Mpich_Version/mpich-$Mpich_Version.tar.gz
	wget -c https://parallel-netcdf.github.io/Release/pnetcdf-$Pnetcdf_Version.tar.gz

	#############################Core Management####################################
	export CPU_CORE=$(nproc) # number of available threads on system
	export CPU_6CORE="6"
	export CPU_HALF=$(($CPU_CORE / 2))                    #half of availble cores on system
	export CPU_HALF_EVEN=$(($CPU_HALF - ($CPU_HALF % 2))) #Forces CPU cores to even number to avoid partial core export. ie 7 cores would be 3.5 cores.

	if [ $CPU_CORE -le $CPU_6CORE ]; then #If statement for low core systems.  Forces computers to only use 1 core if there are 4 cores or less on the system. then
		export CPU_HALF_EVEN="2"
	else
		export CPU_HALF_EVEN=$(($CPU_HALF - ($CPU_HALF % 2)))
	fi

	echo "##########################################"
	echo "Number of threads being used $CPU_HALF_EVEN"
	echo "##########################################"
	echo " "

	#############################Compilers############################
	export DIR="${WRF_FOLDER}"/WRF_CHEM_Tools/Libs
	export CC=gcc
	export CXX=g++
	export FC=gfortran
	export F77=gfortran
	export CFLAGS="-fPIC -fPIE -m64"

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

	export FFLAGS="$fallow_argumen"
	export FCFLAGS="$fallow_argumen"

	echo "##########################################"
	echo "FFLAGS = $FFLAGS"
	echo "FCFLAGS = $FCFLAGS"
	echo "CFLAGS = $CFLAGS"
	echo "##########################################"

	#############################zlib############################
	#Uncalling compilers due to comfigure issue with zlib$Zlib_Version
	#With CC & CXX definied ./configure uses different compiler Flags

	cd "${WRF_FOLDER}"/WRF_CHEM_Tools/Downloads
	tar -xvzf zlib-$Zlib_Version.tar.gz
	cd zlib-$Zlib_Version/
	autoreconf -i -f 2>&1 | tee autoreconf.log
	./configure --prefix=$DIR/grib2 2>&1 | tee configure.log
	automake -a -f 2>&1 | tee automake.log
	make -j $CPU_HALF_EVEN 2>&1 | tee make.log
	make -j $CPU_HALF_EVEN install 2>&1 | tee make.make.log
	#make check

	##############################MPICH############################
	cd "${WRF_FOLDER}"/WRF_CHEM_Tools/Downloads
	tar -xvzf mpich-$Mpich_Version.tar.gz
	cd mpich-$Mpich_Version/
	autoreconf -i -f 2>&1 | tee autoreconf.log
	F90= ./configure --prefix=$DIR/MPICH --with-device=ch3 FFLAGS=$FFLAGS FCFLAGS=$FCFLAGS 2>&1 | tee configure.log
	automake -a -f 2>&1 | tee automake.log
	make -j $CPU_HALF_EVEN 2>&1 | tee make.log
	make -j $CPU_HALF_EVEN install 2>&1 | tee make.make.log
	#make check

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
	tar -xvzf libpng-$Libpng_Version.tar.gz
	cd libpng-$Libpng_Version/
	autoreconf -i -f 2>&1 | tee autoreconf.log
	CC=$MPICC FC=$MPIFC F77=$MPIF77 F90=$MPIF90 CXX=$MPICXX CFLAGS=$CFLAGS FFLAGS=$FFLAGS FCFLAGS=$FCFLAGS ./configure --prefix=$DIR/grib2 2>&1 | tee configure.log
	automake -a -f 2>&1 | tee automake.log
	make -j $CPU_HALF_EVEN 2>&1 | tee make.log
	make -j $CPU_HALF_EVEN install 2>&1 | tee make.make.log
	#make check

	#############################JasPer############################
	cd "${WRF_FOLDER}"/WRF_CHEM_Tools/Downloads
	unzip jasper-$Jasper_Version.zip
	cd jasper-$Jasper_Version/
	autoreconf -i -f 2>&1 | tee autoreconf.log
	CC=$MPICC FC=$MPIFC F77=$MPIF77 F90=$MPIF90 CXX=$MPICXX CFLAGS=$CFLAGS FFLAGS=$FFLAGS FCFLAGS=$FCFLAGS ./configure --prefix=$DIR/grib2 2>&1 | tee configure.log
	automake -a -f 2>&1 | tee automake.log
	make -j $CPU_HALF_EVEN 2>&1 | tee make.log
	make -j $CPU_HALF_EVEN install 2>&1 | tee make.make.log

	export JASPERLIB=$DIR/grib2/lib
	export JASPERINC=$DIR/grib2/include

	#############################hdf5 library for netcdf4 functionality############################
	cd "${WRF_FOLDER}"/WRF_CHEM_Tools/Downloads
	tar -xvzf hdf5-$HDF5_Version-$HDF5_Sub_Version.tar.gz
	cd hdf5-$HDF5_Version-$HDF5_Sub_Version
	autoreconf -i -f 2>&1 | tee autoreconf.log
	CC=$MPICC FC=$MPIFC F77=$MPIF77 F90=$MPIF90 CXX=$MPICXX CFLAGS=$CFLAGS FFLAGS=$FFLAGS FCFLAGS=$FCFLAGS ./configure --prefix=$DIR/grib2 --with-zlib=$DIR/grib2 --enable-hl --enable-fortran --enable-parallel 2>&1 | tee configure.log
	automake -a -f 2>&1 | tee automake.log
	make -j $CPU_HALF_EVEN 2>&1 | tee make.log
	make -j $CPU_HALF_EVEN install 2>&1 | tee make.make.log
	#make check

	export HDF5=$DIR/grib2
	export PHDF5=$DIR/grib2
	export LD_LIBRARY_PATH=$DIR/grib2/lib:$LD_LIBRARY_PATH

	echo " "

	#############################Install Parallel-netCDF##############################
	#Make file created with half of available cpu cores
	#Hard path for MPI added
	##################################################################################
	cd "${WRF_FOLDER}"/WRF_CHEM_Tools/Downloads
	tar -xvzf pnetcdf-$Pnetcdf_Version.tar.gz
	cd pnetcdf-$Pnetcdf_Version
	autoreconf -i -f 2>&1 | tee autoreconf.log
	CC=$MPICC FC=$MPIFC F77=$MPIF77 F90=$MPIF90 CXX=$MPICXX CFLAGS=$CFLAGS FFLAGS=$FFLAGS FCFLAGS=$FCFLAGS ./configure --prefix=$DIR/grib2 --enable-shared --enable-static 2>&1 | tee configure.log
	automake -a -f 2>&1 | tee automake.log
	make -j $CPU_HALF_EVEN 2>&1 | tee make.log
	make -j $CPU_HALF_EVEN install 2>&1 | tee make.make.log
	#make check

	export PNETCDF=$DIR/grib2

	##############################Install NETCDF C Library############################
	cd "${WRF_FOLDER}"/WRF_CHEM_Tools/Downloads
	tar -xzvf v$Netcdf_C_Version.tar.gz
	cd netcdf-c-$Netcdf_C_Version/
	export CPPFLAGS=-I$DIR/grib2/include
	export LDFLAGS=-L$DIR/grib2/lib
	export LIBS="-lhdf5_hl -lhdf5 -lz -lcurl -lgfortran -lgcc -lm -ldl -lpnetcdf"
	autoreconf -i -f 2>&1 | tee autoreconf.log
	CC=$MPICC FC=$MPIFC F77=$MPIF77 F90=$MPIF90 CXX=$MPICXX CFLAGS=$CFLAGS FFLAGS=$FFLAGS FCFLAGS=$FCFLAGS ./configure --prefix=$DIR/NETCDF --with-zlib=$DIR/grib2 --disable-dap --enable-netcdf-4 --enable-netcdf4 --enable-shared --enable-static --enable-pnetcdf --enable-cdf5 --enable-parallel-tests 2>&1 | tee configure.log
	automake -a -f 2>&1 | tee automake.log
	make -j $CPU_HALF_EVEN 2>&1 | tee make.log
	make -j $CPU_HALF_EVEN install 2>&1 | tee make.make.log
	#make check

	export PATH=$DIR/NETCDF/bin:$PATH
	export NETCDF=$DIR/NETCDF

	##############################NetCDF fortran library############################
	cd "${WRF_FOLDER}"/WRF_CHEM_Tools/Downloads
	tar -xvzf v$Netcdf_Fortran_Version.tar.gz
	cd netcdf-fortran-$Netcdf_Fortran_Version/
	export LD_LIBRARY_PATH=$DIR/NETCDF/lib:$LD_LIBRARY_PATH
	export CPPFLAGS="-I$DIR/NETCDF/include -I$DIR/grib2/include"
	export LDFLAGS="-L$DIR/NETCDF/lib -L$DIR/grib2/lib"
	export LIBS="-lnetcdf -lpnetcdf -lcurl -lhdf5_hl -lhdf5 -lz -ldl -lgcc -lgfortran"
	autoreconf -i -f 2>&1 | tee autoreconf.log
	CC=$MPICC FC=$MPIFC F77=$MPIF77 F90=$MPIF90 CXX=$MPICXX CFLAGS=$CFLAGS FFLAGS=$FFLAGS FCFLAGS=$FCFLAGS ./configure --prefix=$DIR/NETCDF --enable-netcdf-4 --enable-netcdf4 --enable-shared --enable-static --enable-parallel-tests --enable-hdf5 2>&1 | tee configure.log
	automake -a -f 2>&1 | tee automake.log
	make -j $CPU_HALF_EVEN 2>&1 | tee make.log
	make -j $CPU_HALF_EVEN install 2>&1 | tee make.make.log
	#make check

	echo " "

	#################################### System Environment Tests ##############

	cd "${WRF_FOLDER}"/WRF_CHEM_Tools/Downloads
	wget -c https://www2.mmm.ucar.edu/wrf/OnLineTutorial/compile_tutorial/tar_files/Fortran_C_NETCDF_MPI_tests.tar
	wget -c https://www2.mmm.ucar.edu/wrf/OnLineTutorial/compile_tutorial/tar_files/Fortran_C_tests.tar

	tar -xvf Fortran_C_tests.tar -C "${WRF_FOLDER}"/WRF_CHEM_Tools/Tests/Environment
	tar -xvf Fortran_C_NETCDF_MPI_tests.tar -C "${WRF_FOLDER}"/WRF_CHEM_Tools/Tests/Compatibility

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
	tar -xvf mozbc.tar -C "${WRF_FOLDER}"/WRF_CHEM_Tools/mozbc
	echo ""
	echo "Unpacking MEGAN Bio Emission."
	tar -xvf megan_bio_emiss.tar -C "${WRF_FOLDER}"/WRF_CHEM_Tools/megan_bio_emiss
	echo ""
	echo "Unpacking MEGAN Bio Emission Data."
	tar -xzvf megan.data.tar.gz -C "${WRF_FOLDER}"/WRF_CHEM_Tools/megan_bio_data
	echo ""
	echo "Unpacking Wes Coldens"
	tar -xvf wes-coldens.tar -C "${WRF_FOLDER}"/WRF_CHEM_Tools/wes_coldens
	echo ""
	echo "Unpacking Unpacking ANTHRO Emission."
	tar -xvf ANTHRO.tar -C "${WRF_FOLDER}"/WRF_CHEM_Tools/ANTHRO_EMIS
	echo ""
	echo "Unpacking EDGAR-HTAP."
	tar -xzvf EDGAR-HTAP.tgz -C "${WRF_FOLDER}"/WRF_CHEM_Tools/EDGAR_HTAP
	echo ""
	echo "Unpacking EPA ANTHRO Emission."
	tar -xzvf EPA_ANTHRO_EMIS.tgz -C "${WRF_FOLDER}"/WRF_CHEM_Tools/EPA_ANTHRO_EMIS
	echo ""
	echo "Unpacking Upper Boundary Conditions."
	tar -xvf UBC_inputs.tar -C "${WRF_FOLDER}"/WRF_CHEM_Tools/UBC
	echo ""
	echo "Unpacking Aircraft Preprocessor Files."
	echo ""
	tar -xvf aircraft_preprocessor_files.tar -C "${WRF_FOLDER}"/WRF_CHEM_Tools/Aircraft
	echo ""
	echo "Unpacking Fire INventory from NCAR (FINN)"
	tar -xzvf fire_emis.tgz -C "${WRF_FOLDER}"/WRF_CHEM_Tools/FINN
	tar -xvf fire_emis_input.tar
	tar -zxvf grass_from_img.nc.tgz -C "${WRF_FOLDER}"/WRF_CHEM_Tools/FINN/grid_finn_fire_emis_v2020/src
	tar -zxvf tempfor_from_img.nc.tgz -C "${WRF_FOLDER}"/WRF_CHEM_Tools/FINN/grid_finn_fire_emis_v2020/src
	tar -zxvf shrub_from_img.nc.tgz -C "${WRF_FOLDER}"/WRF_CHEM_Tools/FINN/grid_finn_fire_emis_v2020/src
	tar -zxvf tropfor_from_img.nc.tgz -C "${WRF_FOLDER}"/WRF_CHEM_Tools/FINN/grid_finn_fire_emis_v2020/src

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

	wget -4 -c http://ftp.cptec.inpe.br/pesquisa/bramsrd/BRAMS_5.4/PREP-CHEM/PREP-CHEM-SRC-1.5.tar.gz

	tar -xzvf PREP-CHEM-SRC-1.5.tar.gz -C "${WRF_FOLDER}"/WRF_CHEM_Tools/PREP-CHEM-SRC-1.5

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
		cd
		pwd
	)

	#Basic Package Management for Model Evaluation Tools (MET)
	echo $PASSWD | sudo -S yum install epel-release -y
	echo $PASSWD | sudo -S yum install dnf -y
	echo $PASSWD | sudo -S dnf install epel-release -y
	echo $PASSWD | sudo -S dnf -y update
	echo $PASSWD | sudo -S dnf -y upgrade
	echo $PASSWD | sudo -S dnf -y install gcc gcc-gfortran gcc-c++ cpp automake autoconf unzip java-11-openjdk java-11-openjdk-devel bzip2 time nfs-utils perl tcsh ksh git python3 mlocate wget git m4 pkgconfig mlocate libX11-devel libxml2 unzip bzip2 time nfs-utils perl tcsh wget m4 mlocate libX11-devel.x86_64 libXext-devel libXrender-devel fontconfig-devel libXext-devel libXrender-devel fontconfig-devel curl-devel cmake cairo-devel pixman-devel bzip2-devel byacc flex libXmu-devel libXt-devel libXaw libXaw-devel python3 python3-devel libXmu-devel curl-devel m4 bzip2 time nfs-utils perl tcsh mlocate libX11-devel libxml2
	echo $PASSWD | sudo -S dnf -y install python3-dateutil

	echo $PASSWD | sudo -S dnf -y groupinstall "Development Tools"
	echo $PASSWD | sudo -S dnf -y update
	echo $PASSWD | sudo -S dnf -y upgrade
	echo " "

	#Directory Listings
	export HOME=$(
		cd
		pwd
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
	wget -c https://github.com/HDFGroup/hdf5/releases/download/hdf5_$HDF5_Version.$HDF5_Sub_Version/hdf5-$HDF5_Version-$HDF5_Sub_Version.tar.gz
	wget -c https://github.com/Unidata/netcdf-c/archive/refs/tags/v$Netcdf_C_Version.tar.gz
	wget -c https://github.com/Unidata/netcdf-fortran/archive/refs/tags/v$Netcdf_Fortran_Version.tar.gz
	wget -c https://download.sourceforge.net/libpng/libpng-$Libpng_Version.tar.gz
	wget -c https://www.ece.uvic.ca/~frodo/jasper/software/jasper-$Jasper_Version.zip
	wget -c https://github.com/pmodels/mpich/releases/download/v$Mpich_Version/mpich-$Mpich_Version.tar.gz
	wget -c https://parallel-netcdf.github.io/Release/pnetcdf-$Pnetcdf_Version.tar.gz

	#############################Core Management####################################
	export CPU_CORE=$(nproc) # number of available threads on system
	export CPU_6CORE="6"
	export CPU_HALF=$(($CPU_CORE / 2))                    #half of availble cores on system
	export CPU_HALF_EVEN=$(($CPU_HALF - ($CPU_HALF % 2))) #Forces CPU cores to even number to avoid partial core export. ie 7 cores would be 3.5 cores.

	if [ $CPU_CORE -le $CPU_6CORE ]; then #If statement for low core systems.  Forces computers to only use 1 core if there are 4 cores or less on the system. then
		export CPU_HALF_EVEN="2"
	else
		export CPU_HALF_EVEN=$(($CPU_HALF - ($CPU_HALF % 2)))
	fi

	echo "##########################################"
	echo "Number of threads being used $CPU_HALF_EVEN"
	echo "##########################################"
	echo " "

	#############################Compilers############################
	export DIR="${WRF_FOLDER}"/WRF_CHEM_Tools/Libs
	export CC=gcc
	export CXX=g++
	export FC=gfortran
	export F77=gfortran
	export CFLAGS="-fPIC -fPIE -m64"

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

	export FFLAGS="$fallow_argumen"
	export FCFLAGS="$fallow_argumen"

	echo "##########################################"
	echo "FFLAGS = $FFLAGS"
	echo "FCFLAGS = $FCFLAGS"
	echo "CFLAGS = $CFLAGS"
	echo "##########################################"

	#############################zlib############################
	#Uncalling compilers due to comfigure issue with zlib$Zlib_Version
	#With CC & CXX definied ./configure uses different compiler Flags

	cd "${WRF_FOLDER}"/WRF_CHEM_Tools/Downloads
	tar -xvzf zlib-$Zlib_Version.tar.gz
	cd zlib-$Zlib_Version/
	autoreconf -i -f 2>&1 | tee autoreconf.log
	./configure --prefix=$DIR/grib2 2>&1 | tee configure.log
	automake -a -f 2>&1 | tee automake.log
	make -j $CPU_HALF_EVEN 2>&1 | tee make.log
	make -j $CPU_HALF_EVEN install 2>&1 | tee make.make.log
	#make check

	##############################MPICH############################
	cd "${WRF_FOLDER}"/WRF_CHEM_Tools/Downloads
	tar -xvzf mpich-$Mpich_Version.tar.gz
	cd mpich-$Mpich_Version/
	autoreconf -i -f 2>&1 | tee autoreconf.log
	F90= ./configure --prefix=$DIR/MPICH --with-device=ch3 FFLAGS=$FFLAGS FCFLAGS=$FCFLAGS 2>&1 | tee configure.log
	automake -a -f 2>&1 | tee automake.log
	make -j $CPU_HALF_EVEN 2>&1 | tee make.log
	make -j $CPU_HALF_EVEN install 2>&1 | tee make.make.log
	#make check

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
	tar -xvzf libpng-$Libpng_Version.tar.gz
	cd libpng-$Libpng_Version/
	autoreconf -i -f 2>&1 | tee autoreconf.log
	CC=$MPICC FC=$MPIFC F77=$MPIF77 F90=$MPIF90 CXX=$MPICXX CFLAGS=$CFLAGS FFLAGS=$FFLAGS FCFLAGS=$FCFLAGS ./configure --prefix=$DIR/grib2 2>&1 | tee configure.log
	automake -a -f 2>&1 | tee automake.log
	make -j $CPU_HALF_EVEN 2>&1 | tee make.log
	make -j $CPU_HALF_EVEN install 2>&1 | tee make.make.log
	#make check

	#############################JasPer############################
	cd "${WRF_FOLDER}"/WRF_CHEM_Tools/Downloads
	unzip jasper-$Jasper_Version.zip
	cd jasper-$Jasper_Version/
	autoreconf -i -f 2>&1 | tee autoreconf.log
	CC=$MPICC FC=$MPIFC F77=$MPIF77 F90=$MPIF90 CXX=$MPICXX CFLAGS=$CFLAGS FFLAGS=$FFLAGS FCFLAGS=$FCFLAGS ./configure --prefix=$DIR/grib2 2>&1 | tee configure.log
	automake -a -f 2>&1 | tee automake.log
	make -j $CPU_HALF_EVEN 2>&1 | tee make.log
	make -j $CPU_HALF_EVEN install 2>&1 | tee make.make.log

	export JASPERLIB=$DIR/grib2/lib
	export JASPERINC=$DIR/grib2/include

	#############################hdf5 library for netcdf4 functionality############################
	cd "${WRF_FOLDER}"/WRF_CHEM_Tools/Downloads
	tar -xvzf hdf5-$HDF5_Version-$HDF5_Sub_Version.tar.gz
	cd hdf5-$HDF5_Version-$HDF5_Sub_Version
	autoreconf -i -f 2>&1 | tee autoreconf.log
	CC=$MPICC FC=$MPIFC F77=$MPIF77 F90=$MPIF90 CXX=$MPICXX CFLAGS=$CFLAGS FFLAGS=$FFLAGS FCFLAGS=$FCFLAGS ./configure --prefix=$DIR/grib2 --with-zlib=$DIR/grib2 --enable-hl --enable-fortran --enable-parallel 2>&1 | tee configure.log
	automake -a -f 2>&1 | tee automake.log
	make -j $CPU_HALF_EVEN 2>&1 | tee make.log
	make -j $CPU_HALF_EVEN install 2>&1 | tee make.make.log
	#make check

	export HDF5=$DIR/grib2
	export PHDF5=$DIR/grib2
	export LD_LIBRARY_PATH=$DIR/grib2/lib:$LD_LIBRARY_PATH

	echo " "

	#############################Install Parallel-netCDF##############################
	#Make file created with half of available cpu cores
	#Hard path for MPI added
	##################################################################################
	cd "${WRF_FOLDER}"/WRF_CHEM_Tools/Downloads
	tar -xvzf pnetcdf-$Pnetcdf_Version.tar.gz
	cd pnetcdf-$Pnetcdf_Version
	autoreconf -i -f 2>&1 | tee autoreconf.log
	CC=$MPICC FC=$MPIFC F77=$MPIF77 F90=$MPIF90 CXX=$MPICXX CFLAGS=$CFLAGS FFLAGS=$FFLAGS FCFLAGS=$FCFLAGS ./configure --prefix=$DIR/grib2 --enable-shared --enable-static 2>&1 | tee configure.log
	automake -a -f 2>&1 | tee automake.log
	make -j $CPU_HALF_EVEN 2>&1 | tee make.log
	make -j $CPU_HALF_EVEN install 2>&1 | tee make.make.log
	#make check

	export PNETCDF=$DIR/grib2

	##############################Install NETCDF C Library############################
	cd "${WRF_FOLDER}"/WRF_CHEM_Tools/Downloads
	tar -xzvf v$Netcdf_C_Version.tar.gz
	cd netcdf-c-$Netcdf_C_Version/
	export CPPFLAGS=-I$DIR/grib2/include
	export LDFLAGS=-L$DIR/grib2/lib
	export LIBS="-lhdf5_hl -lhdf5 -lz -lcurl -lgfortran -lgcc -lm -ldl -lpnetcdf"
	autoreconf -i -f 2>&1 | tee autoreconf.log
	CC=$MPICC FC=$MPIFC F77=$MPIF77 F90=$MPIF90 CXX=$MPICXX CFLAGS=$CFLAGS FFLAGS=$FFLAGS FCFLAGS=$FCFLAGS ./configure --prefix=$DIR/NETCDF --with-zlib=$DIR/grib2 --disable-dap --enable-netcdf-4 --enable-netcdf4 --enable-shared --enable-static --enable-pnetcdf --enable-cdf5 --enable-parallel-tests 2>&1 | tee configure.log
	automake -a -f 2>&1 | tee automake.log
	make -j $CPU_HALF_EVEN 2>&1 | tee make.log
	make -j $CPU_HALF_EVEN install 2>&1 | tee make.make.log
	#make check

	export PATH=$DIR/NETCDF/bin:$PATH
	export NETCDF=$DIR/NETCDF

	##############################NetCDF fortran library############################
	cd "${WRF_FOLDER}"/WRF_CHEM_Tools/Downloads
	tar -xvzf v$Netcdf_Fortran_Version.tar.gz
	cd netcdf-fortran-$Netcdf_Fortran_Version/
	export LD_LIBRARY_PATH=$DIR/NETCDF/lib:$LD_LIBRARY_PATH
	export CPPFLAGS="-I$DIR/NETCDF/include -I$DIR/grib2/include"
	export LDFLAGS="-L$DIR/NETCDF/lib -L$DIR/grib2/lib"
	export LIBS="-lnetcdf -lpnetcdf -lcurl -lhdf5_hl -lhdf5 -lz -ldl -lgcc -lgfortran"
	autoreconf -i -f 2>&1 | tee autoreconf.log
	CC=$MPICC FC=$MPIFC F77=$MPIF77 F90=$MPIF90 CXX=$MPICXX CFLAGS=$CFLAGS FFLAGS=$FFLAGS FCFLAGS=$FCFLAGS ./configure --prefix=$DIR/NETCDF --enable-netcdf-4 --enable-netcdf4 --enable-shared --enable-static --enable-parallel-tests --enable-hdf5 2>&1 | tee configure.log
	automake -a -f 2>&1 | tee automake.log
	make -j $CPU_HALF_EVEN 2>&1 | tee make.log
	make -j $CPU_HALF_EVEN install 2>&1 | tee make.make.log
	#make check

	echo " "
	#################################### System Environment Tests ##############

	cd "${WRF_FOLDER}"/WRF_CHEM_Tools/Downloads
	wget -c https://www2.mmm.ucar.edu/wrf/OnLineTutorial/compile_tutorial/tar_files/Fortran_C_NETCDF_MPI_tests.tar
	wget -c https://www2.mmm.ucar.edu/wrf/OnLineTutorial/compile_tutorial/tar_files/Fortran_C_tests.tar

	tar -xvf Fortran_C_tests.tar -C "${WRF_FOLDER}"/WRF_CHEM_Tools/Tests/Environment
	tar -xvf Fortran_C_NETCDF_MPI_tests.tar -C "${WRF_FOLDER}"/WRF_CHEM_Tools/Tests/Compatibility

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
	tar -xvf mozbc.tar -C "${WRF_FOLDER}"/WRF_CHEM_Tools/mozbc
	echo ""
	echo "Unpacking MEGAN Bio Emission."
	tar -xvf megan_bio_emiss.tar -C "${WRF_FOLDER}"/WRF_CHEM_Tools/megan_bio_emiss
	echo ""
	echo "Unpacking MEGAN Bio Emission Data."
	tar -xzvf megan.data.tar.gz -C "${WRF_FOLDER}"/WRF_CHEM_Tools/megan_bio_data
	echo ""
	echo "Unpacking Wes Coldens"
	tar -xvf wes-coldens.tar -C "${WRF_FOLDER}"/WRF_CHEM_Tools/wes_coldens
	echo ""
	echo "Unpacking Unpacking ANTHRO Emission."
	tar -xvf ANTHRO.tar -C "${WRF_FOLDER}"/WRF_CHEM_Tools/ANTHRO_EMIS
	echo ""
	echo "Unpacking EDGAR-HTAP."
	tar -xzvf EDGAR-HTAP.tgz -C "${WRF_FOLDER}"/WRF_CHEM_Tools/EDGAR_HTAP
	echo ""
	echo "Unpacking EPA ANTHRO Emission."
	tar -xzvf EPA_ANTHRO_EMIS.tgz -C "${WRF_FOLDER}"/WRF_CHEM_Tools/EPA_ANTHRO_EMIS
	echo ""
	echo "Unpacking Upper Boundary Conditions."
	tar -xvf UBC_inputs.tar -C "${WRF_FOLDER}"/WRF_CHEM_Tools/UBC
	echo ""
	echo "Unpacking Aircraft Preprocessor Files."
	echo ""
	tar -xvf aircraft_preprocessor_files.tar -C "${WRF_FOLDER}"/WRF_CHEM_Tools/Aircraft
	echo ""
	echo "Unpacking Fire INventory from NCAR (FINN)"
	tar -xzvf fire_emis.tgz -C "${WRF_FOLDER}"/WRF_CHEM_Tools/FINN
	tar -xvf fire_emis_input.tar
	tar -zxvf grass_from_img.nc.tgz -C "${WRF_FOLDER}"/WRF_CHEM_Tools/FINN/grid_finn_fire_emis_v2020/src
	tar -zxvf tempfor_from_img.nc.tgz -C "${WRF_FOLDER}"/WRF_CHEM_Tools/FINN/grid_finn_fire_emis_v2020/src
	tar -zxvf shrub_from_img.nc.tgz -C "${WRF_FOLDER}"/WRF_CHEM_Tools/FINN/grid_finn_fire_emis_v2020/src
	tar -zxvf tropfor_from_img.nc.tgz -C "${WRF_FOLDER}"/WRF_CHEM_Tools/FINN/grid_finn_fire_emis_v2020/src

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

	wget -4 -c http://ftp.cptec.inpe.br/pesquisa/bramsrd/BRAMS_5.4/PREP-CHEM/PREP-CHEM-SRC-1.5.tar.gz

	tar -xzvf PREP-CHEM-SRC-1.5.tar.gz -C "${WRF_FOLDER}"/WRF_CHEM_Tools/PREP-CHEM-SRC-1.5

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

if [ "$Ubuntu_64bit_GNU" = "1" ]; then

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

	echo $PASSWD | sudo -S apt -y install autoconf automake bison build-essential byacc cmake csh curl default-jdk default-jre flex g++ gawk gcc gfortran git ksh libcurl4-openssl-dev libjpeg-dev libncurses6 libpixman-1-dev libpng-dev libtool libxml2 libxml2-dev m4 make ncview okular openbox pipenv pkg-config python3 python3-dev python3-pip python3-dateutil tcsh unzip xauth xorg time

	#Fix any broken installations
	echo $PASSWD | sudo -S apt --fix-broken install

	# make sure some critical packages have been installed
	which cmake pkg-config make gcc g++ gfortran

	#Directory Listings
	export HOME=$(
		cd
		pwd
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
	wget -c https://github.com/HDFGroup/hdf5/releases/download/hdf5_$HDF5_Version.$HDF5_Sub_Version/hdf5-$HDF5_Version-$HDF5_Sub_Version.tar.gz
	wget -c https://github.com/Unidata/netcdf-c/archive/refs/tags/v$Netcdf_C_Version.tar.gz
	wget -c https://github.com/Unidata/netcdf-fortran/archive/refs/tags/v$Netcdf_Fortran_Version.tar.gz
	wget -c https://download.sourceforge.net/libpng/libpng-$Libpng_Version.tar.gz
	wget -c https://www.ece.uvic.ca/~frodo/jasper/software/jasper-$Jasper_Version.zip
	wget -c https://github.com/pmodels/mpich/releases/download/v$Mpich_Version/mpich-$Mpich_Version.tar.gz
	wget -c https://parallel-netcdf.github.io/Release/pnetcdf-$Pnetcdf_Version.tar.gz

	#############################Core Management####################################
	export CPU_CORE=$(nproc) # number of available threads on system
	export CPU_6CORE="6"
	export CPU_HALF=$(($CPU_CORE / 2))                    #half of availble cores on system
	export CPU_HALF_EVEN=$(($CPU_HALF - ($CPU_HALF % 2))) #Forces CPU cores to even number to avoid partial core export. ie 7 cores would be 3.5 cores.

	if [ $CPU_CORE -le $CPU_6CORE ]; then #If statement for low core systems.  Forces computers to only use 1 core if there are 4 cores or less on the system. then
		export CPU_HALF_EVEN="2"
	else
		export CPU_HALF_EVEN=$(($CPU_HALF - ($CPU_HALF % 2)))
	fi

	echo "##########################################"
	echo "Number of threads being used $CPU_HALF_EVEN"
	echo "##########################################"
	echo " "

	#############################Compilers############################
	export DIR="${WRF_FOLDER}"/WRF_CHEM_Tools/Libs
	export CC=gcc
	export CXX=g++
	export FC=gfortran
	export F77=gfortran
	export CFLAGS="-fPIC -fPIE -m64"

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

	export FFLAGS="$fallow_argumen"
	export FCFLAGS="$fallow_argumen"

	echo "##########################################"
	echo "FFLAGS = $FFLAGS"
	echo "FCFLAGS = $FCFLAGS"
	echo "CFLAGS = $CFLAGS"
	echo "##########################################"

	#############################zlib############################
	#Uncalling compilers due to comfigure issue with zlib$Zlib_Version
	#With CC & CXX definied ./configure uses different compiler Flags

	cd "${WRF_FOLDER}"/WRF_CHEM_Tools/Downloads
	tar -xvzf zlib-$Zlib_Version.tar.gz
	cd zlib-$Zlib_Version/
	autoreconf -i -f 2>&1 | tee autoreconf.log
	./configure --prefix=$DIR/grib2 2>&1 | tee configure.log
	automake -a -f 2>&1 | tee automake.log
	make -j $CPU_HALF_EVEN 2>&1 | tee make.log
	make -j $CPU_HALF_EVEN check 2>&1 | tee make.check.log
	make -j $CPU_HALF_EVEN install 2>&1 | tee make.install.log
	#make check

	##############################MPICH############################
	cd "${WRF_FOLDER}"/WRF_CHEM_Tools/Downloads
	tar -xvzf mpich-$Mpich_Version.tar.gz
	cd mpich-$Mpich_Version/
	autoreconf -i -f 2>&1 | tee autoreconf.log
	F90= ./configure --prefix=$DIR/MPICH --with-device=ch3 FFLAGS=$FFLAGS FCFLAGS=$FCFLAGS 2>&1 | tee configure.log
	automake -a -f 2>&1 | tee automake.log
	make -j $CPU_HALF_EVEN 2>&1 | tee make.log
	make -j $CPU_HALF_EVEN check 2>&1 | tee make.check.log
	make -j $CPU_HALF_EVEN install 2>&1 | tee make.install.log
	#make check

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
	tar -xvzf libpng-$Libpng_Version.tar.gz
	cd libpng-$Libpng_Version/
	autoreconf -i -f 2>&1 | tee autoreconf.log
	CC=$MPICC FC=$MPIFC F77=$MPIF77 F90=$MPIF90 CXX=$MPICXX CFLAGS=$CFLAGS FFLAGS=$FFLAGS FCFLAGS=$FCFLAGS ./configure --prefix=$DIR/grib2 2>&1 | tee configure.log
	automake -a -f 2>&1 | tee automake.log
	make -j $CPU_HALF_EVEN 2>&1 | tee make.log
	make -j $CPU_HALF_EVEN check 2>&1 | tee make.check.log
	make -j $CPU_HALF_EVEN install 2>&1 | tee make.install.log
	#make check

	#############################JasPer############################
	cd "${WRF_FOLDER}"/WRF_CHEM_Tools/Downloads
	unzip jasper-$Jasper_Version.zip
	cd jasper-$Jasper_Version/
	autoreconf -i -f 2>&1 | tee autoreconf.log
	CC=$MPICC FC=$MPIFC F77=$MPIF77 F90=$MPIF90 CXX=$MPICXX CFLAGS=$CFLAGS FFLAGS=$FFLAGS FCFLAGS=$FCFLAGS ./configure --prefix=$DIR/grib2 2>&1 | tee configure.log
	automake -a -f 2>&1 | tee automake.log
	make -j $CPU_HALF_EVEN 2>&1 | tee make.log
	make -j $CPU_HALF_EVEN check 2>&1 | tee make.check.log
	make -j $CPU_HALF_EVEN install 2>&1 | tee make.install.log

	export JASPERLIB=$DIR/grib2/lib
	export JASPERINC=$DIR/grib2/include

	#############################hdf5 library for netcdf4 functionality############################
	cd "${WRF_FOLDER}"/WRF_CHEM_Tools/Downloads
	tar -xvzf hdf5-$HDF5_Version-$HDF5_Sub_Version.tar.gz
	cd hdf5-$HDF5_Version-$HDF5_Sub_Version
	autoreconf -i -f 2>&1 | tee autoreconf.log
	CC=$MPICC FC=$MPIFC F77=$MPIF77 F90=$MPIF90 CXX=$MPICXX CFLAGS=$CFLAGS FFLAGS=$FFLAGS FCFLAGS=$FCFLAGS ./configure --prefix=$DIR/grib2 --with-zlib=$DIR/grib2 --enable-hl --enable-fortran --enable-parallel 2>&1 | tee configure.log
	automake -a -f 2>&1 | tee automake.log
	make -j $CPU_HALF_EVEN 2>&1 | tee make.log
	make -j $CPU_HALF_EVEN check 2>&1 | tee make.check.log
	make -j $CPU_HALF_EVEN install 2>&1 | tee make.install.log
	#make check

	export HDF5=$DIR/grib2
	export PHDF5=$DIR/grib2
	export LD_LIBRARY_PATH=$DIR/grib2/lib:$LD_LIBRARY_PATH

	echo " "

	#############################Install Parallel-netCDF##############################
	#Make file created with half of available cpu cores
	#Hard path for MPI added
	##################################################################################
	cd "${WRF_FOLDER}"/WRF_CHEM_Tools/Downloads
	tar -xvzf pnetcdf-$Pnetcdf_Version.tar.gz
	cd pnetcdf-$Pnetcdf_Version
	autoreconf -i -f 2>&1 | tee autoreconf.log
	CC=$MPICC FC=$MPIFC F77=$MPIF77 F90=$MPIF90 CXX=$MPICXX CFLAGS=$CFLAGS FFLAGS=$FFLAGS FCFLAGS=$FCFLAGS ./configure --prefix=$DIR/grib2 --enable-shared --enable-static 2>&1 | tee configure.log
	automake -a -f 2>&1 | tee automake.log
	make -j $CPU_HALF_EVEN 2>&1 | tee make.log
	make -j $CPU_HALF_EVEN check 2>&1 | tee make.check.log
	make -j $CPU_HALF_EVEN install 2>&1 | tee make.install.log
	#make check

	export PNETCDF=$DIR/grib2

	##############################Install NETCDF C Library############################
	cd "${WRF_FOLDER}"/WRF_CHEM_Tools/Downloads
	tar -xzvf v$Netcdf_C_Version.tar.gz
	cd netcdf-c-$Netcdf_C_Version/
	export CPPFLAGS=-I$DIR/grib2/include
	export LDFLAGS=-L$DIR/grib2/lib
	export LIBS="-lhdf5_hl -lhdf5 -lz -lcurl -lgfortran -lgcc -lm -ldl -lpnetcdf"
	autoreconf -i -f 2>&1 | tee autoreconf.log
	CC=$MPICC FC=$MPIFC F77=$MPIF77 F90=$MPIF90 CXX=$MPICXX CFLAGS=$CFLAGS FFLAGS=$FFLAGS FCFLAGS=$FCFLAGS ./configure --prefix=$DIR/NETCDF --with-zlib=$DIR/grib2 --disable-dap --enable-netcdf-4 --enable-netcdf4 --enable-shared --enable-static --enable-pnetcdf --enable-cdf5 --enable-parallel-tests 2>&1 | tee configure.log
	automake -a -f 2>&1 | tee automake.log
	make -j $CPU_HALF_EVEN 2>&1 | tee make.log
	make -j $CPU_HALF_EVEN check 2>&1 | tee make.check.log
	make -j $CPU_HALF_EVEN install 2>&1 | tee make.install.log
	#make check

	export PATH=$DIR/NETCDF/bin:$PATH
	export NETCDF=$DIR/NETCDF

	##############################NetCDF fortran library############################
	cd "${WRF_FOLDER}"/WRF_CHEM_Tools/Downloads
	tar -xvzf v$Netcdf_Fortran_Version.tar.gz
	cd netcdf-fortran-$Netcdf_Fortran_Version/
	export LD_LIBRARY_PATH=$DIR/NETCDF/lib:$LD_LIBRARY_PATH
	export CPPFLAGS="-I$DIR/NETCDF/include -I$DIR/grib2/include"
	export LDFLAGS="-L$DIR/NETCDF/lib -L$DIR/grib2/lib"
	export LIBS="-lnetcdf -lpnetcdf -lcurl -lhdf5_hl -lhdf5 -lz -ldl -lgcc -lgfortran"
	autoreconf -i -f 2>&1 | tee autoreconf.log
	CC=$MPICC FC=$MPIFC F77=$MPIF77 F90=$MPIF90 CXX=$MPICXX CFLAGS=$CFLAGS FFLAGS=$FFLAGS FCFLAGS=$FCFLAGS ./configure --prefix=$DIR/NETCDF --enable-netcdf-4 --enable-netcdf4 --enable-shared --enable-static --enable-parallel-tests --enable-hdf5 2>&1 | tee configure.log
	automake -a -f 2>&1 | tee automake.log
	make -j $CPU_HALF_EVEN 2>&1 | tee make.log
	make -j $CPU_HALF_EVEN check 2>&1 | tee make.check.log
	make -j $CPU_HALF_EVEN install 2>&1 | tee make.install.log
	#make check

	echo " "
	#################################### System Environment Tests ##############

	cd "${WRF_FOLDER}"/WRF_CHEM_Tools/Downloads
	wget -c https://www2.mmm.ucar.edu/wrf/OnLineTutorial/compile_tutorial/tar_files/Fortran_C_NETCDF_MPI_tests.tar
	wget -c https://www2.mmm.ucar.edu/wrf/OnLineTutorial/compile_tutorial/tar_files/Fortran_C_tests.tar

	tar -xvf Fortran_C_tests.tar -C "${WRF_FOLDER}"/WRF_CHEM_Tools/Tests/Environment
	tar -xvf Fortran_C_NETCDF_MPI_tests.tar -C "${WRF_FOLDER}"/WRF_CHEM_Tools/Tests/Compatibility

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
	tar -xvf mozbc.tar -C "${WRF_FOLDER}"/WRF_CHEM_Tools/mozbc
	echo ""
	echo "Unpacking MEGAN Bio Emission."
	tar -xvf megan_bio_emiss.tar -C "${WRF_FOLDER}"/WRF_CHEM_Tools/megan_bio_emiss
	echo ""
	echo "Unpacking MEGAN Bio Emission Data."
	tar -xzvf megan.data.tar.gz -C "${WRF_FOLDER}"/WRF_CHEM_Tools/megan_bio_data
	echo ""
	echo "Unpacking Wes Coldens"
	tar -xvf wes-coldens.tar -C "${WRF_FOLDER}"/WRF_CHEM_Tools/wes_coldens
	echo ""
	echo "Unpacking Unpacking ANTHRO Emission."
	tar -xvf ANTHRO.tar -C "${WRF_FOLDER}"/WRF_CHEM_Tools/ANTHRO_EMIS
	echo ""
	echo "Unpacking EDGAR-HTAP."
	tar -xzvf EDGAR-HTAP.tgz -C "${WRF_FOLDER}"/WRF_CHEM_Tools/EDGAR_HTAP
	echo ""
	echo "Unpacking EPA ANTHRO Emission."
	tar -xzvf EPA_ANTHRO_EMIS.tgz -C "${WRF_FOLDER}"/WRF_CHEM_Tools/EPA_ANTHRO_EMIS
	echo ""
	echo "Unpacking Upper Boundary Conditions."
	tar -xvf UBC_inputs.tar -C "${WRF_FOLDER}"/WRF_CHEM_Tools/UBC
	echo ""
	echo "Unpacking Aircraft Preprocessor Files."
	echo ""
	tar -xvf aircraft_preprocessor_files.tar -C "${WRF_FOLDER}"/WRF_CHEM_Tools/Aircraft
	echo ""
	echo "Unpacking Fire INventory from NCAR (FINN)"
	tar -xzvf fire_emis.tgz -C "${WRF_FOLDER}"/WRF_CHEM_Tools/FINN
	tar -xvf fire_emis_input.tar
	tar -zxvf grass_from_img.nc.tgz -C "${WRF_FOLDER}"/WRF_CHEM_Tools/FINN/grid_finn_fire_emis_v2020/src
	tar -zxvf tempfor_from_img.nc.tgz -C "${WRF_FOLDER}"/WRF_CHEM_Tools/FINN/grid_finn_fire_emis_v2020/src
	tar -zxvf shrub_from_img.nc.tgz -C "${WRF_FOLDER}"/WRF_CHEM_Tools/FINN/grid_finn_fire_emis_v2020/src
	tar -zxvf tropfor_from_img.nc.tgz -C "${WRF_FOLDER}"/WRF_CHEM_Tools/FINN/grid_finn_fire_emis_v2020/src

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

	wget -4 -c http://ftp.cptec.inpe.br/pesquisa/bramsrd/BRAMS_5.4/PREP-CHEM/PREP-CHEM-SRC-1.5.tar.gz

	tar -xzvf PREP-CHEM-SRC-1.5.tar.gz -C "${WRF_FOLDER}"/WRF_CHEM_Tools/PREP-CHEM-SRC-1.5

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
	echo "WRF CHEM Tools & PREP_CHEM_SRC compiled with latest version of NETCDF files available on 01/01/2023"
	echo "If error occurs using WRFCHEM tools please update your NETCDF libraries or reconfigure with older libraries"
	echo "This is a WRC Chem Community tool made by a private user and is not supported by UCAR/NCAR"
	read -r -t 5 -p "BASH Script Finished"

fi

if [ "$Ubuntu_64bit_Intel" = "1" ]; then

	echo $PASSWD | sudo -S apt -y update
	echo $PASSWD | sudo -S apt -y upgrade

	# download the key to system keyring; this and the following echo command are
	# needed in order to install the Intel compilers
	wget -O- https://apt.repos.intel.com/intel-gpg-keys/GPG-PUB-KEY-INTEL-SW-PRODUCTS.PUB |
		gpg --dearmor | sudo tee /usr/share/keyrings/oneapi-archive-keyring.gpg >/dev/null

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

	echo $PASSWD | sudo -S apt -y install autoconf automake bison build-essential byacc cmake csh curl default-jdk default-jre flex g++ gawk gcc gfortran git ksh libcurl4-openssl-dev libjpeg-dev libncurses6 libpixman-1-dev libpng-dev libtool libxml2 libxml2-dev m4 make ncview okular openbox pipenv pkg-config python3 python3-dev python3-pip python3-dateutil tcsh unzip xauth xorg time

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
	export MPICXX=mpiicpc
	export CFLAGS="-fPIC -fPIE -O3 -Wno-implicit-function-declaration -Wno-incompatible-function-pointer-types -Wno-unused-command-line-argument"
	export FFLAGS="-m64"
	export FCFLAGS="-m64"

	#Directory Listings
	export HOME=$(
		cd
		pwd
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
	wget -c https://github.com/HDFGroup/hdf5/releases/download/hdf5_$HDF5_Version.$HDF5_Sub_Version/hdf5-$HDF5_Version-$HDF5_Sub_Version.tar.gz
	wget -c https://github.com/Unidata/netcdf-c/archive/refs/tags/v$Netcdf_C_Version.tar.gz
	wget -c https://github.com/Unidata/netcdf-fortran/archive/refs/tags/v$Netcdf_Fortran_Version.tar.gz
	wget -c https://download.sourceforge.net/libpng/libpng-$Libpng_Version.tar.gz
	wget -c https://www.ece.uvic.ca/~frodo/jasper/software/jasper-$Jasper_Version.zip
	wget -c https://parallel-netcdf.github.io/Release/pnetcdf-$Pnetcdf_Version.tar.gz

	#############################Core Management####################################
	export CPU_CORE=$(nproc) #number of available threads on system
	export CPU_6CORE="6"
	export CPU_HALF=$(($CPU_CORE / 2))                    #half of availble cores on system
	export CPU_HALF_EVEN=$(($CPU_HALF - ($CPU_HALF % 2))) #Forces CPU cores to even number to avoid partial core export. ie 7 cores would be 3.5 cores.

	if [ $CPU_CORE -le $CPU_6CORE ]; then #If statement for low core systems.  Forces computers to only use 1 core if there are 4 cores or less on the system. then
		export CPU_HALF_EVEN="2"
	else
		export CPU_HALF_EVEN=$(($CPU_HALF - ($CPU_HALF % 2)))
	fi

	echo "##########################################"
	echo "Number of threads being used $CPU_HALF_EVEN"
	echo "##########################################"
	echo " "

	#############################Compilers############################

	#############################zlib############################
	#Uncalling compilers due to comfigure issue with zlib$Zlib_Version
	#With CC & CXX definied ./configure uses different compiler Flags

	cd "${WRF_FOLDER}"/WRF_CHEM_Tools/Downloads
	tar -xvzf zlib-$Zlib_Version.tar.gz
	cd zlib-$Zlib_Version/
	autoreconf -i -f 2>&1 | tee autoreconf.log
	./configure --prefix=$DIR/grib2 2>&1 | tee configure.log
	automake -a -f 2>&1 | tee automake.log
	make -j $CPU_HALF_EVEN 2>&1 | tee make.log
	make -j $CPU_HALF_EVEN check 2>&1 | tee make.check.log
	make -j $CPU_HALF_EVEN install 2>&1 | tee make.install.log
	#make check

	#############################libpng############################
	cd "${WRF_FOLDER}"/WRF_CHEM_Tools/Downloads
	export LDFLAGS=-L$DIR/grib2/lib
	export CPPFLAGS=-I$DIR/grib2/include
	tar -xvzf libpng-$Libpng_Version.tar.gz
	autoreconf -i -f 2>&1 | tee autoreconf.log
	cd libpng-$Libpng_Version/
	CC=$MPICC FC=$MPIFC F77=$MPIF77 F90=$MPIF90 CXX=$MPICXX CFLAGS=$CFLAGS FFLAGS=$FFLAGS FCFLAGS=$FCFLAGS ./configure --prefix=$DIR/grib2 2>&1 | tee configure.log
	automake -a -f 2>&1 | tee automake.log
	make -j $CPU_HALF_EVEN 2>&1 | tee make.log
	make -j $CPU_HALF_EVEN check 2>&1 | tee make.check.log
	make -j $CPU_HALF_EVEN install 2>&1 | tee make.install.log
	#make check

	#############################JasPer############################
	cd "${WRF_FOLDER}"/WRF_CHEM_Tools/Downloads
	unzip jasper-$Jasper_Version.zip
	cd jasper-$Jasper_Version/
	autoreconf -i -f 2>&1 | tee autoreconf.log
	CC=$MPICC FC=$MPIFC F77=$MPIF77 F90=$MPIF90 CXX=$MPICXX CFLAGS=$CFLAGS FFLAGS=$FFLAGS FCFLAGS=$FCFLAGS ./configure --prefix=$DIR/grib2 2>&1 | tee configure.log
	automake -a -f 2>&1 | tee automake.log
	make -j $CPU_HALF_EVEN 2>&1 | tee make.log
	make -j $CPU_HALF_EVEN check 2>&1 | tee make.check.log
	make -j $CPU_HALF_EVEN install 2>&1 | tee make.install.log

	export JASPERLIB=$DIR/grib2/lib
	export JASPERINC=$DIR/grib2/include

	#############################hdf5 library for netcdf4 functionality############################
	cd "${WRF_FOLDER}"/WRF_CHEM_Tools/Downloads
	tar -xvzf hdf5-$HDF5_Version-$HDF5_Sub_Version.tar.gz
	cd hdf5-$HDF5_Version-$HDF5_Sub_Version
	autoreconf -i -f 2>&1 | tee autoreconf.log
	CC=$MPICC FC=$MPIFC F77=$MPIF77 F90=$MPIF90 CXX=$MPICXX CFLAGS=$CFLAGS FFLAGS=$FFLAGS FCFLAGS=$FCFLAGS ./configure --prefix=$DIR/grib2 --with-zlib=$DIR/grib2 --enable-hl --enable-fortran --enable-parallel 2>&1 | tee configure.log
	automake -a -f 2>&1 | tee automake.log
	make -j $CPU_HALF_EVEN 2>&1 | tee make.log
	make -j $CPU_HALF_EVEN check 2>&1 | tee make.check.log
	make -j $CPU_HALF_EVEN install 2>&1 | tee make.install.log
	#make check

	export HDF5=$DIR/grib2
	export PHDF5=$DIR/grib2
	export LD_LIBRARY_PATH=$DIR/grib2/lib:$LD_LIBRARY_PATH

	echo " "

	#############################Install Parallel-netCDF##############################
	#Make file created with half of available cpu cores
	#Hard path for MPI added
	##################################################################################
	cd "${WRF_FOLDER}"/WRF_CHEM_Tools/Downloads
	tar -xvzf pnetcdf-$Pnetcdf_Version.tar.gz
	cd pnetcdf-$Pnetcdf_Version
	autoreconf -i -f 2>&1 | tee autoreconf.log
	CC=$MPICC FC=$MPIFC F77=$MPIF77 F90=$MPIF90 CXX=$MPICXX CFLAGS=$CFLAGS FFLAGS=$FFLAGS FCFLAGS=$FCFLAGS ./configure --prefix=$DIR/grib2 --enable-shared --enable-static 2>&1 | tee configure.log
	automake -a -f 2>&1 | tee automake.log
	make -j $CPU_HALF_EVEN 2>&1 | tee make.log
	make -j $CPU_HALF_EVEN check 2>&1 | tee make.check.log
	make -j $CPU_HALF_EVEN install 2>&1 | tee make.install.log
	#make check

	export PNETCDF=$DIR/grib2

	##############################Install NETCDF C Library############################
	cd "${WRF_FOLDER}"/WRF_CHEM_Tools/Downloads
	tar -xzvf v$Netcdf_C_Version.tar.gz
	cd netcdf-c-$Netcdf_C_Version/
	export CPPFLAGS=-I$DIR/grib2/include
	export LDFLAGS=-L$DIR/grib2/lib
	export LIBS="-lhdf5_hl -lhdf5 -lz -lcurl -lgcc -lm -ldl -lpnetcdf"
	autoreconf -i -f 2>&1 | tee autoreconf.log
	CC=$MPICC FC=$MPIFC F77=$MPIF77 F90=$MPIF90 CXX=$MPICXX CFLAGS=$CFLAGS FFLAGS=$FFLAGS FCFLAGS=$FCFLAGS ./configure --prefix=$DIR/NETCDF --with-zlib=$DIR/grib2 --disable-dap --enable-netcdf-4 --enable-netcdf4 --enable-shared --enable-static --enable-pnetcdf --enable-cdf5 --enable-parallel-tests 2>&1 | tee configure.log
	automake -a -f 2>&1 | tee automake.log
	make -j $CPU_HALF_EVEN 2>&1 | tee make.log
	make -j $CPU_HALF_EVEN check 2>&1 | tee make.check.log
	make -j $CPU_HALF_EVEN install 2>&1 | tee make.install.log
	#make check

	export PATH=$DIR/NETCDF/bin:$PATH
	export NETCDF=$DIR/NETCDF

	##############################NetCDF fortran library############################
	cd "${WRF_FOLDER}"/WRF_CHEM_Tools/Downloads
	tar -xvzf v$Netcdf_Fortran_Version.tar.gz
	cd netcdf-fortran-$Netcdf_Fortran_Version/
	export LD_LIBRARY_PATH=$DIR/NETCDF/lib:$LD_LIBRARY_PATH
	export CPPFLAGS="-I$DIR/NETCDF/include -I$DIR/grib2/include"
	export LDFLAGS="-L$DIR/NETCDF/lib -L$DIR/grib2/lib"
	export LIBS="-lnetcdf -lpnetcdf -lcurl -lhdf5_hl -lhdf5 -lz -lm -ldl -lgcc"
	autoreconf -i -f 2>&1 | tee autoreconf.log
	CC=$MPICC FC=$MPIFC F77=$MPIF77 F90=$MPIF90 CXX=$MPICXX CFLAGS=$CFLAGS FFLAGS=$FFLAGS FCFLAGS=$FCFLAGS ./configure --prefix=$DIR/NETCDF --enable-netcdf-4 --enable-netcdf4 --enable-shared --enable-static --enable-parallel-tests --enable-hdf5 2>&1 | tee configure.log
	automake -a -f 2>&1 | tee automake.log
	make -j $CPU_HALF_EVEN 2>&1 | tee make.log
	make -j $CPU_HALF_EVEN check 2>&1 | tee make.check.log
	make -j $CPU_HALF_EVEN install 2>&1 | tee make.install.log
	#make check

	echo " "
	#################################### System Environment Tests ##############

	cd "${WRF_FOLDER}"/WRF_CHEM_Tools/Downloads
	wget -c https://www2.mmm.ucar.edu/wrf/OnLineTutorial/compile_tutorial/tar_files/Fortran_C_NETCDF_MPI_tests.tar
	wget -c https://www2.mmm.ucar.edu/wrf/OnLineTutorial/compile_tutorial/tar_files/Fortran_C_tests.tar

	tar -xvf Fortran_C_tests.tar -C "${WRF_FOLDER}"/WRF_CHEM_Tools/Tests/Environment
	tar -xvf Fortran_C_NETCDF_MPI_tests.tar -C "${WRF_FOLDER}"/WRF_CHEM_Tools/Tests/Compatibility

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
	tar -xvf mozbc.tar -C "${WRF_FOLDER}"/WRF_CHEM_Tools/mozbc
	echo ""
	echo "Unpacking MEGAN Bio Emission."
	tar -xvf megan_bio_emiss.tar -C "${WRF_FOLDER}"/WRF_CHEM_Tools/megan_bio_emiss
	echo ""
	echo "Unpacking MEGAN Bio Emission Data."
	tar -xzvf megan.data.tar.gz -C "${WRF_FOLDER}"/WRF_CHEM_Tools/megan_bio_data
	echo ""
	echo "Unpacking Wes Coldens"
	tar -xvf wes-coldens.tar -C "${WRF_FOLDER}"/WRF_CHEM_Tools/wes_coldens
	echo ""
	echo "Unpacking Unpacking ANTHRO Emission."
	tar -xvf ANTHRO.tar -C "${WRF_FOLDER}"/WRF_CHEM_Tools/ANTHRO_EMIS
	echo ""
	echo "Unpacking EDGAR-HTAP."
	tar -xzvf EDGAR-HTAP.tgz -C "${WRF_FOLDER}"/WRF_CHEM_Tools/EDGAR_HTAP
	echo ""
	echo "Unpacking EPA ANTHRO Emission."
	tar -xzvf EPA_ANTHRO_EMIS.tgz -C "${WRF_FOLDER}"/WRF_CHEM_Tools/EPA_ANTHRO_EMIS
	echo ""
	echo "Unpacking Upper Boundary Conditions."
	tar -xvf UBC_inputs.tar -C "${WRF_FOLDER}"/WRF_CHEM_Tools/UBC
	echo ""
	echo "Unpacking Aircraft Preprocessor Files."
	echo ""
	tar -xvf aircraft_preprocessor_files.tar -C "${WRF_FOLDER}"/WRF_CHEM_Tools/Aircraft
	echo ""
	echo "Unpacking Fire INventory from NCAR (FINN)"
	tar -xzvf fire_emis.tgz -C "${WRF_FOLDER}"/WRF_CHEM_Tools/FINN
	tar -xvf fire_emis_input.tar
	tar -zxvf grass_from_img.nc.tgz -C "${WRF_FOLDER}"/WRF_CHEM_Tools/FINN/grid_finn_fire_emis_v2020/src
	tar -zxvf tempfor_from_img.nc.tgz -C "${WRF_FOLDER}"/WRF_CHEM_Tools/FINN/grid_finn_fire_emis_v2020/src
	tar -zxvf shrub_from_img.nc.tgz -C "${WRF_FOLDER}"/WRF_CHEM_Tools/FINN/grid_finn_fire_emis_v2020/src
	tar -zxvf tropfor_from_img.nc.tgz -C "${WRF_FOLDER}"/WRF_CHEM_Tools/FINN/grid_finn_fire_emis_v2020/src

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
	echo "WRF CHEM Tools & PREP-CHEM-SRC compiled with latest version of NETCDF files available on 03/01/2023"
	echo "If error occurs using WRFCHEM tools please update your NETCDF libraries or reconfigure with older libraries"
	echo "This is a WRC Chem Community tool made by a private user and is not supported by UCAR/NCAR"
	read -r -t 5 -p "BASH Script Finished"

fi

if [ "$macos_64bit_GNU" = "1" ] && [ "$MAC_CHIP" = "Intel" ]; then

	#############################basic package managment############################
	brew update
	outdated_packages=$(brew outdated --quiet)

	# List of packages to check/install
	packages=(
		"autoconf" "automake" "bison" "byacc" "cmake" "curl" "flex" "gcc"
		"gdal" "gedit" "git" "gnu-sed" "grads" "imagemagick" "java" "ksh"
		"libtool" "m4" "make" "python@3.10" "snapcraft" "tcsh" "wget"
		"xauth" "xorgproto" "xorgrgb" "xquartz"
	)

	for pkg in "${packages[@]}"; do
		if brew list "$pkg" &>/dev/null; then
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
		cd
		pwd
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
	export CPU_HALF=$(($CPU_CORE / 2))
	#1/2 of availble cores on system
	export CPU_HALF_EVEN=$(($CPU_HALF - ($CPU_HALF % 2)))
	#Forces CPU cores to even number to avoid partial core export. ie 7 cores would be 3.5 cores.

	if [ $CPU_CORE -le $CPU_6CORE ]; then #If statement for low core systems.  Forces computers to only use 1 core if there are 4 cores or less on the system. then
		export CPU_HALF_EVEN="2"
	else
		export CPU_HALF_EVEN=$(($CPU_HALF - ($CPU_HALF % 2)))
	fi

	echo "##########################################"
	echo "Number of Threads being used $CPU_HALF_EVEN"
	echo "##########################################"
	echo " "

	##############################Downloading Libraries############################

	cd "${WRF_FOLDER}"/WRF_CHEM_Tools/Downloads
	wget -c https://github.com/madler/zlib/releases/download/v$Zlib_Version/zlib-$Zlib_Version.tar.gz
	wget -c https://github.com/HDFGroup/hdf5/releases/download/hdf5_$HDF5_Version.$HDF5_Sub_Version/hdf5-$HDF5_Version-$HDF5_Sub_Version.tar.gz
	wget -c https://github.com/Unidata/netcdf-c/archive/refs/tags/v$Netcdf_C_Version.tar.gz
	wget -c https://github.com/Unidata/netcdf-fortran/archive/refs/tags/v$Netcdf_Fortran_Version.tar.gz
	wget -c https://download.sourceforge.net/libpng/libpng-$Libpng_Version.tar.gz
	wget -c https://www.ece.uvic.ca/~frodo/jasper/software/jasper-$Jasper_Version.zip
	wget -c https://github.com/pmodels/mpich/releases/download/v$Mpich_Version/mpich-$Mpich_Version.tar.gz
	wget -c https://parallel-netcdf.github.io/Release/pnetcdf-$Pnetcdf_Version.tar.gz

	echo " "

	#############################Compilers############################

	# Find the highest version of GCC in /usr/local/bin
	latest_gcc=$(ls /usr/local/bin/gcc-* 2>/dev/null | grep -o 'gcc-[0-9]*' | sort -V | tail -n 1)
	latest_gpp=$(ls /usr/local/bin/g++-* 2>/dev/null | grep -o 'g++-[0-9]*' | sort -V | tail -n 1)
	latest_gfortran=$(ls /usr/local/bin/gfortran-* 2>/dev/null | grep -o 'gfortran-[0-9]*' | sort -V | tail -n 1)

	# Check if GCC, G++, and GFortran were found
	if [ -z "$latest_gcc" ]; then
		echo "No GCC version found in /usr/local/bin."
		exit 1
	fi

	# Create or update the symbolic links for GCC, G++, and GFortran
	echo "Linking the latest GCC version: $latest_gcc"
	echo $PASSWD | sudo -S ln -sf /usr/local/bin/$latest_gcc /usr/local/bin/gcc

	if [ ! -z "$latest_gpp" ]; then
		echo "Linking the latest G++ version: $latest_gpp"
		echo $PASSWD | sudo -S ln -sf /usr/local/bin/$latest_gpp /usr/local/bin/g++
	fi

	if [ ! -z "$latest_gfortran" ]; then
		echo "Linking the latest GFortran version: $latest_gfortran"
		echo $PASSWD | sudo -S ln -sf /usr/local/bin/$latest_gfortran /usr/local/bin/gfortran
	fi

	echo "Updated symbolic links for GCC, G++, and GFortran."

	export CC=gcc
	export CXX=g++
	export FC=gfortran
	export F77=gfortran
	export CFLAGS="-fPIC -fPIE -Wno-implicit-function-declaration -Wall"

	echo " "

	#IF statement for GNU compiler issue
	export GCC_VERSION=$(gcc -dumpfullversion | awk '{print$1}')
	export GFORTRAN_VERSION=$(gfortran -dumpfullversion | awk '{print$1}')
	export GPLUSPLUS_VERSION=$(g++ -dumpfullversion | awk '{print$1}')

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

	export FFLAGS="$fallow_argumen"
	export FCFLAGS="$fallow_argumen"

	echo "##########################################"
	echo "FFLAGS = $FFLAGS"
	echo "FCFLAGS = $FCFLAGS"
	echo "CFLAGS = $CFLAGS"
	echo "##########################################"

	echo " "

	#############################zlib############################
	#Uncalling compilers due to comfigure issue with zlib1.2.12
	#With CC & CXX definied ./configure uses different compiler Flags

	cd "${WRF_FOLDER}"/WRF_CHEM_Tools/Downloads
	tar -xvzf zlib-$Zlib_Version.tar.gz
	cd zlib-$Zlib_Version/
	autoreconf -i -f 2>&1 | tee autoreconf.log
	./configure --prefix=$DIR/grib2 2>&1 | tee configure.log
	automake -a -f 2>&1 | tee automake.log
	make -j $CPU_HALF_EVEN 2>&1 | tee make.log
	make -j $CPU_HALF_EVEN check 2>&1 | tee make.check.log
	make -j $CPU_HALF_EVEN install 2>&1 | tee make.install.log
	#make check

	echo " "

	##############################MPICH############################
	cd "${WRF_FOLDER}"/WRF_CHEM_Tools/Downloads
	tar -xvzf mpich-$Mpich_Version.tar.gz
	cd mpich-$Mpich_Version/
	autoreconf -i -f 2>&1 | tee autoreconf.log
	F90= ./configure --prefix=$DIR/MPICH --with-device=ch3 FFLAGS=$FFLAGS FCFLAGS=$FCFLAGS 2>&1 | tee configure.log
	automake -a -f 2>&1 | tee automake.log
	make -j $CPU_HALF_EVEN 2>&1 | tee make.log
	make -j $CPU_HALF_EVEN check 2>&1 | tee make.check.log
	make -j $CPU_HALF_EVEN install 2>&1 | tee make.install.log
	#make check

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
	tar -xvzf libpng-$Libpng_Version.tar.gz
	cd libpng-$Libpng_Version/
	autoreconf -i -f 2>&1 | tee autoreconf.log
	CC=$MPICC FC=$MPIFC F77=$MPIF77 F90=$MPIF90 CXX=$MPICXX CFLAGS=$CFLAGS FFLAGS=$FFLAGS FCFLAGS=$FCFLAGS ./configure --prefix=$DIR/grib2 2>&1 | tee configure.log
	automake -a -f 2>&1 | tee automake.log
	make -j $CPU_HALF_EVEN 2>&1 | tee make.log
	make -j $CPU_HALF_EVEN check 2>&1 | tee make.check.log
	make -j $CPU_HALF_EVEN install 2>&1 | tee make.install.log
	#make check
	#make check

	echo " "
	#############################JasPer############################

	cd "${WRF_FOLDER}"/WRF_CHEM_Tools/Downloads
	unzip jasper-$Jasper_Version.zip
	cd jasper-$Jasper_Version/
	autoreconf -i -f 2>&1 | tee autoreconf.log
	CC=$MPICC FC=$MPIFC F77=$MPIF77 F90=$MPIF90 CXX=$MPICXX CFLAGS=$CFLAGS FFLAGS=$FFLAGS FCFLAGS=$FCFLAGS ./configure --prefix=$DIR/grib2 2>&1 | tee configure.log
	automake -a -f 2>&1 | tee automake.log
	make -j $CPU_HALF_EVEN 2>&1 | tee make.log
	make -j $CPU_HALF_EVEN check 2>&1 | tee make.check.log
	make -j $CPU_HALF_EVEN install 2>&1 | tee make.install.log
	export JASPERLIB=$DIR/grib2/lib
	export JASPERINC=$DIR/grib2/include

	echo " "
	#############################hdf5 library for netcdf4 functionality############################

	cd "${WRF_FOLDER}"/WRF_CHEM_Tools/Downloads
	tar -xvzf hdf5-$HDF5_Version-$HDF5_Sub_Version.tar.gz
	cd hdf5-$HDF5_Version-$HDF5_Sub_Version
	autoreconf -i -f 2>&1 | tee autoreconf.log
	CC=$MPICC FC=$MPIFC F77=$MPIF77 F90=$MPIF90 CXX=$MPICXX CFLAGS=$CFLAGS FFLAGS=$FFLAGS FCFLAGS=$FCFLAGS ./configure --prefix=$DIR/grib2 --with-zlib=$DIR/grib2 --enable-hl --enable-fortran --enable-parallel 2>&1 | tee configure.log
	automake -a -f 2>&1 | tee automake.log
	make -j $CPU_HALF_EVEN 2>&1 | tee make.log
	make -j $CPU_HALF_EVEN check 2>&1 | tee make.check.log
	make -j $CPU_HALF_EVEN install 2>&1 | tee make.install.log
	#make check

	export HDF5=$DIR/grib2
	export PHDF5=$DIR/grib2
	export LD_LIBRARY_PATH=$DIR/grib2/lib:$LD_LIBRARY_PATH

	echo " "

	#############################Install Parallel-netCDF##############################
	#Make file created with half of available cpu cores
	#Hard path for MPI added
	##################################################################################
	cd "${WRF_FOLDER}"/WRF_CHEM_Tools/Downloads
	tar -xvzf pnetcdf-$Pnetcdf_Version.tar.gz
	cd pnetcdf-$Pnetcdf_Version
	export MPIFC=$DIR/MPICH/bin/mpifort
	export MPIF77=$DIR/MPICH/bin/mpifort
	export MPIF90=$DIR/MPICH/bin/mpifort
	export MPICC=$DIR/MPICH/bin/mpicc
	export MPICXX=$DIR/MPICH/bin/mpicxx
	autoreconf -i -f 2>&1 | tee autoreconf.log
	./configure --prefix=$DIR/grib2 --enable-shared --enable-static 2>&1 | tee configure.log
	automake -a -f 2>&1 | tee automake.log
	make -j $CPU_HALF_EVEN 2>&1 | tee make.log
	make -j $CPU_HALF_EVEN check 2>&1 | tee make.check.log
	make -j $CPU_HALF_EVEN install 2>&1 | tee make.install.log
	#make check

	export PNETCDF=$DIR/grib2

	##############################Install NETCDF C Library############################
	cd "${WRF_FOLDER}"/WRF_CHEM_Tools/Downloads
	tar -xzvf v$Netcdf_C_Version.tar.gz
	cd netcdf-c-$Netcdf_C_Version/
	export CPPFLAGS=-I$DIR/grib2/include
	export LDFLAGS=-L$DIR/grib2/lib
	export LIBS="-lhdf5_hl -lhdf5 -lz -lcurl -lgfortran -lgcc -lm -ldl -lpnetcdf"
	autoreconf -i -f 2>&1 | tee autoreconf.log
	CC=$MPICC FC=$MPIFC F77=$MPIF77 F90=$MPIF90 CXX=$MPICXX CFLAGS=$CFLAGS FFLAGS=$FFLAGS FCFLAGS=$FCFLAGS ./configure --prefix=$DIR/NETCDF --disable-dap --enable-netcdf-4 --enable-netcdf4 --enable-shared --enable-static --enable-pnetcdf --enable-cdf5 --enable-parallel-tests 2>&1 | tee configure.log
	automake -a -f 2>&1 | tee automake.log
	make -j $CPU_HALF_EVEN 2>&1 | tee make.log
	make -j $CPU_HALF_EVEN install 2>&1 | tee make.make.log
	#make check

	export PATH=$DIR/NETCDF/bin:$PATH
	export NETCDF=$DIR/NETCDF
	echo " "

	##############################NetCDF fortran library############################
	cd "${WRF_FOLDER}"/WRF_CHEM_Tools/Downloads
	tar -xvzf v$Netcdf_Fortran_Version.tar.gz
	cd netcdf-fortran-$Netcdf_Fortran_Version/
	export LD_LIBRARY_PATH=$DIR/NETCDF/lib:$LD_LIBRARY_PATH
	export CPPFLAGS="-I$DIR/NETCDF/include -I$DIR/grib2/include"
	export LDFLAGS="-L$DIR/NETCDF/lib -L$DIR/grib2/lib"
	export LIBS="-lnetcdf -lpnetcdf -lcurl -lhdf5_hl -lhdf5 -lz -lm -ldl -lgcc -lgfortran"
	autoreconf -i -f 2>&1 | tee autoreconf.log
	CC=$MPICC FC=$MPIFC F77=$MPIF77 F90=$MPIF90 CXX=$MPICXX CFLAGS=$CFLAGS FFLAGS=$FFLAGS FCFLAGS=$FCFLAGS ./configure --prefix=$DIR/NETCDF --enable-netcdf-4 --enable-netcdf4 --enable-shared --enable-static --enable-parallel-tests --enable-hdf5 2>&1 | tee configure.log
	automake -a -f 2>&1 | tee automake.log
	make -j $CPU_HALF_EVEN 2>&1 | tee make.log
	make -j $CPU_HALF_EVEN check 2>&1 | tee make.check.log
	make -j $CPU_HALF_EVEN install 2>&1 | tee make.install.log
	#make check

	echo " "
	#################################### System Environment Tests ##############

	cd "${WRF_FOLDER}"/WRF_CHEM_Tools/Downloads
	wget -c https://www2.mmm.ucar.edu/wrf/OnLineTutorial/compile_tutorial/tar_files/Fortran_C_NETCDF_MPI_tests.tar
	wget -c https://www2.mmm.ucar.edu/wrf/OnLineTutorial/compile_tutorial/tar_files/Fortran_C_tests.tar

	tar -xvf Fortran_C_tests.tar -C "${WRF_FOLDER}"/WRF_CHEM_Tools/Tests/Environment
	tar -xvf Fortran_C_NETCDF_MPI_tests.tar -C "${WRF_FOLDER}"/WRF_CHEM_Tools/Tests/Compatibility

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
	tar -xvf mozbc.tar -C "${WRF_FOLDER}"/WRF_CHEM_Tools/mozbc
	echo ""
	echo "Unpacking MEGAN Bio Emission."
	tar -xvf megan_bio_emiss.tar -C "${WRF_FOLDER}"/WRF_CHEM_Tools/megan_bio_emiss
	echo ""
	echo "Unpacking MEGAN Bio Emission Data."
	tar -xzvf megan.data.tar.gz -C "${WRF_FOLDER}"/WRF_CHEM_Tools/megan_bio_data
	echo ""
	echo "Unpacking Wes Coldens"
	tar -xvf wes-coldens.tar -C "${WRF_FOLDER}"/WRF_CHEM_Tools/wes_coldens
	echo ""
	echo "Unpacking Unpacking ANTHRO Emission."
	tar -xvf ANTHRO.tar -C "${WRF_FOLDER}"/WRF_CHEM_Tools/ANTHRO_EMIS
	echo ""
	echo "Unpacking EDGAR-HTAP."
	tar -xzvf EDGAR-HTAP.tgz -C "${WRF_FOLDER}"/WRF_CHEM_Tools/EDGAR_HTAP
	echo ""
	echo "Unpacking EPA ANTHRO Emission."
	tar -xzvf EPA_ANTHRO_EMIS.tgz -C "${WRF_FOLDER}"/WRF_CHEM_Tools/EPA_ANTHRO_EMIS
	echo ""
	echo "Unpacking Upper Boundary Conditions."
	tar -xvf UBC_inputs.tar -C "${WRF_FOLDER}"/WRF_CHEM_Tools/UBC
	echo ""
	echo "Unpacking Aircraft Preprocessor Files."
	echo ""
	tar -xvf aircraft_preprocessor_files.tar -C "${WRF_FOLDER}"/WRF_CHEM_Tools/Aircraft
	echo ""
	echo "Unpacking Fire INventory from NCAR (FINN)"
	tar -xzvf fire_emis.tgz -C "${WRF_FOLDER}"/WRF_CHEM_Tools/FINN
	tar -xvf fire_emis_input.tar
	tar -zxvf grass_from_img.nc.tgz -C "${WRF_FOLDER}"/WRF_CHEM_Tools/FINN/grid_finn_fire_emis_v2020/src
	tar -zxvf tempfor_from_img.nc.tgz -C "${WRF_FOLDER}"/WRF_CHEM_Tools/FINN/grid_finn_fire_emis_v2020/src
	tar -zxvf shrub_from_img.nc.tgz -C "${WRF_FOLDER}"/WRF_CHEM_Tools/FINN/grid_finn_fire_emis_v2020/src
	tar -zxvf tropfor_from_img.nc.tgz -C "${WRF_FOLDER}"/WRF_CHEM_Tools/FINN/grid_finn_fire_emis_v2020/src

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
	echo "WRF CHEM Tools compiled with latest version of NETCDF files available on 01/01/2023"
	echo "If error occurs using WRFCHEM tools please update your NETCDF libraries or reconfigure with older libraries"
	echo "This is a WRC Chem Community tool made by a private user and is not supported by UCAR/NCAR"
	echo "BASH Script Finished"

fi

if [ "$macos_64bit_GNU" = "1" ] && [ "$MAC_CHIP" = "ARM" ]; then

	#############################basic package managment############################
	brew update
	outdated_packages=$(brew outdated --quiet)

	# List of packages to check/install
	packages=(
		"autoconf" "automake" "bison" "byacc" "cmake" "curl" "flex" "gcc"
		"gdal" "gedit" "git" "gnu-sed" "grads" "imagemagick" "java" "ksh"
		"libtool" "m4" "make" "python@3.10" "snapcraft" "tcsh" "wget"
		"xauth" "xorgproto" "xorgrgb" "xquartz"
	)

	for pkg in "${packages[@]}"; do
		if brew list "$pkg" &>/dev/null; then
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
		cd
		pwd
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
	export CPU_HALF=$(($CPU_CORE / 2))
	#1/2 of availble cores on system
	export CPU_HALF_EVEN=$(($CPU_HALF - ($CPU_HALF % 2)))
	#Forces CPU cores to even number to avoid partial core export. ie 7 cores would be 3.5 cores.

	if [ $CPU_CORE -le $CPU_6CORE ]; then #If statement for low core systems.  Forces computers to only use 1 core if there are 4 cores or less on the system. then
		export CPU_HALF_EVEN="2"
	else
		export CPU_HALF_EVEN=$(($CPU_HALF - ($CPU_HALF % 2)))
	fi

	echo "##########################################"
	echo "Number of Threads being used $CPU_HALF_EVEN"
	echo "##########################################"
	echo " "

	##############################Downloading Libraries############################

	cd "${WRF_FOLDER}"/WRF_CHEM_Tools/Downloads
	wget -c https://github.com/madler/zlib/releases/download/v$Zlib_Version/zlib-$Zlib_Version.tar.gz
	wget -c https://github.com/HDFGroup/hdf5/releases/download/hdf5_$HDF5_Version.$HDF5_Sub_Version/hdf5-$HDF5_Version-$HDF5_Sub_Version.tar.gz
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
	latest_gcc=$(ls gcc-* 2>/dev/null | grep -o 'gcc-[0-9]*' | sort -V | tail -n 1)
	latest_gpp=$(ls g++-* 2>/dev/null | grep -o 'g++-[0-9]*' | sort -V | tail -n 1)
	latest_gfortran=$(ls gfortran-* 2>/dev/null | grep -o 'gfortran-[0-9]*' | sort -V | tail -n 1)

	# Check if the latest versions were found, and link them
	if [ -n "$latest_gcc" ]; then
		echo "Linking the latest GCC version: $latest_gcc"
		echo $PASSWD | sudo -S ln -sf $latest_gcc gcc
	else
		echo "No GCC version found."
	fi

	if [ -n "$latest_gpp" ]; then
		echo "Linking the latest G++ version: $latest_gpp"
		echo $PASSWD | sudo -S ln -sf $latest_gpp g++
	else
		echo "No G++ version found."
	fi

	if [ -n "$latest_gfortran" ]; then
		echo "Linking the latest GFortran version: $latest_gfortran"
		echo $PASSWD | sudo -S ln -sf $latest_gfortran gfortran
	else
		echo "No GFortran version found."
	fi

	# Return to the home directory
	cd

	# Source bashrc and bash_profile to reload the environment settings
	source ~/.bashrc
	source ~/.bash_profile

	# Check if the versions were successfully updated
	gcc --version
	g++ --version
	gfortran --version
	export CC=gcc
	export CXX=g++
	export FC=gfortran
	export F77=gfortran
	export CFLAGS="-fPIC -fPIE -Wno-implicit-function-declaration -Wall"

	echo " "

	#IF statement for GNU compiler issue
	export GCC_VERSION=$(gcc -dumpfullversion | awk '{print$1}')
	export GFORTRAN_VERSION=$(gfortran -dumpfullversion | awk '{print$1}')
	export GPLUSPLUS_VERSION=$(g++ -dumpfullversion | awk '{print$1}')

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

	export FFLAGS="$fallow_argumen"
	export FCFLAGS="$fallow_argumen"

	echo "##########################################"
	echo "FFLAGS = $FFLAGS"
	echo "FCFLAGS = $FCFLAGS"
	echo "CFLAGS = $CFLAGS"
	echo "##########################################"

	echo " "

	#############################zlib############################
	#Uncalling compilers due to comfigure issue with zlib1.2.12
	#With CC & CXX definied ./configure uses different compiler Flags

	cd "${WRF_FOLDER}"/WRF_CHEM_Tools/Downloads
	tar -xvzf zlib-$Zlib_Version.tar.gz
	cd zlib-$Zlib_Version/
	autoreconf -i -f 2>&1 | tee autoreconf.log
	./configure --prefix=$DIR/grib2 2>&1 | tee configure.log
	automake -a -f 2>&1 | tee automake.log
	make -j $CPU_HALF_EVEN 2>&1 | tee make.log
	make -j $CPU_HALF_EVEN check 2>&1 | tee make.check.log
	make -j $CPU_HALF_EVEN install 2>&1 | tee make.install.log
	#make check

	echo " "

	##############################MPICH############################
	cd "${WRF_FOLDER}"/WRF_CHEM_Tools/Downloads
	tar -xvzf mpich-$Mpich_Version.tar.gz
	cd mpich-$Mpich_Version/"${WRF_FOLDER}"/WRF_CHEM_Tools/Tests/Compatibility
	autoreconf -i -f 2>&1 | tee autoreconf.log
	F90= ./configure --prefix=$DIR/MPICH --with-device=ch3 FFLAGS=$FFLAGS FCFLAGS=$FCFLAGS 2>&1 | tee configure.log
	automake -a -f 2>&1 | tee automake.log
	make -j $CPU_HALF_EVEN 2>&1 | tee make.log
	make -j $CPU_HALF_EVEN install 2>&1 | tee make.make.log
	#make check

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
	tar -xvzf libpng-$Libpng_Version.tar.gz
	cd libpng-$Libpng_Version/
	autoreconf -i -f 2>&1 | tee autoreconf.log
	CC=$MPICC FC=$MPIFC F77=$MPIF77 F90=$MPIF90 CXX=$MPICXX CFLAGS=$CFLAGS FFLAGS=$FFLAGS FCFLAGS=$FCFLAGS ./configure --prefix=$DIR/grib2 2>&1 | tee configure.log
	automake -a -f 2>&1 | tee automake.log
	make -j $CPU_HALF_EVEN 2>&1 | tee make.log
	make -j $CPU_HALF_EVEN check 2>&1 | tee make.check.log
	make -j $CPU_HALF_EVEN install 2>&1 | tee make.install.log
	#make check
	#make check

	echo " "
	#############################JasPer############################

	cd "${WRF_FOLDER}"/WRF_CHEM_Tools/Downloads
	unzip jasper-$Jasper_Version.zip
	cd jasper-$Jasper_Version/
	autoreconf -i -f 2>&1 | tee autoreconf.log
	CC=$MPICC FC=$MPIFC F77=$MPIF77 F90=$MPIF90 CXX=$MPICXX CFLAGS=$CFLAGS FFLAGS=$FFLAGS FCFLAGS=$FCFLAGS ./configure --prefix=$DIR/grib2 2>&1 | tee configure.log
	automake -a -f 2>&1 | tee automake.log
	make -j $CPU_HALF_EVEN 2>&1 | tee make.log
	make -j $CPU_HALF_EVEN check 2>&1 | tee make.check.log
	make -j $CPU_HALF_EVEN install 2>&1 | tee make.install.log
	export JASPERLIB=$DIR/grib2/lib
	export JASPERINC=$DIR/grib2/include

	echo " "
	#############################hdf5 library for netcdf4 functionality############################

	cd "${WRF_FOLDER}"/WRF_CHEM_Tools/Downloads
	tar -xvzf hdf5-$HDF5_Version-$HDF5_Sub_Version.tar.gz
	cd hdf5-$HDF5_Version-$HDF5_Sub_Version
	autoreconf -i -f 2>&1 | tee autoreconf.log
	CC=$MPICC FC=$MPIFC F77=$MPIF77 F90=$MPIF90 CXX=$MPICXX CFLAGS=$CFLAGS FFLAGS=$FFLAGS FCFLAGS=$FCFLAGS ./configure --prefix=$DIR/grib2 --with-zlib=$DIR/grib2 --enable-hl --enable-fortran --enable-parallel 2>&1 | tee configure.log
	automake -a -f 2>&1 | tee automake.log
	make -j $CPU_HALF_EVEN 2>&1 | tee make.log
	make -j $CPU_HALF_EVEN check 2>&1 | tee make.check.log
	make -j $CPU_HALF_EVEN install 2>&1 | tee make.install.log
	#make check

	export HDF5=$DIR/grib2
	export PHDF5=$DIR/grib2
	export LD_LIBRARY_PATH=$DIR/grib2/lib:$LD_LIBRARY_PATH

	echo " "

	#############################Install Parallel-netCDF##############################
	#Make file created with half of available cpu cores
	#Hard path for MPI added
	##################################################################################
	cd "${WRF_FOLDER}"/WRF_CHEM_Tools/Downloads
	tar -xvzf pnetcdf-$Pnetcdf_Version.tar.gz
	cd pnetcdf-$Pnetcdf_Version
	export MPIFC=$DIR/MPICH/bin/mpifort
	export MPIF77=$DIR/MPICH/bin/mpifort
	export MPIF90=$DIR/MPICH/bin/mpifort
	export MPICC=$DIR/MPICH/bin/mpicc
	export MPICXX=$DIR/MPICH/bin/mpicxx
	autoreconf -i -f 2>&1 | tee autoreconf.log
	./configure --prefix=$DIR/grib2 --enable-shared --enable-static 2>&1 | tee configure.log
	automake -a -f 2>&1 | tee automake.log
	make -j $CPU_HALF_EVEN 2>&1 | tee make.log
	make -j $CPU_HALF_EVEN check 2>&1 | tee make.check.log
	make -j $CPU_HALF_EVEN install 2>&1 | tee make.install.log
	#make check

	export PNETCDF=$DIR/grib2

	##############################Install NETCDF C Library############################
	cd "${WRF_FOLDER}"/WRF_CHEM_Tools/Downloads
	tar -xzvf v$Netcdf_C_Version.tar.gz
	cd netcdf-c-$Netcdf_C_Version/
	export CPPFLAGS=-I$DIR/grib2/include
	export LDFLAGS=-L$DIR/grib2/lib
	export LIBS="-lhdf5_hl -lhdf5 -lz -lcurl -lgfortran -lgcc -lm -ldl -lpnetcdf"
	autoreconf -i -f 2>&1 | tee autoreconf.log
	CC=$MPICC FC=$MPIFC F77=$MPIF77 F90=$MPIF90 CXX=$MPICXX CFLAGS=$CFLAGS FFLAGS=$FFLAGS FCFLAGS=$FCFLAGS ./configure --prefix=$DIR/NETCDF --disable-dap --enable-netcdf-4 --enable-netcdf4 --enable-shared --enable-static --enable-pnetcdf --enable-cdf5 --enable-parallel-tests 2>&1 | tee configure.log
	automake -a -f 2>&1 | tee automake.log
	make -j $CPU_HALF_EVEN 2>&1 | tee make.log
	make -j $CPU_HALF_EVEN check 2>&1 | tee make.check.log
	make -j $CPU_HALF_EVEN install 2>&1 | tee make.install.log
	#make check

	export PATH=$DIR/NETCDF/bin:$PATH
	export NETCDF=$DIR/NETCDF
	echo " "

	##############################NetCDF fortran library############################
	cd "${WRF_FOLDER}"/WRF_CHEM_Tools/Downloads
	tar -xvzf v$Netcdf_Fortran_Version.tar.gz
	cd netcdf-fortran-$Netcdf_Fortran_Version/
	export LD_LIBRARY_PATH=$DIR/NETCDF/lib:$LD_LIBRARY_PATH
	export CPPFLAGS="-I$DIR/NETCDF/include -I$DIR/grib2/include"
	export LDFLAGS="-L$DIR/NETCDF/lib -L$DIR/grib2/lib"
	export LIBS="-lnetcdf -lpnetcdf -lcurl -lhdf5_hl -lhdf5 -lz -lm -ldl -lgcc -lgfortran"
	autoreconf -i -f 2>&1 | tee autoreconf.log
	CC=$MPICC FC=$MPIFC F77=$MPIF77 F90=$MPIF90 CXX=$MPICXX CFLAGS=$CFLAGS FFLAGS=$FFLAGS FCFLAGS=$FCFLAGS ./configure --prefix=$DIR/NETCDF --enable-netcdf-4 --enable-netcdf4 --enable-shared --enable-static --enable-parallel-tests --enable-hdf5 2>&1 | tee configure.log
	automake -a -f 2>&1 | tee automake.log
	make -j $CPU_HALF_EVEN 2>&1 | tee make.log
	make -j $CPU_HALF_EVEN check 2>&1 | tee make.check.log
	make -j $CPU_HALF_EVEN install 2>&1 | tee make.install.log
	#make check

	echo " "
	#################################### System Environment Tests ##############

	cd "${WRF_FOLDER}"/WRF_CHEM_Tools/Downloads
	wget -c https://www2.mmm.ucar.edu/wrf/OnLineTutorial/compile_tutorial/tar_files/Fortran_C_NETCDF_MPI_tests.tar
	wget -c https://www2.mmm.ucar.edu/wrf/OnLineTutorial/compile_tutorial/tar_files/Fortran_C_tests.tar

	tar -xvf Fortran_C_tests.tar -C "${WRF_FOLDER}"/WRF_CHEM_Tools/Tests/Environment
	tar -xvf Fortran_C_NETCDF_MPI_tests.tar -C "${WRF_FOLDER}"/WRF_CHEM_Tools/Tests/Compatibility

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
	tar -xvf mozbc.tar -C "${WRF_FOLDER}"/WRF_CHEM_Tools/mozbc
	echo ""
	echo "Unpacking MEGAN Bio Emission."
	tar -xvf megan_bio_emiss.tar -C "${WRF_FOLDER}"/WRF_CHEM_Tools/megan_bio_emiss
	echo ""
	echo "Unpacking MEGAN Bio Emission Data."
	tar -xzvf megan.data.tar.gz -C "${WRF_FOLDER}"/WRF_CHEM_Tools/megan_bio_data
	echo ""
	echo "Unpacking Wes Coldens"
	tar -xvf wes-coldens.tar -C "${WRF_FOLDER}"/WRF_CHEM_Tools/wes_coldens
	echo ""
	echo "Unpacking Unpacking ANTHRO Emission."
	tar -xvf ANTHRO.tar -C "${WRF_FOLDER}"/WRF_CHEM_Tools/ANTHRO_EMIS
	echo ""
	echo "Unpacking EDGAR-HTAP."
	tar -xzvf EDGAR-HTAP.tgz -C "${WRF_FOLDER}"/WRF_CHEM_Tools/EDGAR_HTAP
	echo ""
	echo "Unpacking EPA ANTHRO Emission."
	tar -xzvf EPA_ANTHRO_EMIS.tgz -C "${WRF_FOLDER}"/WRF_CHEM_Tools/EPA_ANTHRO_EMIS
	echo ""
	echo "Unpacking Upper Boundary Conditions."
	tar -xvf UBC_inputs.tar -C "${WRF_FOLDER}"/WRF_CHEM_Tools/UBC
	echo ""
	echo "Unpacking Aircraft Preprocessor Files."
	echo ""
	tar -xvf aircraft_preprocessor_files.tar -C "${WRF_FOLDER}"/WRF_CHEM_Tools/Aircraft
	echo ""
	echo "Unpacking Fire INventory from NCAR (FINN)"
	tar -xzvf fire_emis.tgz -C "${WRF_FOLDER}"/WRF_CHEM_Tools/FINN
	tar -xvf fire_emis_input.tar
	tar -zxvf grass_from_img.nc.tgz -C "${WRF_FOLDER}"/WRF_CHEM_Tools/FINN/grid_finn_fire_emis_v2020/src
	tar -zxvf tempfor_from_img.nc.tgz -C "${WRF_FOLDER}"/WRF_CHEM_Tools/FINN/grid_finn_fire_emis_v2020/src
	tar -zxvf shrub_from_img.nc.tgz -C "${WRF_FOLDER}"/WRF_CHEM_Tools/FINN/grid_finn_fire_emis_v2020/src
	tar -zxvf tropfor_from_img.nc.tgz -C "${WRF_FOLDER}"/WRF_CHEM_Tools/FINN/grid_finn_fire_emis_v2020/src

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
	echo "WRF CHEM Tools compiled with latest version of NETCDF files available on 01/01/2023"
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
