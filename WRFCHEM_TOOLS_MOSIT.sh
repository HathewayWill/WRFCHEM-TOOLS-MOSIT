#!/bin/bash

#Conda environment test
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
export HDF5_Version=1_14_2
export Zlib_Version=1.2.13
export Netcdf_C_Version=4.9.2
export Netcdf_Fortran_Version=4.6.1
export Mpich_Version=4.1.2
export Libpng_Version=1.6.39
export Jasper_Version=1.900.1
export Pnetcdf_Version=1.12.3

############################### System Architecture Type #################
# 32 or 64 bit
##########################################################################
export SYS_ARCH=$(uname -m)

if [ "$SYS_ARCH" = "x86_64" ] || [ "$SYS_ARCH" = "arm64" ]; then
	export SYSTEMBIT="64"
else
	export SYSTEMBIT="32"
fi

if [ "$SYS_ARCH" = "arm64" ]; then
	export MAC_CHIP="ARM"
else
	export MAC_CHIP="Intel"
fi

############################# System OS Version #############################
# Macos or linux
# Make note that this script only works for Debian Linux kernals
#############################################################################
export SYS_OS=$(uname -s)

if [ "$SYS_OS" = "Darwin" ]; then
	export SYSTEMOS="MacOS"
elif [ "$SYS_OS" = "Linux" ]; then
	export SYSTEMOS="Linux"
fi

########## Centos Test #############
if [ "$SYSTEMOS" = "Linux" ]; then
	export YUM=$(command -v yum)
	if [ "$YUM" != "" ]; then
		echo " yum found"
		echo "Your system is a CentOS based system"
		export SYSTEMOS=CentOS
	fi

fi

############################### Intel or GNU Compiler Option #############

if [ "$SYSTEMBIT" = "32" ] && [ "$SYSTEMOS" = "CentOS" ]; then
	echo "Your system is not compatibile with this script."
	exit
fi

if [ "$SYSTEMBIT" = "64" ] && [ "$SYSTEMOS" = "CentOS" ]; then
	echo "Your system is a 64-bit version of CentOS Linux Kernel"
	echo " "
	echo "Intel compilers are not compatible with this script"
	echo " "

	if [ -v $Centos_64bit_GNU ]; then
		echo "The environment variable Centos_64bit_GNU is already set."
	else
		echo "The environment variable Centos_64bit_GNU is not set."
		echo "Setting compiler to GNU"
		export Centos_64bit_GNU=1

		if [ "$(gcc -dumpversion 2>&1 | awk '{print $1}')" -lt 9 ]; then
			export Centos_64bit_GNU=2
			echo "OLD GNU FILES FOUND"
		fi
	fi
else
	echo "The environment variable Centos_64bit_GNU is not set."
fi

if [ "$SYSTEMBIT" = "32" ] && [ "$SYSTEMOS" = "MacOS" ]; then
	echo "Your system is not compatibile with this script."
	exit
fi

if [ "$SYSTEMBIT" = "64" ] && [ "$SYSTEMOS" = "MacOS" ] && [ "$MAC_CHIP" = "Intel" ]; then
	echo "Your system is a 64bit version of MacOS"
	echo " "
	echo "Intel compilers are not compatibile with this script"
	echo " "

	if [ -v $macos_64bit_GNU ]; then
		echo "The environment variable macos_64bit_GNU is already set."
	else
		echo "The environment variable macos_64bit_GNU is not set."
		echo "Setting compiler to GNU"
		export macos_64bit_GNU=1

	echo " "
	echo "Xcode Command Line Tools & Homebrew are required for this script."
	echo " "
	echo "Installing Homebrew and Xcode Command Line Tools now"
	echo " "
	echo "Please enter password when prompted"
	/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/master/install.sh)"

	(
		echo
		echo 'eval "$(/usr/local/bin/brew shellenv)"'
	) >>~/.profile
	eval "$(/usr/local/bin/brew shellenv)"

	chsh -s /bin/bash
  fi
fi

if [ "$SYSTEMBIT" = "64" ] && [ "$SYSTEMOS" = "MacOS" ] && [ "$MAC_CHIP" = "ARM" ]; then
	echo "Your system is a 64bit version of MacOS with arm64"
	echo " "
	echo "Intel compilers are not compatibile with this script"
	echo " "
	echo "Setting compiler to GNU"

	if [ -v $macos_64bit_GNU ]; then
		echo "The environment variable macos_64bit_GNU is already set."
	else
		echo "The environment variable macos_64bit_GNU is not set."
		export macos_64bit_GNU=1
	fi

	echo " "
	echo "Xcode Command Line Tools & Homebrew are required for this script."
	echo " "
	echo "Installing Homebrew and Xcode Command Line Tools now"
	echo " "
	echo "Please enter password when prompted"
	/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/master/install.sh)"

	(
		echo
		echo 'eval "$(/opt/homebrew/bin/brew shellenv)"'
	) >>~/.profile
	eval "$(/opt/homebrew/bin/brew shellenv)"

	chsh -s /bin/bash
fi

if [ "$SYSTEMBIT" = "64" ] && [ "$SYSTEMOS" = "Linux" ]; then
	echo "Your system is 64bit version of Debian Linux Kernal"
	echo " "

	if [ -n "$Ubuntu_64bit_Intel" ]; then
		echo "The environment variable Ubuntu_64bit_Intel is already set."
		else
			echo "The environment variable Ubuntu_64bit_Intel is not set."
			while read -r -p "Which compiler do you want to use?
    	-Intel
     	--Please note that Hurricane WRF (HWRF) is only compatibile with Intel Compilers.

    	-GNU

    	Please answer Intel or GNU and press enter (case sensative).
    	" yn; do

				case $yn in
					Intel)
					echo " "
					echo "Intel is selected for installation"
					export Ubuntu_64bit_Intel=1
					break
					;;
					GNU)
					echo "-------------------------------------------------- "
					echo " "
					echo "GNU is selected for installation"
					export Ubuntu_64bit_GNU=1
					break
					;;
					*)
					echo " "
					echo "Please answer Intel or GNU (case sensative)."
					;;

				esac
			done
	fi
fi

if [ "$SYSTEMBIT" = "32" ] && [ "$SYSTEMOS" = "Linux" ]; then
	echo "Your system is not compatibile with this script."
	exit
fi

############################# Enter sudo users information #############################

if [[ -n "$PASSWD" ]]; then
	echo "Using existing password: $PASSWD"
else
	echo -e "\nPassword is only saved locally and will not be visible when typing."
	read -r -s -p "Please enter your sudo password: " PASSWD
fi

echo -e "\nBeginning Installation"

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

if [ "$Centos_64bit_GNU" = "1" ]; then

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
	echo $PASSWD | sudo echo $PASSWD | sudo -S pip3 install python-dateutil
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
	export WRFCHEM_FOLDER=$HOME/WRFCHEM
	cd $HOME/WRFCHEM
	mkdir Downloads
	mkdir Libs
	mkdir Libs/grib2
	mkdir Libs/NETCDF
	mkdir $WRFCHEM_FOLDER/WRF_CHEM_Tools
	mkdir $WRFCHEM_FOLDER/WRF_CHEM_Tools/Libs
	mkdir $WRFCHEM_FOLDER/WRF_CHEM_Tools/Libs/grib2
	mkdir $WRFCHEM_FOLDER/WRF_CHEM_Tools/Libs/NETCDF
	mkdir $WRFCHEM_FOLDER/WRF_CHEM_Tools/Downloads
	mkdir $WRFCHEM_FOLDER/WRF_CHEM_Tools/mozbc
	mkdir $WRFCHEM_FOLDER/WRF_CHEM_Tools/megan_bio_emiss
	mkdir $WRFCHEM_FOLDER/WRF_CHEM_Tools/megan_bio_data
	mkdir $WRFCHEM_FOLDER/WRF_CHEM_Tools/wes_coldens
	mkdir $WRFCHEM_FOLDER/WRF_CHEM_Tools/ANTHRO_EMIS
	mkdir $WRFCHEM_FOLDER/WRF_CHEM_Tools/EDGAR_HTAP
	mkdir $WRFCHEM_FOLDER/WRF_CHEM_Tools/EPA_ANTHRO_EMIS
	mkdir $WRFCHEM_FOLDER/WRF_CHEM_Tools/UBC
	mkdir $WRFCHEM_FOLDER/WRF_CHEM_Tools/Aircraft
	mkdir $WRFCHEM_FOLDER/WRF_CHEM_Tools/FINN

	##############################Downloading Libraries############################
	cd $WRFCHEM_FOLDER/WRF_CHEM_Tools/Downloads

	wget -c https://github.com/madler/zlib/archive/refs/tags/v$Zlib_Version.tar.gz
	wget -c https://github.com/HDFGroup/hdf5/archive/refs/tags/hdf5-$HDF5_Version.tar.gz
	wget -c https://github.com/Unidata/netcdf-c/archive/refs/tags/v$Netcdf_C_Version.tar.gz
	wget -c https://github.com/Unidata/netcdf-fortran/archive/refs/tags/v$Netcdf_Fortran_Version.tar.gz
	wget -c https://download.sourceforge.net/libpng/libpng-$Libpng_Version.tar.gz
	wget -c https://www.ece.uvic.ca/~frodo/jasper/software/jasper-$Jasper_Version.zip
	wget -c https://github.com/pmodels/mpich/releases/download/v$Mpich_Version/mpich-$Mpich_Version.tar.gz
	wget -c https://parallel-netcdf.github.io/Release/pnetcdf-$Pnetcdf_Version.tar.gz

	#############################Core Management####################################
	export CPU_CORE=$(nproc) # number of available thread -rs on system
	export CPU_6CORE="6"
	export CPU_HALF=$(($CPU_CORE / 2))                    #half of availble cores on system
	export CPU_HALF_EVEN=$(($CPU_HALF - ($CPU_HALF % 2))) #Forces CPU cores to even number to avoid partial core export. ie 7 cores would be 3.5 cores.

	if [ $CPU_CORE -le $CPU_6CORE ]; then #If statement for low core systems.  Forces computers to only use 1 core if there are 4 cores or less on the system.
		export CPU_HALF_EVEN="2"
	else
		export CPU_HALF_EVEN=$(($CPU_HALF - ($CPU_HALF % 2)))
	fi

	echo "##########################################"
	echo "Number of thread -rs being used $CPU_HALF_EVEN"
	echo "##########################################"
	echo " "

	#############################Compilers############################
	export DIR=$WRFCHEM_FOLDER/WRF_CHEM_Tools/Libs
	export CC=gcc
	export CXX=g++
	export FC=gfortran
	export F77=gfortran
	export CFLAGS="-fPIC -fPIE"

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

	export FFLAGS="$fallow_argument -m64"
	export FCFLAGS="$fallow_argument -m64"

	echo "##########################################"
	echo "FFLAGS = $FFLAGS"
	echo "FCFLAGS = $FCFLAGS"
	echo "##########################################"

	#############################zlib############################
	#Uncalling compilers due to comfigure issue with zlib$Zlib_Version
	#With CC & CXX definied ./configure uses different compiler Flags

	cd $WRFCHEM_FOLDER/WRF_CHEM_Tools/Downloads
	tar -xvzf v$Zlib_Version.tar.gz
	cd zlib-$Zlib_Version/
	autoreconf -i -f 2>&1 | tee autoreconf.log
	./configure --prefix=$DIR/grib2 2>&1 | tee configure.log
	automake -a -f 2>&1 | tee automake.log
	make -j $CPU_HALF_EVEN 2>&1 | tee make.log
	make -j $CPU_HALF_EVEN install 2>&1 | tee make.make.log
	#make check

	##############################MPICH############################
	cd $WRFCHEM_FOLDER/WRF_CHEM_Tools/Downloads
	tar -xvzf mpich-$Mpich_Version.tar.gz
	cd mpich-$Mpich_Version/
	autoreconf -i -f 2>&1 | tee autoreconf.log
	F90= ./configure --prefix=$DIR/MPICH --with-device=ch3 FFLAGS="$fallow_argument -m64" FCFLAGS="$fallow_argument -m64" 2>&1 | tee configure.log
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
	cd $WRFCHEM_FOLDER/WRF_CHEM_Tools/Downloads
	export LDFLAGS=-L$DIR/grib2/lib
	export CPPFLAGS=-I$DIR/grib2/include
	tar -xvzf libpng-$Libpng_Version.tar.gz
	cd libpng-$Libpng_Version/
	autoreconf -i -f 2>&1 | tee autoreconf.log
	CC=$MPICC FC=$MPIFC F77=$MPIF77 F90=$MPIF90 CXX=$MPICXX ./configure --prefix=$DIR/grib2 2>&1 | tee configure.log
	automake -a -f 2>&1 | tee automake.log
	make -j $CPU_HALF_EVEN 2>&1 | tee make.log
	make -j $CPU_HALF_EVEN install 2>&1 | tee make.make.log
	#make check

	#############################JasPer############################
	cd $WRFCHEM_FOLDER/WRF_CHEM_Tools/Downloads
	unzip jasper-$Jasper_Version.zip
	cd jasper-$Jasper_Version/
	autoreconf -i -f 2>&1 | tee autoreconf.log
	CC=$MPICC FC=$MPIFC F77=$MPIF77 F90=$MPIF90 CXX=$MPICXX ./configure --prefix=$DIR/grib2 2>&1 | tee configure.log
	automake -a -f 2>&1 | tee automake.log
	make -j $CPU_HALF_EVEN 2>&1 | tee make.log
	make -j $CPU_HALF_EVEN install 2>&1 | tee make.make.log

	export JASPERLIB=$DIR/grib2/lib
	export JASPERINC=$DIR/grib2/include

	#############################hdf5 library for netcdf4 functionality############################
	cd $WRFCHEM_FOLDER/WRF_CHEM_Tools/Downloads
	tar -xvzf hdf5-$HDF5_Version.tar.gz
	cd hdf5-hdf5-$HDF5_Version
	autoreconf -i -f 2>&1 | tee autoreconf.log
	CC=$MPICC FC=$MPIFC F77=$MPIF77 F90=$MPIF90 CXX=$MPICXX ./configure --prefix=$DIR/grib2 --with-zlib=$DIR/grib2 --enable-hl --enable-fortran --enable-parallel 2>&1 | tee configure.log
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
	cd $WRFCHEM_FOLDER/WRF_CHEM_Tools/Downloads
	tar -xvzf pnetcdf-$Pnetcdf_Version.tar.gz
	cd pnetcdf-$Pnetcdf_Version
	autoreconf -i -f 2>&1 | tee autoreconf.log
	CC=$MPICC FC=$MPIFC F77=$MPIF77 F90=$MPIF90 CXX=$MPICXX ./configure --prefix=$DIR/grib2 --enable-shared --enable-static 2>&1 | tee configure.log
	automake -a -f 2>&1 | tee automake.log
	make -j $CPU_HALF_EVEN 2>&1 | tee make.log
	make -j $CPU_HALF_EVEN install 2>&1 | tee make.make.log
	#make check

	export PNETCDF=$DIR/grib2

	##############################Install NETCDF C Library############################
	cd $WRFCHEM_FOLDER/WRF_CHEM_Tools/Downloads
	tar -xzvf v$Netcdf_C_Version.tar.gz
	cd netcdf-c-$Netcdf_C_Version/
	export CPPFLAGS=-I$DIR/grib2/include
	export LDFLAGS=-L$DIR/grib2/lib
	export LIBS="-lhdf5_hl -lhdf5 -lz -lcurl -lgfortran -lgcc -lm -ldl -lpnetcdf"
	autoreconf -i -f 2>&1 | tee autoreconf.log
	CC=$MPICC FC=$MPIFC F77=$MPIF77 F90=$MPIF90 CXX=$MPICXX ./configure --prefix=$DIR/NETCDF --with-zlib=$DIR/grib2 --disable-dap --enable-netcdf-4 --enable-netcdf4 --enable-shared --enable-static--enable-pnetcdf --enable-cdf5 --enable-parallel-tests 2>&1 | tee configure.log
	automake -a -f 2>&1 | tee automake.log
	make -j $CPU_HALF_EVEN 2>&1 | tee make.log
	make -j $CPU_HALF_EVEN install 2>&1 | tee make.make.log
	#make check

	export PATH=$DIR/NETCDF/bin:$PATH
	export NETCDF=$DIR/NETCDF

	##############################NetCDF fortran library############################
	cd $WRFCHEM_FOLDER/WRF_CHEM_Tools/Downloads
	tar -xvzf v$Netcdf_Fortran_Version.tar.gz
	cd netcdf-fortran-$Netcdf_Fortran_Version/
	export LD_LIBRARY_PATH=$DIR/NETCDF/lib:$LD_LIBRARY_PATH
	export CPPFLAGS="-I$DIR/NETCDF/include -I$DIR/grib2/include"
	export LDFLAGS="-L$DIR/NETCDF/lib -L$DIR/grib2/lib"
	export LIBS="-lnetcdf -lpnetcdf -lcurl -lhdf5_hl -lhdf5 -lz -ldl -lgcc -lgfortran"
	autoreconf -i -f 2>&1 | tee autoreconf.log
	CC=$MPICC FC=$MPIFC CXX=$MPICXX F90=$MPIF90 F77=$MPIF77 ./configure --prefix=$DIR/NETCDF --enable-netcdf-4 --enable-netcdf4 --enable-shared --enable-static--enable-parallel-tests --enable-hdf5 2>&1 | tee configure.log
	automake -a -f 2>&1 | tee automake.log
	make -j $CPU_HALF_EVEN 2>&1 | tee make.log
	make -j $CPU_HALF_EVEN install 2>&1 | tee make.make.log
	#make check

	echo " "

	# Downloading WRF-CHEM Tools and untarring files
	cd $WRFCHEM_FOLDER/WRF_CHEM_Tools/Downloads

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
	tar -xvf mozbc.tar -C $WRFCHEM_FOLDER/WRF_CHEM_Tools/mozbc
	echo ""
	echo "Unpacking MEGAN Bio Emission."
	tar -xvf megan_bio_emiss.tar -C $WRFCHEM_FOLDER/WRF_CHEM_Tools/megan_bio_emiss
	echo ""
	echo "Unpacking MEGAN Bio Emission Data."
	tar -xzvf megan.data.tar.gz -C $WRFCHEM_FOLDER/WRF_CHEM_Tools/megan_bio_data
	echo ""
	echo "Unpacking Wes Coldens"
	tar -xvf wes-coldens.tar -C $WRFCHEM_FOLDER/WRF_CHEM_Tools/wes_coldens
	echo ""
	echo "Unpacking Unpacking ANTHRO Emission."
	tar -xvf ANTHRO.tar -C $WRFCHEM_FOLDER/WRF_CHEM_Tools/ANTHRO_EMIS
	echo ""
	echo "Unpacking EDGAR-HTAP."
	tar -xzvf EDGAR-HTAP.tgz -C $WRFCHEM_FOLDER/WRF_CHEM_Tools/EDGAR_HTAP
	echo ""
	echo "Unpacking EPA ANTHRO Emission."
	tar -xzvf EPA_ANTHRO_EMIS.tgz -C $WRFCHEM_FOLDER/WRF_CHEM_Tools/EPA_ANTHRO_EMIS
	echo ""
	echo "Unpacking Upper Boundary Conditions."
	tar -xvf UBC_inputs.tar -C $WRFCHEM_FOLDER/WRF_CHEM_Tools/UBC
	echo ""
	echo "Unpacking Aircraft Preprocessor Files."
	echo ""
	tar -xvf aircraft_preprocessor_files.tar -C $WRFCHEM_FOLDER/WRF_CHEM_Tools/Aircraft
	echo ""
	echo "Unpacking Fire INventory from NCAR (FINN)"
	tar -xzvf fire_emis.tgz -C $WRFCHEM_FOLDER/WRF_CHEM_Tools/FINN
	tar -xvf fire_emis_input.tar
	tar -zxvf grass_from_img.nc.tgz -C $WRFCHEM_FOLDER/WRF_CHEM_Tools/FINN/grid_finn_fire_emis_v2020/src
	tar -zxvf tempfor_from_img.nc.tgz -C $WRFCHEM_FOLDER/WRF_CHEM_Tools/FINN/grid_finn_fire_emis_v2020/src
	tar -zxvf shrub_from_img.nc.tgz -C $WRFCHEM_FOLDER/WRF_CHEM_Tools/FINN/grid_finn_fire_emis_v2020/src
	tar -zxvf tropfor_from_img.nc.tgz -C $WRFCHEM_FOLDER/WRF_CHEM_Tools/FINN/grid_finn_fire_emis_v2020/src

	mv $WRFCHEM_FOLDER/WRF_CHEM_Tools/Downloads/FINNv2.4_MOD_MOZART_2020_c20210617.txt.gz $WRFCHEM_FOLDER/WRF_CHEM_Tools/FINN
	mv $WRFCHEM_FOLDER/WRF_CHEM_Tools/Downloads/FINNv2.4_MOD_MOZART_2013_c20210617.txt.gz $WRFCHEM_FOLDER/WRF_CHEM_Tools/FINN
	mv $WRFCHEM_FOLDER/WRF_CHEM_Tools/Downloads/FINNv2.4_MODVRS_MOZART_2019_c20210615.txt.gz $WRFCHEM_FOLDER/WRF_CHEM_Tools/FINN

	unzip TrashEmis.zip
	mv $WRFCHEM_FOLDER/WRF_CHEM_Tools/Downloads/ALL_Emiss_04282014.nc $WRFCHEM_FOLDER/WRF_CHEM_Tools/FINN/grid_finn_fire_emis_v2020/src

	cd $WRFCHEM_FOLDER/WRF_CHEM_Tools/FINN

	gunzip FINNv2.4_MOD_MOZART_2020_c20210617.txt.gz
	gunzip FINNv2.4_MOD_MOZART_2013_c20210617.txt.gz
	gunzip FINNv2.4_MODVRS_MOZART_2019_c20210615.txt.gz
	############################Installation of Mozbc #############################
	# Recalling variables from install script to make sure the path is right

	cd $WRFCHEM_FOLDER/WRF_CHEM_Tools/mozbc
	chmod +x make_mozbc
	export DIR=$WRFCHEM_FOLDER/WRF_CHEM_Tools/Libs
	export FC=gfortran
	export NETCDF_DIR=$DIR/NETCDF
	sed -i 's/"${ar_libs} -lnetcdff"/"-lnetcdff ${ar_libs}"/' make_mozbc
	sed -i '8s/FFLAGS = --g/FFLAGS = --g ${fallow_argument}/' Makefile
	sed -i '10s/FFLAGS = -g/FFLAGS = -g ${fallow_argument}/' Makefile
	./make_mozbc 2>&1 | tee make.log

	################## Information on Upper Boundary Conditions ###################

	cd $WRFCHEM_FOLDER/WRF_CHEM_Tools/UBC/
	wget -c https://www2.acom.ucar.edu/sites/default/files/documents/8A_2_Barth_WRFWorkshop_11.pdf

	########################## MEGAN Bio Emission #################################
	# Data for MEGAN Bio Emission located in
	# $WRFCHEM_FOLDER/WRF_CHEM_Tools/megan_bio_data

	cd $WRFCHEM_FOLDER/WRF_CHEM_Tools/megan_bio_emiss
	chmod +x make_util
	export DIR=$WRFCHEM_FOLDER/WRF_CHEM_Tools/Libs
	export FC=gfortran
	export NETCDF_DIR=$DIR/NETCDF
	sed -i 's/"${ar_libs} -lnetcdff"/"-lnetcdff ${ar_libs}"/' make_util
	sed -i '8s/FFLAGS = --g/FFLAGS = --g ${fallow_argument}/' Makefile
	sed -i '10s/FFLAGS = -g/FFLAGS = -g ${fallow_argument}/' Makefile
	./make_util megan_bio_emiss 2>&1 | tee make.bio.log
	./make_util megan_xform 2>&1 | tee make.xform.log
	./make_util surfdata_xform 2>&1 | tee make.surfdata.log

	############################# Anthroprogenic Emissions #########################

	cd $WRFCHEM_FOLDER/WRF_CHEM_Tools/ANTHRO_EMIS/ANTHRO/src
	chmod +x make_anthro
	export DIR=$WRFCHEM_FOLDER/WRF_CHEM_Tools/Libs
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
	cd $WRFCHEM_FOLDER/WRF_CHEM_Tools/EPA_ANTHRO_EMIS/src
	chmod +x make_anthro
	export DIR=$WRFCHEM_FOLDER/WRF_CHEM_Tools/Libs
	export FC=gfortran
	export NETCDF_DIR=$DIR/NETCDF
	sed -i 's/"${ar_libs} -lnetcdff"/"-lnetcdff ${ar_libs}"/' make_anthro
	sed -i '8s/FFLAGS = --g/FFLAGS = --g ${fallow_argument}/' Makefile
	sed -i '10s/FFLAGS = -g/FFLAGS = -g ${fallow_argument}/' Makefile
	./make_anthro 2>&1 | tee make.log

	######################### Weseley EXO Coldens ##################################
	cd $WRFCHEM_FOLDER/WRF_CHEM_Tools/wes_coldens
	chmod +x make_util
	export DIR=$WRFCHEM_FOLDER/WRF_CHEM_Tools/Libs
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
	mkdir $WRFCHEM_FOLDER/WRF_CHEM_Tools/PREP-CHEM-SRC-1.5

	cd $WRFCHEM_FOLDER/WRF_CHEM_Tools/Downloads

	wget -4 -c http://ftp.cptec.inpe.br/pesquisa/bramsrd/BRAMS_5.4/PREP-CHEM/PREP-CHEM-SRC-1.5.tar.gz

	tar -xzvf PREP-CHEM-SRC-1.5.tar.gz -C $WRFCHEM_FOLDER/WRF_CHEM_Tools/PREP-CHEM-SRC-1.5

	cd $WRFCHEM_FOLDER/WRF_CHEM_Tools/PREP-CHEM-SRC-1.5

	# Installation of PREP-CHEM-SRC-1.5

	cd $WRFCHEM_FOLDER/WRF_CHEM_Tools/PREP-CHEM-SRC-1.5/bin/build

	sed -i '47s|/scratchin/grupos/catt-brams/shared/libs/gfortran/netcdf-4.1.3|${DIR}/NETCDF|' include.mk.gfortran.wrf        #Changing NETDCF Location
	sed -i '53s|/scratchin/grupos/catt-brams/shared/libs/gfortran/hdf5-1.8.13-serial|${DIR}/grib2|' include.mk.gfortran.wrf     #Changing HDF5 Location
	sed -i '55s|-L/scratchin/grupos/catt-brams/shared/libs/gfortran/zlib-1.2.8/lib|-L${DIR}/grib2/lib|' include.mk.gfortran.wrf #Changing zlib Location
	sed -i '69s|-frecord-marker=4|-frecord-marker=4 ${fallow_argument}|' include.mk.gfortran.wrf                                #Changing adding fallow argument mismatch to fix dummy error

	make OPT=gfortran.wrf CHEM=RADM_WRF_FIM AER=SIMPLE 2>&1 | tee make.log # Compiling and making of PRE-CHEM-SRC-1.5

	# IF statement to check that all files were created.
	cd $WRFCHEM_FOLDER/WRF_CHEM_Tools/PREP-CHEM-SRC-1.5/bin
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

if [ "$Centos_64bit_GNU" = "2" ]; then

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
	echo $PASSWD | sudo echo $PASSWD | sudo -S pip3 install python-dateutil
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
	export WRFCHEM_FOLDER=$HOME/WRFCHEM
	cd $HOME/WRFCHEM
	mkdir Downloads
	mkdir Libs
	mkdir Libs/grib2
	mkdir Libs/NETCDF
	mkdir $WRFCHEM_FOLDER/WRF_CHEM_Tools
	mkdir $WRFCHEM_FOLDER/WRF_CHEM_Tools/Libs
	mkdir $WRFCHEM_FOLDER/WRF_CHEM_Tools/Libs/grib2
	mkdir $WRFCHEM_FOLDER/WRF_CHEM_Tools/Libs/NETCDF
	mkdir $WRFCHEM_FOLDER/WRF_CHEM_Tools/Downloads
	mkdir $WRFCHEM_FOLDER/WRF_CHEM_Tools/mozbc
	mkdir $WRFCHEM_FOLDER/WRF_CHEM_Tools/megan_bio_emiss
	mkdir $WRFCHEM_FOLDER/WRF_CHEM_Tools/megan_bio_data
	mkdir $WRFCHEM_FOLDER/WRF_CHEM_Tools/wes_coldens
	mkdir $WRFCHEM_FOLDER/WRF_CHEM_Tools/ANTHRO_EMIS
	mkdir $WRFCHEM_FOLDER/WRF_CHEM_Tools/EDGAR_HTAP
	mkdir $WRFCHEM_FOLDER/WRF_CHEM_Tools/EPA_ANTHRO_EMIS
	mkdir $WRFCHEM_FOLDER/WRF_CHEM_Tools/UBC
	mkdir $WRFCHEM_FOLDER/WRF_CHEM_Tools/Aircraft
	mkdir $WRFCHEM_FOLDER/WRF_CHEM_Tools/FINN

	##############################Downloading Libraries############################
	cd $WRFCHEM_FOLDER/WRF_CHEM_Tools/Downloads

	wget -c https://github.com/madler/zlib/archive/refs/tags/v$Zlib_Version.tar.gz
	wget -c https://github.com/HDFGroup/hdf5/archive/refs/tags/hdf5-$HDF5_Version.tar.gz
	wget -c https://github.com/Unidata/netcdf-c/archive/refs/tags/v$Netcdf_C_Version.tar.gz
	wget -c https://github.com/Unidata/netcdf-fortran/archive/refs/tags/v$Netcdf_Fortran_Version.tar.gz
	wget -c https://download.sourceforge.net/libpng/libpng-$Libpng_Version.tar.gz
	wget -c https://www.ece.uvic.ca/~frodo/jasper/software/jasper-$Jasper_Version.zip
	wget -c https://github.com/pmodels/mpich/releases/download/v$Mpich_Version/mpich-$Mpich_Version.tar.gz
	wget -c https://parallel-netcdf.github.io/Release/pnetcdf-$Pnetcdf_Version.tar.gz

	#############################Core Management####################################
	export CPU_CORE=$(nproc) # number of available thread -rs on system
	export CPU_6CORE="6"
	export CPU_HALF=$(($CPU_CORE / 2))                    #half of availble cores on system
	export CPU_HALF_EVEN=$(($CPU_HALF - ($CPU_HALF % 2))) #Forces CPU cores to even number to avoid partial core export. ie 7 cores would be 3.5 cores.

	if [ $CPU_CORE -le $CPU_6CORE ]; then #If statement for low core systems.  Forces computers to only use 1 core if there are 4 cores or less on the system.
		export CPU_HALF_EVEN="2"
	else
		export CPU_HALF_EVEN=$(($CPU_HALF - ($CPU_HALF % 2)))
	fi

	echo "##########################################"
	echo "Number of thread -rs being used $CPU_HALF_EVEN"
	echo "##########################################"
	echo " "

	#############################Compilers############################
	export DIR=$WRFCHEM_FOLDER/WRF_CHEM_Tools/Libs
	export CC=gcc
	export CXX=g++
	export FC=gfortran
	export F77=gfortran
	export CFLAGS="-fPIC -fPIE"

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

	export FFLAGS="$fallow_argument -m64"
	export FCFLAGS="$fallow_argument -m64"

	echo "##########################################"
	echo "FFLAGS = $FFLAGS"
	echo "FCFLAGS = $FCFLAGS"
	echo "##########################################"

	#############################zlib############################
	#Uncalling compilers due to comfigure issue with zlib$Zlib_Version
	#With CC & CXX definied ./configure uses different compiler Flags

	cd $WRFCHEM_FOLDER/WRF_CHEM_Tools/Downloads
	tar -xvzf v$Zlib_Version.tar.gz
	cd zlib-$Zlib_Version/
	autoreconf -i -f 2>&1 | tee autoreconf.log
	./configure --prefix=$DIR/grib2 2>&1 | tee configure.log
	automake -a -f 2>&1 | tee automake.log
	make -j $CPU_HALF_EVEN 2>&1 | tee make.log
	make -j $CPU_HALF_EVEN install 2>&1 | tee make.make.log
	#make check

	##############################MPICH############################
	cd $WRFCHEM_FOLDER/WRF_CHEM_Tools/Downloads
	tar -xvzf mpich-$Mpich_Version.tar.gz
	cd mpich-$Mpich_Version/
	autoreconf -i -f 2>&1 | tee autoreconf.log
	F90= ./configure --prefix=$DIR/MPICH --with-device=ch3 FFLAGS="$fallow_argument -m64" FCFLAGS="$fallow_argument -m64" 2>&1 | tee configure.log
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
	cd $WRFCHEM_FOLDER/WRF_CHEM_Tools/Downloads
	export LDFLAGS=-L$DIR/grib2/lib
	export CPPFLAGS=-I$DIR/grib2/include
	tar -xvzf libpng-$Libpng_Version.tar.gz
	cd libpng-$Libpng_Version/
	autoreconf -i -f 2>&1 | tee autoreconf.log
	CC=$MPICC FC=$MPIFC F77=$MPIF77 F90=$MPIF90 CXX=$MPICXX ./configure --prefix=$DIR/grib2 2>&1 | tee configure.log
	automake -a -f 2>&1 | tee automake.log
	make -j $CPU_HALF_EVEN 2>&1 | tee make.log
	make -j $CPU_HALF_EVEN install 2>&1 | tee make.make.log
	#make check

	#############################JasPer############################
	cd $WRFCHEM_FOLDER/WRF_CHEM_Tools/Downloads
	unzip jasper-$Jasper_Version.zip
	cd jasper-$Jasper_Version/
	autoreconf -i -f 2>&1 | tee autoreconf.log
	CC=$MPICC FC=$MPIFC F77=$MPIF77 F90=$MPIF90 CXX=$MPICXX ./configure --prefix=$DIR/grib2 2>&1 | tee configure.log
	automake -a -f 2>&1 | tee automake.log
	make -j $CPU_HALF_EVEN 2>&1 | tee make.log
	make -j $CPU_HALF_EVEN install 2>&1 | tee make.make.log

	export JASPERLIB=$DIR/grib2/lib
	export JASPERINC=$DIR/grib2/include

	#############################hdf5 library for netcdf4 functionality############################
	cd $WRFCHEM_FOLDER/WRF_CHEM_Tools/Downloads
	tar -xvzf hdf5-$HDF5_Version.tar.gz
	cd hdf5-hdf5-$HDF5_Version
	autoreconf -i -f 2>&1 | tee autoreconf.log
	CC=$MPICC FC=$MPIFC F77=$MPIF77 F90=$MPIF90 CXX=$MPICXX ./configure --prefix=$DIR/grib2 --with-zlib=$DIR/grib2 --enable-hl --enable-fortran --enable-parallel 2>&1 | tee configure.log
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
	cd $WRFCHEM_FOLDER/WRF_CHEM_Tools/Downloads
	tar -xvzf pnetcdf-$Pnetcdf_Version.tar.gz
	cd pnetcdf-$Pnetcdf_Version
	autoreconf -i -f 2>&1 | tee autoreconf.log
	CC=$MPICC FC=$MPIFC F77=$MPIF77 F90=$MPIF90 CXX=$MPICXX ./configure --prefix=$DIR/grib2 --enable-shared --enable-static 2>&1 | tee configure.log
	automake -a -f 2>&1 | tee automake.log
	make -j $CPU_HALF_EVEN 2>&1 | tee make.log
	make -j $CPU_HALF_EVEN install 2>&1 | tee make.make.log
	#make check

	export PNETCDF=$DIR/grib2

	##############################Install NETCDF C Library############################
	cd $WRFCHEM_FOLDER/WRF_CHEM_Tools/Downloads
	tar -xzvf v$Netcdf_C_Version.tar.gz
	cd netcdf-c-$Netcdf_C_Version/
	export CPPFLAGS=-I$DIR/grib2/include
	export LDFLAGS=-L$DIR/grib2/lib
	export LIBS="-lhdf5_hl -lhdf5 -lz -lcurl -lgfortran -lgcc -lm -ldl -lpnetcdf"
	autoreconf -i -f 2>&1 | tee autoreconf.log
	CC=$MPICC FC=$MPIFC F77=$MPIF77 F90=$MPIF90 CXX=$MPICXX ./configure --prefix=$DIR/NETCDF --with-zlib=$DIR/grib2 --disable-dap --enable-netcdf-4 --enable-netcdf4 --enable-shared --enable-static--enable-pnetcdf --enable-cdf5 --enable-parallel-tests 2>&1 | tee configure.log
	automake -a -f 2>&1 | tee automake.log
	make -j $CPU_HALF_EVEN 2>&1 | tee make.log
	make -j $CPU_HALF_EVEN install 2>&1 | tee make.make.log
	#make check

	export PATH=$DIR/NETCDF/bin:$PATH
	export NETCDF=$DIR/NETCDF

	##############################NetCDF fortran library############################
	cd $WRFCHEM_FOLDER/WRF_CHEM_Tools/Downloads
	tar -xvzf v$Netcdf_Fortran_Version.tar.gz
	cd netcdf-fortran-$Netcdf_Fortran_Version/
	export LD_LIBRARY_PATH=$DIR/NETCDF/lib:$LD_LIBRARY_PATH
	export CPPFLAGS="-I$DIR/NETCDF/include -I$DIR/grib2/include"
	export LDFLAGS="-L$DIR/NETCDF/lib -L$DIR/grib2/lib"
	export LIBS="-lnetcdf -lpnetcdf -lcurl -lhdf5_hl -lhdf5 -lz -ldl -lgcc -lgfortran"
	autoreconf -i -f 2>&1 | tee autoreconf.log
	CC=$MPICC FC=$MPIFC CXX=$MPICXX F90=$MPIF90 F77=$MPIF77 ./configure --prefix=$DIR/NETCDF --enable-netcdf-4 --enable-netcdf4 --enable-shared --enable-static--enable-parallel-tests --enable-hdf5 2>&1 | tee configure.log
	automake -a -f 2>&1 | tee automake.log
	make -j $CPU_HALF_EVEN 2>&1 | tee make.log
	make -j $CPU_HALF_EVEN install 2>&1 | tee make.make.log
	#make check

	echo " "

	# Downloading WRF-CHEM Tools and untarring files
	cd $WRFCHEM_FOLDER/WRF_CHEM_Tools/Downloads

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
	tar -xvf mozbc.tar -C $WRFCHEM_FOLDER/WRF_CHEM_Tools/mozbc
	echo ""
	echo "Unpacking MEGAN Bio Emission."
	tar -xvf megan_bio_emiss.tar -C $WRFCHEM_FOLDER/WRF_CHEM_Tools/megan_bio_emiss
	echo ""
	echo "Unpacking MEGAN Bio Emission Data."
	tar -xzvf megan.data.tar.gz -C $WRFCHEM_FOLDER/WRF_CHEM_Tools/megan_bio_data
	echo ""
	echo "Unpacking Wes Coldens"
	tar -xvf wes-coldens.tar -C $WRFCHEM_FOLDER/WRF_CHEM_Tools/wes_coldens
	echo ""
	echo "Unpacking Unpacking ANTHRO Emission."
	tar -xvf ANTHRO.tar -C $WRFCHEM_FOLDER/WRF_CHEM_Tools/ANTHRO_EMIS
	echo ""
	echo "Unpacking EDGAR-HTAP."
	tar -xzvf EDGAR-HTAP.tgz -C $WRFCHEM_FOLDER/WRF_CHEM_Tools/EDGAR_HTAP
	echo ""
	echo "Unpacking EPA ANTHRO Emission."
	tar -xzvf EPA_ANTHRO_EMIS.tgz -C $WRFCHEM_FOLDER/WRF_CHEM_Tools/EPA_ANTHRO_EMIS
	echo ""
	echo "Unpacking Upper Boundary Conditions."
	tar -xvf UBC_inputs.tar -C $WRFCHEM_FOLDER/WRF_CHEM_Tools/UBC
	echo ""
	echo "Unpacking Aircraft Preprocessor Files."
	echo ""
	tar -xvf aircraft_preprocessor_files.tar -C $WRFCHEM_FOLDER/WRF_CHEM_Tools/Aircraft
	echo ""
	echo "Unpacking Fire INventory from NCAR (FINN)"
	tar -xzvf fire_emis.tgz -C $WRFCHEM_FOLDER/WRF_CHEM_Tools/FINN
	tar -xvf fire_emis_input.tar
	tar -zxvf grass_from_img.nc.tgz -C $WRFCHEM_FOLDER/WRF_CHEM_Tools/FINN/grid_finn_fire_emis_v2020/src
	tar -zxvf tempfor_from_img.nc.tgz -C $WRFCHEM_FOLDER/WRF_CHEM_Tools/FINN/grid_finn_fire_emis_v2020/src
	tar -zxvf shrub_from_img.nc.tgz -C $WRFCHEM_FOLDER/WRF_CHEM_Tools/FINN/grid_finn_fire_emis_v2020/src
	tar -zxvf tropfor_from_img.nc.tgz -C $WRFCHEM_FOLDER/WRF_CHEM_Tools/FINN/grid_finn_fire_emis_v2020/src

	mv $WRFCHEM_FOLDER/WRF_CHEM_Tools/Downloads/FINNv2.4_MOD_MOZART_2020_c20210617.txt.gz $WRFCHEM_FOLDER/WRF_CHEM_Tools/FINN
	mv $WRFCHEM_FOLDER/WRF_CHEM_Tools/Downloads/FINNv2.4_MOD_MOZART_2013_c20210617.txt.gz $WRFCHEM_FOLDER/WRF_CHEM_Tools/FINN
	mv $WRFCHEM_FOLDER/WRF_CHEM_Tools/Downloads/FINNv2.4_MODVRS_MOZART_2019_c20210615.txt.gz $WRFCHEM_FOLDER/WRF_CHEM_Tools/FINN

	unzip TrashEmis.zip
	mv $WRFCHEM_FOLDER/WRF_CHEM_Tools/Downloads/ALL_Emiss_04282014.nc $WRFCHEM_FOLDER/WRF_CHEM_Tools/FINN/grid_finn_fire_emis_v2020/src

	cd $WRFCHEM_FOLDER/WRF_CHEM_Tools/FINN

	gunzip FINNv2.4_MOD_MOZART_2020_c20210617.txt.gz
	gunzip FINNv2.4_MOD_MOZART_2013_c20210617.txt.gz
	gunzip FINNv2.4_MODVRS_MOZART_2019_c20210615.txt.gz
	############################Installation of Mozbc #############################
	# Recalling variables from install script to make sure the path is right

	cd $WRFCHEM_FOLDER/WRF_CHEM_Tools/mozbc
	chmod +x make_mozbc
	export DIR=$WRFCHEM_FOLDER/WRF_CHEM_Tools/Libs
	export FC=gfortran
	export NETCDF_DIR=$DIR/NETCDF
	sed -i 's/"${ar_libs} -lnetcdff"/"-lnetcdff ${ar_libs}"/' make_mozbc
	sed -i '8s/FFLAGS = --g/FFLAGS = --g ${fallow_argument}/' Makefile
	sed -i '10s/FFLAGS = -g/FFLAGS = -g ${fallow_argument}/' Makefile
	./make_mozbc 2>&1 | tee make.log

	################## Information on Upper Boundary Conditions ###################

	cd $WRFCHEM_FOLDER/WRF_CHEM_Tools/UBC/
	wget -c https://www2.acom.ucar.edu/sites/default/files/documents/8A_2_Barth_WRFWorkshop_11.pdf

	########################## MEGAN Bio Emission #################################
	# Data for MEGAN Bio Emission located in
	# $WRFCHEM_FOLDER/WRF_CHEM_Tools/megan_bio_data

	cd $WRFCHEM_FOLDER/WRF_CHEM_Tools/megan_bio_emiss
	chmod +x make_util
	export DIR=$WRFCHEM_FOLDER/WRF_CHEM_Tools/Libs
	export FC=gfortran
	export NETCDF_DIR=$DIR/NETCDF
	sed -i 's/"${ar_libs} -lnetcdff"/"-lnetcdff ${ar_libs}"/' make_util
	sed -i '8s/FFLAGS = --g/FFLAGS = --g ${fallow_argument}/' Makefile
	sed -i '10s/FFLAGS = -g/FFLAGS = -g ${fallow_argument}/' Makefile
	./make_util megan_bio_emiss 2>&1 | tee make.bio.log
	./make_util megan_xform 2>&1 | tee make.xform.log
	./make_util surfdata_xform 2>&1 | tee make.surfdata.log

	############################# Anthroprogenic Emissions #########################

	cd $WRFCHEM_FOLDER/WRF_CHEM_Tools/ANTHRO_EMIS/ANTHRO/src
	chmod +x make_anthro
	export DIR=$WRFCHEM_FOLDER/WRF_CHEM_Tools/Libs
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
	cd $WRFCHEM_FOLDER/WRF_CHEM_Tools/EPA_ANTHRO_EMIS/src
	chmod +x make_anthro
	export DIR=$WRFCHEM_FOLDER/WRF_CHEM_Tools/Libs
	export FC=gfortran
	export NETCDF_DIR=$DIR/NETCDF
	sed -i 's/"${ar_libs} -lnetcdff"/"-lnetcdff ${ar_libs}"/' make_anthro
	sed -i '8s/FFLAGS = --g/FFLAGS = --g ${fallow_argument}/' Makefile
	sed -i '10s/FFLAGS = -g/FFLAGS = -g ${fallow_argument}/' Makefile
	./make_anthro 2>&1 | tee make.log

	######################### Weseley EXO Coldens ##################################
	cd $WRFCHEM_FOLDER/WRF_CHEM_Tools/wes_coldens
	chmod +x make_util
	export DIR=$WRFCHEM_FOLDER/WRF_CHEM_Tools/Libs
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
	mkdir $WRFCHEM_FOLDER/WRF_CHEM_Tools/PREP-CHEM-SRC-1.5

	cd $WRFCHEM_FOLDER/WRF_CHEM_Tools/Downloads

	wget -4 -c http://ftp.cptec.inpe.br/pesquisa/bramsrd/BRAMS_5.4/PREP-CHEM/PREP-CHEM-SRC-1.5.tar.gz

	tar -xzvf PREP-CHEM-SRC-1.5.tar.gz -C $WRFCHEM_FOLDER/WRF_CHEM_Tools/PREP-CHEM-SRC-1.5

	cd $WRFCHEM_FOLDER/WRF_CHEM_Tools/PREP-CHEM-SRC-1.5

	# Installation of PREP-CHEM-SRC-1.5

	cd $WRFCHEM_FOLDER/WRF_CHEM_Tools/PREP-CHEM-SRC-1.5/bin/build

	sed -i '47s|/scratchin/grupos/catt-brams/shared/libs/gfortran/netcdf-4.1.3|${DIR}/NETCDF|' include.mk.gfortran.wrf        #Changing NETDCF Location
	sed -i '53s|/scratchin/grupos/catt-brams/shared/libs/gfortran/hdf5-1.8.13-serial|${DIR}/grib2|' include.mk.gfortran.wrf     #Changing HDF5 Location
	sed -i '55s|-L/scratchin/grupos/catt-brams/shared/libs/gfortran/zlib-1.2.8/lib|-L${DIR}/grib2/lib|' include.mk.gfortran.wrf #Changing zlib Location
	sed -i '69s|-frecord-marker=4|-frecord-marker=4 ${fallow_argument}|' include.mk.gfortran.wrf                                #Changing adding fallow argument mismatch to fix dummy error

	make OPT=gfortran.wrf CHEM=RADM_WRF_FIM AER=SIMPLE 2>&1 | tee make.log # Compiling and making of PRE-CHEM-SRC-1.5

	# IF statement to check that all files were created.
	cd $WRFCHEM_FOLDER/WRF_CHEM_Tools/PREP-CHEM-SRC-1.5/bin
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
	echo $PASSWD | sudo -S apt -y install autoconf automake bison build-essential byacc cmake csh curl default-jdk default-jre emacs flex g++ gawk gcc gfortran git ksh libcurl4-openssl-dev libjpeg-dev libncurses5 libncurses6 libpixman-1-dev libpng-dev libtool libxml2 libxml2-dev m4 make mlocate ncview okular openbox pipenv pkg-config python2 python2-dev python3 python3-dev python3-pip tsch unzip xauth xorg time

	#Directory Listings
	export HOME=$(
		cd
		pwd
	)
	mkdir $HOME/WRFCHEM
	export WRFCHEM_FOLDER=$HOME/WRFCHEM
	cd $HOME/WRFCHEM
	mkdir Downloads
	mkdir Libs
	mkdir Libs/grib2
	mkdir Libs/NETCDF
	mkdir $WRFCHEM_FOLDER/WRF_CHEM_Tools
	mkdir $WRFCHEM_FOLDER/WRF_CHEM_Tools/Libs
	mkdir $WRFCHEM_FOLDER/WRF_CHEM_Tools/Libs/grib2
	mkdir $WRFCHEM_FOLDER/WRF_CHEM_Tools/Libs/NETCDF
	mkdir $WRFCHEM_FOLDER/WRF_CHEM_Tools/Downloads
	mkdir $WRFCHEM_FOLDER/WRF_CHEM_Tools/mozbc
	mkdir $WRFCHEM_FOLDER/WRF_CHEM_Tools/megan_bio_emiss
	mkdir $WRFCHEM_FOLDER/WRF_CHEM_Tools/megan_bio_data
	mkdir $WRFCHEM_FOLDER/WRF_CHEM_Tools/wes_coldens
	mkdir $WRFCHEM_FOLDER/WRF_CHEM_Tools/ANTHRO_EMIS
	mkdir $WRFCHEM_FOLDER/WRF_CHEM_Tools/EDGAR_HTAP
	mkdir $WRFCHEM_FOLDER/WRF_CHEM_Tools/EPA_ANTHRO_EMIS
	mkdir $WRFCHEM_FOLDER/WRF_CHEM_Tools/UBC
	mkdir $WRFCHEM_FOLDER/WRF_CHEM_Tools/Aircraft
	mkdir $WRFCHEM_FOLDER/WRF_CHEM_Tools/FINN

	##############################Downloading Libraries############################
	cd $WRFCHEM_FOLDER/WRF_CHEM_Tools/Downloads

	wget -c https://github.com/madler/zlib/archive/refs/tags/v$Zlib_Version.tar.gz
	wget -c https://github.com/HDFGroup/hdf5/archive/refs/tags/hdf5-$HDF5_Version.tar.gz
	wget -c https://github.com/Unidata/netcdf-c/archive/refs/tags/v$Netcdf_C_Version.tar.gz
	wget -c https://github.com/Unidata/netcdf-fortran/archive/refs/tags/v$Netcdf_Fortran_Version.tar.gz
	wget -c https://download.sourceforge.net/libpng/libpng-$Libpng_Version.tar.gz
	wget -c https://www.ece.uvic.ca/~frodo/jasper/software/jasper-$Jasper_Version.zip
	wget -c https://github.com/pmodels/mpich/releases/download/v$Mpich_Version/mpich-$Mpich_Version.tar.gz
	wget -c https://parallel-netcdf.github.io/Release/pnetcdf-$Pnetcdf_Version.tar.gz

	#############################Core Management####################################
	export CPU_CORE=$(nproc) # number of available thread -rs on system
	export CPU_6CORE="6"
	export CPU_HALF=$(($CPU_CORE / 2))                    #half of availble cores on system
	export CPU_HALF_EVEN=$(($CPU_HALF - ($CPU_HALF % 2))) #Forces CPU cores to even number to avoid partial core export. ie 7 cores would be 3.5 cores.

	if [ $CPU_CORE -le $CPU_6CORE ]; then #If statement for low core systems.  Forces computers to only use 1 core if there are 4 cores or less on the system.
		export CPU_HALF_EVEN="2"
	else
		export CPU_HALF_EVEN=$(($CPU_HALF - ($CPU_HALF % 2)))
	fi

	echo "##########################################"
	echo "Number of thread -rs being used $CPU_HALF_EVEN"
	echo "##########################################"
	echo " "

	#############################Compilers############################
	export DIR=$WRFCHEM_FOLDER/WRF_CHEM_Tools/Libs
	export CC=gcc
	export CXX=g++
	export FC=gfortran
	export F77=gfortran
	export CFLAGS="-fPIC -fPIE"

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

	export FFLAGS="$fallow_argument -m64"
	export FCFLAGS="$fallow_argument -m64"

	echo "##########################################"
	echo "FFLAGS = $FFLAGS"
	echo "FCFLAGS = $FCFLAGS"
	echo "##########################################"

	#############################zlib############################
	#Uncalling compilers due to comfigure issue with zlib$Zlib_Version
	#With CC & CXX definied ./configure uses different compiler Flags

	cd $WRFCHEM_FOLDER/WRF_CHEM_Tools/Downloads
	tar -xvzf v$Zlib_Version.tar.gz
	cd zlib-$Zlib_Version/
	autoreconf -i -f 2>&1 | tee autoreconf.log
	./configure --prefix=$DIR/grib2 2>&1 | tee configure.log
	automake -a -f 2>&1 | tee automake.log
	make -j $CPU_HALF_EVEN 2>&1 | tee make.log
	make -j $CPU_HALF_EVEN install 2>&1 | tee make.install.log
	#make check

	##############################MPICH############################
	cd $WRFCHEM_FOLDER/WRF_CHEM_Tools/Downloads
	tar -xvzf mpich-$Mpich_Version.tar.gz
	cd mpich-$Mpich_Version/
	autoreconf -i -f 2>&1 | tee autoreconf.log
	F90= ./configure --prefix=$DIR/MPICH --with-device=ch3 FFLAGS="$fallow_argument -m64" FCFLAGS="$fallow_argument -m64" 2>&1 | tee configure.log
	automake -a -f 2>&1 | tee automake.log
	make -j $CPU_HALF_EVEN 2>&1 | tee make.log
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
	cd $WRFCHEM_FOLDER/WRF_CHEM_Tools/Downloads
	export LDFLAGS=-L$DIR/grib2/lib
	export CPPFLAGS=-I$DIR/grib2/include
	tar -xvzf libpng-$Libpng_Version.tar.gz
	cd libpng-$Libpng_Version/
	autoreconf -i -f 2>&1 | tee autoreconf.log
	CC=$MPICC FC=$MPIFC F77=$MPIF77 F90=$MPIF90 CXX=$MPICXX ./configure --prefix=$DIR/grib2 2>&1 | tee configure.log
	automake -a -f 2>&1 | tee automake.log
	make -j $CPU_HALF_EVEN 2>&1 | tee make.log
	make -j $CPU_HALF_EVEN install 2>&1 | tee make.install.log
	#make check

	#############################JasPer############################
	cd $WRFCHEM_FOLDER/WRF_CHEM_Tools/Downloads
	unzip jasper-$Jasper_Version.zip
	cd jasper-$Jasper_Version/
	autoreconf -i -f 2>&1 | tee autoreconf.log
	CC=$MPICC FC=$MPIFC F77=$MPIF77 F90=$MPIF90 CXX=$MPICXX ./configure --prefix=$DIR/grib2 2>&1 | tee configure.log
	automake -a -f 2>&1 | tee automake.log
	make -j $CPU_HALF_EVEN 2>&1 | tee make.log
	make -j $CPU_HALF_EVEN install 2>&1 | tee make.install.log

	export JASPERLIB=$DIR/grib2/lib
	export JASPERINC=$DIR/grib2/include

	#############################hdf5 library for netcdf4 functionality############################
	cd $WRFCHEM_FOLDER/WRF_CHEM_Tools/Downloads
	tar -xvzf hdf5-$HDF5_Version.tar.gz
	cd hdf5-hdf5-$HDF5_Version
	autoreconf -i -f 2>&1 | tee autoreconf.log
	CC=$MPICC FC=$MPIFC F77=$MPIF77 F90=$MPIF90 CXX=$MPICXX ./configure --prefix=$DIR/grib2 --with-zlib=$DIR/grib2 --enable-hl --enable-fortran --enable-parallel 2>&1 | tee configure.log
	automake -a -f 2>&1 | tee automake.log
	make -j $CPU_HALF_EVEN 2>&1 | tee make.log
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
	cd $WRFCHEM_FOLDER/WRF_CHEM_Tools/Downloads
	tar -xvzf pnetcdf-$Pnetcdf_Version.tar.gz
	cd pnetcdf-$Pnetcdf_Version
	autoreconf -i -f 2>&1 | tee autoreconf.log
	CC=$MPICC FC=$MPIFC F77=$MPIF77 F90=$MPIF90 CXX=$MPICXX ./configure --prefix=$DIR/grib2 --enable-shared --enable-static 2>&1 | tee configure.log
	automake -a -f 2>&1 | tee automake.log
	make -j $CPU_HALF_EVEN 2>&1 | tee make.log
	make -j $CPU_HALF_EVEN install 2>&1 | tee make.install.log
	#make check

	export PNETCDF=$DIR/grib2

	##############################Install NETCDF C Library############################
	cd $WRFCHEM_FOLDER/WRF_CHEM_Tools/Downloads
	tar -xzvf v$Netcdf_C_Version.tar.gz
	cd netcdf-c-$Netcdf_C_Version/
	export CPPFLAGS=-I$DIR/grib2/include
	export LDFLAGS=-L$DIR/grib2/lib
	export LIBS="-lhdf5_hl -lhdf5 -lz -lcurl -lgfortran -lgcc -lm -ldl -lpnetcdf"
	autoreconf -i -f 2>&1 | tee autoreconf.log
	CC=$MPICC FC=$MPIFC F77=$MPIF77 F90=$MPIF90 CXX=$MPICXX ./configure --prefix=$DIR/NETCDF --with-zlib=$DIR/grib2 --disable-dap --enable-netcdf-4 --enable-netcdf4 --enable-shared --enable-static--enable-pnetcdf --enable-cdf5 --enable-parallel-tests 2>&1 | tee configure.log
	automake -a -f 2>&1 | tee automake.log
	make -j $CPU_HALF_EVEN 2>&1 | tee make.log
	make -j $CPU_HALF_EVEN install 2>&1 | tee make.install.log
	#make check

	export PATH=$DIR/NETCDF/bin:$PATH
	export NETCDF=$DIR/NETCDF

	##############################NetCDF fortran library############################
	cd $WRFCHEM_FOLDER/WRF_CHEM_Tools/Downloads
	tar -xvzf v$Netcdf_Fortran_Version.tar.gz
	cd netcdf-fortran-$Netcdf_Fortran_Version/
	export LD_LIBRARY_PATH=$DIR/NETCDF/lib:$LD_LIBRARY_PATH
	export CPPFLAGS="-I$DIR/NETCDF/include -I$DIR/grib2/include"
	export LDFLAGS="-L$DIR/NETCDF/lib -L$DIR/grib2/lib"
	export LIBS="-lnetcdf -lpnetcdf -lcurl -lhdf5_hl -lhdf5 -lz -ldl -lgcc -lgfortran"
	autoreconf -i -f 2>&1 | tee autoreconf.log
	CC=$MPICC FC=$MPIFC CXX=$MPICXX F90=$MPIF90 F77=$MPIF77 ./configure --prefix=$DIR/NETCDF --enable-netcdf-4 --enable-netcdf4 --enable-shared --enable-static--enable-parallel-tests --enable-hdf5 2>&1 | tee configure.log
	automake -a -f 2>&1 | tee automake.log
	make -j $CPU_HALF_EVEN 2>&1 | tee make.log
	make -j $CPU_HALF_EVEN install 2>&1 | tee make.install.log
	#make check

	echo " "

	# Downloading WRF-CHEM Tools and untarring files
	cd $WRFCHEM_FOLDER/WRF_CHEM_Tools/Downloads

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
	tar -xvf mozbc.tar -C $WRFCHEM_FOLDER/WRF_CHEM_Tools/mozbc
	echo ""
	echo "Unpacking MEGAN Bio Emission."
	tar -xvf megan_bio_emiss.tar -C $WRFCHEM_FOLDER/WRF_CHEM_Tools/megan_bio_emiss
	echo ""
	echo "Unpacking MEGAN Bio Emission Data."
	tar -xzvf megan.data.tar.gz -C $WRFCHEM_FOLDER/WRF_CHEM_Tools/megan_bio_data
	echo ""
	echo "Unpacking Wes Coldens"
	tar -xvf wes-coldens.tar -C $WRFCHEM_FOLDER/WRF_CHEM_Tools/wes_coldens
	echo ""
	echo "Unpacking Unpacking ANTHRO Emission."
	tar -xvf ANTHRO.tar -C $WRFCHEM_FOLDER/WRF_CHEM_Tools/ANTHRO_EMIS
	echo ""
	echo "Unpacking EDGAR-HTAP."
	tar -xzvf EDGAR-HTAP.tgz -C $WRFCHEM_FOLDER/WRF_CHEM_Tools/EDGAR_HTAP
	echo ""
	echo "Unpacking EPA ANTHRO Emission."
	tar -xzvf EPA_ANTHRO_EMIS.tgz -C $WRFCHEM_FOLDER/WRF_CHEM_Tools/EPA_ANTHRO_EMIS
	echo ""
	echo "Unpacking Upper Boundary Conditions."
	tar -xvf UBC_inputs.tar -C $WRFCHEM_FOLDER/WRF_CHEM_Tools/UBC
	echo ""
	echo "Unpacking Aircraft Preprocessor Files."
	echo ""
	tar -xvf aircraft_preprocessor_files.tar -C $WRFCHEM_FOLDER/WRF_CHEM_Tools/Aircraft
	echo ""
	echo "Unpacking Fire INventory from NCAR (FINN)"
	tar -xzvf fire_emis.tgz -C $WRFCHEM_FOLDER/WRF_CHEM_Tools/FINN
	tar -xvf fire_emis_input.tar
	tar -zxvf grass_from_img.nc.tgz -C $WRFCHEM_FOLDER/WRF_CHEM_Tools/FINN/grid_finn_fire_emis_v2020/src
	tar -zxvf tempfor_from_img.nc.tgz -C $WRFCHEM_FOLDER/WRF_CHEM_Tools/FINN/grid_finn_fire_emis_v2020/src
	tar -zxvf shrub_from_img.nc.tgz -C $WRFCHEM_FOLDER/WRF_CHEM_Tools/FINN/grid_finn_fire_emis_v2020/src
	tar -zxvf tropfor_from_img.nc.tgz -C $WRFCHEM_FOLDER/WRF_CHEM_Tools/FINN/grid_finn_fire_emis_v2020/src

	mv $WRFCHEM_FOLDER/WRF_CHEM_Tools/Downloads/FINNv2.4_MOD_MOZART_2020_c20210617.txt.gz $WRFCHEM_FOLDER/WRF_CHEM_Tools/FINN
	mv $WRFCHEM_FOLDER/WRF_CHEM_Tools/Downloads/FINNv2.4_MOD_MOZART_2013_c20210617.txt.gz $WRFCHEM_FOLDER/WRF_CHEM_Tools/FINN
	mv $WRFCHEM_FOLDER/WRF_CHEM_Tools/Downloads/FINNv2.4_MODVRS_MOZART_2019_c20210615.txt.gz $WRFCHEM_FOLDER/WRF_CHEM_Tools/FINN

	unzip TrashEmis.zip
	mv $WRFCHEM_FOLDER/WRF_CHEM_Tools/Downloads/ALL_Emiss_04282014.nc $WRFCHEM_FOLDER/WRF_CHEM_Tools/FINN/grid_finn_fire_emis_v2020/src

	cd $WRFCHEM_FOLDER/WRF_CHEM_Tools/FINN

	gunzip FINNv2.4_MOD_MOZART_2020_c20210617.txt.gz
	gunzip FINNv2.4_MOD_MOZART_2013_c20210617.txt.gz
	gunzip FINNv2.4_MODVRS_MOZART_2019_c20210615.txt.gz
	############################Installation of Mozbc #############################
	# Recalling variables from install script to make sure the path is right

	cd $WRFCHEM_FOLDER/WRF_CHEM_Tools/mozbc
	chmod +x make_mozbc
	export DIR=$WRFCHEM_FOLDER/WRF_CHEM_Tools/Libs
	export FC=gfortran
	export NETCDF_DIR=$DIR/NETCDF
	sed -i 's/"${ar_libs} -lnetcdff"/"-lnetcdff ${ar_libs}"/' make_mozbc
	sed -i '8s/FFLAGS = --g/FFLAGS = --g ${fallow_argument}/' Makefile
	sed -i '10s/FFLAGS = -g/FFLAGS = -g ${fallow_argument}/' Makefile
	./make_mozbc 2>&1 | tee make.log

	################## Information on Upper Boundary Conditions ###################

	cd $WRFCHEM_FOLDER/WRF_CHEM_Tools/UBC/
	wget -c https://www2.acom.ucar.edu/sites/default/files/documents/8A_2_Barth_WRFWorkshop_11.pdf

	########################## MEGAN Bio Emission #################################
	# Data for MEGAN Bio Emission located in
	# $WRFCHEM_FOLDER/WRF_CHEM_Tools/megan_bio_data

	cd $WRFCHEM_FOLDER/WRF_CHEM_Tools/megan_bio_emiss
	chmod +x make_util
	export DIR=$WRFCHEM_FOLDER/WRF_CHEM_Tools/Libs
	export FC=gfortran
	export NETCDF_DIR=$DIR/NETCDF
	sed -i 's/"${ar_libs} -lnetcdff"/"-lnetcdff ${ar_libs}"/' make_util
	sed -i '8s/FFLAGS = --g/FFLAGS = --g ${fallow_argument}/' Makefile
	sed -i '10s/FFLAGS = -g/FFLAGS = -g ${fallow_argument}/' Makefile
	./make_util megan_bio_emiss 2>&1 | tee make.bio.log
	./make_util megan_xform 2>&1 | tee make.xform.log
	./make_util surfdata_xform 2>&1 | tee make.surfdata.log

	############################# Anthroprogenic Emissions #########################

	cd $WRFCHEM_FOLDER/WRF_CHEM_Tools/ANTHRO_EMIS/ANTHRO/src
	chmod +x make_anthro
	export DIR=$WRFCHEM_FOLDER/WRF_CHEM_Tools/Libs
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
	cd $WRFCHEM_FOLDER/WRF_CHEM_Tools/EPA_ANTHRO_EMIS/src
	chmod +x make_anthro
	export DIR=$WRFCHEM_FOLDER/WRF_CHEM_Tools/Libs
	export FC=gfortran
	export NETCDF_DIR=$DIR/NETCDF
	sed -i 's/"${ar_libs} -lnetcdff"/"-lnetcdff ${ar_libs}"/' make_anthro
	sed -i '8s/FFLAGS = --g/FFLAGS = --g ${fallow_argument}/' Makefile
	sed -i '10s/FFLAGS = -g/FFLAGS = -g ${fallow_argument}/' Makefile
	./make_anthro 2>&1 | tee make.log

	######################### Weseley EXO Coldens ##################################
	cd $WRFCHEM_FOLDER/WRF_CHEM_Tools/wes_coldens
	chmod +x make_util
	export DIR=$WRFCHEM_FOLDER/WRF_CHEM_Tools/Libs
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
	mkdir $WRFCHEM_FOLDER/WRF_CHEM_Tools/PREP-CHEM-SRC-1.5

	cd $WRFCHEM_FOLDER/WRF_CHEM_Tools/Downloads

	wget -4 -c http://ftp.cptec.inpe.br/pesquisa/bramsrd/BRAMS_5.4/PREP-CHEM/PREP-CHEM-SRC-1.5.tar.gz

	tar -xzvf PREP-CHEM-SRC-1.5.tar.gz -C $WRFCHEM_FOLDER/WRF_CHEM_Tools/PREP-CHEM-SRC-1.5

	cd $WRFCHEM_FOLDER/WRF_CHEM_Tools/PREP-CHEM-SRC-1.5

	# Installation of PREP-CHEM-SRC-1.5

	cd $WRFCHEM_FOLDER/WRF_CHEM_Tools/PREP-CHEM-SRC-1.5/bin/build

	sed -i '47s|/scratchin/grupos/catt-brams/shared/libs/gfortran/netcdf-4.1.3|${DIR}/NETCDF|' include.mk.gfortran.wrf        #Changing NETDCF Location
	sed -i '53s|/scratchin/grupos/catt-brams/shared/libs/gfortran/hdf5-1.8.13-serial|${DIR}/grib2|' include.mk.gfortran.wrf     #Changing HDF5 Location
	sed -i '55s|-L/scratchin/grupos/catt-brams/shared/libs/gfortran/zlib-1.2.8/lib|-L${DIR}/grib2/lib|' include.mk.gfortran.wrf #Changing zlib Location
	sed -i '69s|-frecord-marker=4|-frecord-marker=4 ${fallow_argument}|' include.mk.gfortran.wrf                                #Changing adding fallow argument mismatch to fix dummy error

	make OPT=gfortran.wrf CHEM=RADM_WRF_FIM AER=SIMPLE 2>&1 | tee make.log # Compiling and making of PRE-CHEM-SRC-1.5

	# IF statement to check that all files were created.
	cd $WRFCHEM_FOLDER/WRF_CHEM_Tools/PREP-CHEM-SRC-1.5/bin
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
	echo $PASSWD | sudo -S apt -y install autoconf automake bison build-essential byacc cmake csh curl default-jdk default-jre emacs flex g++ gawk gcc gfortran git ksh libcurl4-openssl-dev libjpeg-dev libncurses5 libncurses6 libpixman-1-dev libpng-dev libtool libxml2 libxml2-dev m4 make mlocate ncview okular openbox pipenv pkg-config python2 python2-dev python3 python3-dev python3-pip tcsh unzip xauth xorg time

	# install the Intel compilers
	echo $PASSWD | sudo -S apt -y install intel-basekit
	echo $PASSWD | sudo -S apt -y install intel-hpckit
	echo $PASSWD | sudo -S apt -y install intel-oneapi-python

	echo $PASSWD | sudo -S apt -y update
	echo $PASSWD | sudo -S apt -y upgrade

	# make sure some critical packages have been installed
	which cmake pkg-config make gcc g++

	# add the Intel compiler file paths to various environment variables
	source /opt/intel/oneapi/setvars.sh

	# some of the libraries we install below need one or more of these variables
	export CC=icc
	export CXX=icpc
	export FC=ifort
	export F77=ifort
	export F90=ifort
	export MPIFC=mpiifort
	export MPIF77=mpiifort
	export MPIF90=mpiifort
	export MPICC=mpiicc
	export MPICXX=mpiicpc
	export CFLAGS="-fPIC -fPIE -diag-disable=10441"

	#Directory Listings
	export HOME=$(
		cd
		pwd
	)
	mkdir $HOME/WRFCHEM_Intel
	export WRFCHEM_FOLDER=$HOME/WRFCHEM_Intel
	cd $HOME/WRFCHEM_Intel
	mkdir Downloads
	mkdir Libs
	mkdir Libs/grib2
	mkdir Libs/NETCDF
	mkdir $WRFCHEM_FOLDER/WRF_CHEM_Tools
	mkdir $WRFCHEM_FOLDER/WRF_CHEM_Tools/Libs
	mkdir $WRFCHEM_FOLDER/WRF_CHEM_Tools/Libs/grib2
	mkdir $WRFCHEM_FOLDER/WRF_CHEM_Tools/Libs/NETCDF
	mkdir $WRFCHEM_FOLDER/WRF_CHEM_Tools/Downloads
	mkdir $WRFCHEM_FOLDER/WRF_CHEM_Tools/mozbc
	mkdir $WRFCHEM_FOLDER/WRF_CHEM_Tools/megan_bio_emiss
	mkdir $WRFCHEM_FOLDER/WRF_CHEM_Tools/megan_bio_data
	mkdir $WRFCHEM_FOLDER/WRF_CHEM_Tools/wes_coldens
	mkdir $WRFCHEM_FOLDER/WRF_CHEM_Tools/ANTHRO_EMIS
	mkdir $WRFCHEM_FOLDER/WRF_CHEM_Tools/EDGAR_HTAP
	mkdir $WRFCHEM_FOLDER/WRF_CHEM_Tools/EPA_ANTHRO_EMIS
	mkdir $WRFCHEM_FOLDER/WRF_CHEM_Tools/UBC
	mkdir $WRFCHEM_FOLDER/WRF_CHEM_Tools/Aircraft
	mkdir $WRFCHEM_FOLDER/WRF_CHEM_Tools/FINN

	export DIR=$WRFCHEM_FOLDER/WRF_CHEM_Tools/Libs

	##############################Downloading Libraries############################
	cd $WRFCHEM_FOLDER/WRF_CHEM_Tools/Downloads

	wget -c https://github.com/madler/zlib/archive/refs/tags/v$Zlib_Version.tar.gz
	wget -c https://github.com/HDFGroup/hdf5/archive/refs/tags/hdf5-$HDF5_Version.tar.gz
	wget -c https://github.com/Unidata/netcdf-c/archive/refs/tags/v$Netcdf_C_Version.tar.gz
	wget -c https://github.com/Unidata/netcdf-fortran/archive/refs/tags/v$Netcdf_Fortran_Version.tar.gz
	wget -c https://download.sourceforge.net/libpng/libpng-$Libpng_Version.tar.gz
	wget -c https://www.ece.uvic.ca/~frodo/jasper/software/jasper-$Jasper_Version.zip
	wget -c https://parallel-netcdf.github.io/Release/pnetcdf-$Pnetcdf_Version.tar.gz

	#############################Core Management####################################
	export CPU_CORE=$(nproc) #number of available thread -rs on system
	export CPU_6CORE="6"
	export CPU_HALF=$(($CPU_CORE / 2))                    #half of availble cores on system
	export CPU_HALF_EVEN=$(($CPU_HALF - ($CPU_HALF % 2))) #Forces CPU cores to even number to avoid partial core export. ie 7 cores would be 3.5 cores.

	if [ $CPU_CORE -le $CPU_6CORE ]; then #If statement for low core systems.  Forces computers to only use 1 core if there are 4 cores or less on the system.
		export CPU_HALF_EVEN="2"
	else
		export CPU_HALF_EVEN=$(($CPU_HALF - ($CPU_HALF % 2)))
	fi

	echo "##########################################"
	echo "Number of thread -rs being used $CPU_HALF_EVEN"
	echo "##########################################"
	echo " "

	#############################Compilers############################

	#############################zlib############################
	#Uncalling compilers due to comfigure issue with zlib$Zlib_Version
	#With CC & CXX definied ./configure uses different compiler Flags

	cd $WRFCHEM_FOLDER/WRF_CHEM_Tools/Downloads
	tar -xvzf v$Zlib_Version.tar.gz
	cd zlib-$Zlib_Version/
	autoreconf -i -f 2>&1 | tee autoreconf.log
	./configure --prefix=$DIR/grib2 2>&1 | tee configure.log
	automake -a -f 2>&1 | tee automake.log
	make -j $CPU_HALF_EVEN 2>&1 | tee make.log
	make -j $CPU_HALF_EVEN install 2>&1 | tee make.install.log
	#make check

	#############################libpng############################
	cd $WRFCHEM_FOLDER/WRF_CHEM_Tools/Downloads
	export LDFLAGS=-L$DIR/grib2/lib
	export CPPFLAGS=-I$DIR/grib2/include
	tar -xvzf libpng-$Libpng_Version.tar.gz
	autoreconf -i -f 2>&1 | tee autoreconf.log
	cd libpng-$Libpng_Version/
	CC=$MPICC FC=$MPIFC F77=$MPIF77 F90=$MPIF90 CXX=$MPICXX ./configure --prefix=$DIR/grib2 2>&1 | tee configure.log
	automake -a -f 2>&1 | tee automake.log
	make -j $CPU_HALF_EVEN 2>&1 | tee make.log
	make -j $CPU_HALF_EVEN install 2>&1 | tee make.install.log
	#make check

	#############################JasPer############################
	cd $WRFCHEM_FOLDER/WRF_CHEM_Tools/Downloads
	unzip jasper-$Jasper_Version.zip
	cd jasper-$Jasper_Version/
	autoreconf -i -f 2>&1 | tee autoreconf.log
	CC=$MPICC FC=$MPIFC F77=$MPIF77 F90=$MPIF90 CXX=$MPICXX ./configure --prefix=$DIR/grib2 2>&1 | tee configure.log
	automake -a -f 2>&1 | tee automake.log
	make -j $CPU_HALF_EVEN 2>&1 | tee make.log
	make -j $CPU_HALF_EVEN install 2>&1 | tee make.install.log

	export JASPERLIB=$DIR/grib2/lib
	export JASPERINC=$DIR/grib2/include

	#############################hdf5 library for netcdf4 functionality############################
	cd $WRFCHEM_FOLDER/WRF_CHEM_Tools/Downloads
	tar -xvzf hdf5-$HDF5_Version.tar.gz
	cd hdf5-hdf5-$HDF5_Version
	autoreconf -i -f 2>&1 | tee autoreconf.log
	CC=$MPICC FC=$MPIFC F77=$MPIF77 F90=$MPIF90 CXX=$MPICXX ./configure --prefix=$DIR/grib2 --with-zlib=$DIR/grib2 --enable-hl --enable-fortran --enable-parallel 2>&1 | tee configure.log
	automake -a -f 2>&1 | tee automake.log
	make -j $CPU_HALF_EVEN 2>&1 | tee make.log
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
	cd $WRFCHEM_FOLDER/WRF_CHEM_Tools/Downloads
	tar -xvzf pnetcdf-$Pnetcdf_Version.tar.gz
	cd pnetcdf-$Pnetcdf_Version
	autoreconf -i -f 2>&1 | tee autoreconf.log
	CC=$MPICC FC=$MPIFC F77=$MPIF77 F90=$MPIF90 CXX=$MPICXX ./configure --prefix=$DIR/grib2 --enable-shared --enable-static 2>&1 | tee configure.log
	automake -a -f 2>&1 | tee automake.log
	make -j $CPU_HALF_EVEN 2>&1 | tee make.log
	make -j $CPU_HALF_EVEN install 2>&1 | tee make.install.log
	#make check

	export PNETCDF=$DIR/grib2

	##############################Install NETCDF C Library############################
	cd $WRFCHEM_FOLDER/WRF_CHEM_Tools/Downloads
	tar -xzvf v$Netcdf_C_Version.tar.gz
	cd netcdf-c-$Netcdf_C_Version/
	export CPPFLAGS=-I$DIR/grib2/include
	export LDFLAGS=-L$DIR/grib2/lib
	export LIBS="-lhdf5_hl -lhdf5 -lz -lcurl -lgfortran -lgcc -lm -ldl -lpnetcdf"
	autoreconf -i -f 2>&1 | tee autoreconf.log
	CC=$MPICC FC=$MPIFC F77=$MPIF77 F90=$MPIF90 CXX=$MPICXX ./configure --prefix=$DIR/NETCDF --with-zlib=$DIR/grib2 --disable-dap --enable-netcdf-4 --enable-netcdf4 --enable-shared --enable-static--enable-pnetcdf --enable-cdf5 --enable-parallel-tests 2>&1 | tee configure.log
	automake -a -f 2>&1 | tee automake.log
	make -j $CPU_HALF_EVEN 2>&1 | tee make.log
	make -j $CPU_HALF_EVEN install 2>&1 | tee make.install.log
	#make check

	export PATH=$DIR/NETCDF/bin:$PATH
	export NETCDF=$DIR/NETCDF

	##############################NetCDF fortran library############################
	cd $WRFCHEM_FOLDER/WRF_CHEM_Tools/Downloads
	tar -xvzf v$Netcdf_Fortran_Version.tar.gz
	cd netcdf-fortran-$Netcdf_Fortran_Version/
	export LD_LIBRARY_PATH=$DIR/NETCDF/lib:$LD_LIBRARY_PATH
	export CPPFLAGS="-I$DIR/NETCDF/include -I$DIR/grib2/include"
	export LDFLAGS="-L$DIR/NETCDF/lib -L$DIR/grib2/lib"
	export LIBS="-lnetcdf -lpnetcdf -lcurl -lhdf5_hl -lhdf5 -lz -ldl -lgcc -lgfortran"
	autoreconf -i -f 2>&1 | tee autoreconf.log
	CC=$MPICC FC=$MPIFC CXX=$MPICXX F90=$MPIF90 F77=$MPIF77 ./configure --prefix=$DIR/NETCDF --enable-netcdf-4 --enable-netcdf4 --enable-shared --enable-static--enable-parallel-tests --enable-hdf5 2>&1 | tee configure.log
	automake -a -f 2>&1 | tee automake.log
	make -j $CPU_HALF_EVEN 2>&1 | tee make.log
	make -j $CPU_HALF_EVEN install 2>&1 | tee make.install.log
	#make check

	echo " "

	# Downloading WRF-CHEM Tools and untarring files
	cd $WRFCHEM_FOLDER/WRF_CHEM_Tools/Downloads

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
	tar -xvf mozbc.tar -C $WRFCHEM_FOLDER/WRF_CHEM_Tools/mozbc
	echo ""
	echo "Unpacking MEGAN Bio Emission."
	tar -xvf megan_bio_emiss.tar -C $WRFCHEM_FOLDER/WRF_CHEM_Tools/megan_bio_emiss
	echo ""
	echo "Unpacking MEGAN Bio Emission Data."
	tar -xzvf megan.data.tar.gz -C $WRFCHEM_FOLDER/WRF_CHEM_Tools/megan_bio_data
	echo ""
	echo "Unpacking Wes Coldens"
	tar -xvf wes-coldens.tar -C $WRFCHEM_FOLDER/WRF_CHEM_Tools/wes_coldens
	echo ""
	echo "Unpacking Unpacking ANTHRO Emission."
	tar -xvf ANTHRO.tar -C $WRFCHEM_FOLDER/WRF_CHEM_Tools/ANTHRO_EMIS
	echo ""
	echo "Unpacking EDGAR-HTAP."
	tar -xzvf EDGAR-HTAP.tgz -C $WRFCHEM_FOLDER/WRF_CHEM_Tools/EDGAR_HTAP
	echo ""
	echo "Unpacking EPA ANTHRO Emission."
	tar -xzvf EPA_ANTHRO_EMIS.tgz -C $WRFCHEM_FOLDER/WRF_CHEM_Tools/EPA_ANTHRO_EMIS
	echo ""
	echo "Unpacking Upper Boundary Conditions."
	tar -xvf UBC_inputs.tar -C $WRFCHEM_FOLDER/WRF_CHEM_Tools/UBC
	echo ""
	echo "Unpacking Aircraft Preprocessor Files."
	echo ""
	tar -xvf aircraft_preprocessor_files.tar -C $WRFCHEM_FOLDER/WRF_CHEM_Tools/Aircraft
	echo ""
	echo "Unpacking Fire INventory from NCAR (FINN)"
	tar -xzvf fire_emis.tgz -C $WRFCHEM_FOLDER/WRF_CHEM_Tools/FINN
	tar -xvf fire_emis_input.tar
	tar -zxvf grass_from_img.nc.tgz -C $WRFCHEM_FOLDER/WRF_CHEM_Tools/FINN/grid_finn_fire_emis_v2020/src
	tar -zxvf tempfor_from_img.nc.tgz -C $WRFCHEM_FOLDER/WRF_CHEM_Tools/FINN/grid_finn_fire_emis_v2020/src
	tar -zxvf shrub_from_img.nc.tgz -C $WRFCHEM_FOLDER/WRF_CHEM_Tools/FINN/grid_finn_fire_emis_v2020/src
	tar -zxvf tropfor_from_img.nc.tgz -C $WRFCHEM_FOLDER/WRF_CHEM_Tools/FINN/grid_finn_fire_emis_v2020/src

	mv $WRFCHEM_FOLDER/WRF_CHEM_Tools/Downloads/FINNv2.4_MOD_MOZART_2020_c20210617.txt.gz $WRFCHEM_FOLDER/WRF_CHEM_Tools/FINN
	mv $WRFCHEM_FOLDER/WRF_CHEM_Tools/Downloads/FINNv2.4_MOD_MOZART_2013_c20210617.txt.gz $WRFCHEM_FOLDER/WRF_CHEM_Tools/FINN
	mv $WRFCHEM_FOLDER/WRF_CHEM_Tools/Downloads/FINNv2.4_MODVRS_MOZART_2019_c20210615.txt.gz $WRFCHEM_FOLDER/WRF_CHEM_Tools/FINN

	unzip TrashEmis.zip
	mv $WRFCHEM_FOLDER/WRF_CHEM_Tools/Downloads/ALL_Emiss_04282014.nc $WRFCHEM_FOLDER/WRF_CHEM_Tools/FINN/grid_finn_fire_emis_v2020/src

	cd $WRFCHEM_FOLDER/WRF_CHEM_Tools/FINN

	gunzip FINNv2.4_MOD_MOZART_2020_c20210617.txt.gz
	gunzip FINNv2.4_MOD_MOZART_2013_c20210617.txt.gz
	gunzip FINNv2.4_MODVRS_MOZART_2019_c20210615.txt.gz
	############################Installation of Mozbc #############################
	# Recalling variables from install script to make sure the path is right

	cd $WRFCHEM_FOLDER/WRF_CHEM_Tools/mozbc
	chmod +x make_mozbc
	export DIR=$WRFCHEM_FOLDER/WRF_CHEM_Tools/Libs
	export NETCDF_DIR=$DIR/NETCDF
	sed -i 's/"${ar_libs} -lnetcdff"/"-lnetcdff ${ar_libs}"/' make_mozbc

	./make_mozbc 2>&1 | tee make.log

	################## Information on Upper Boundary Conditions ###################

	cd $WRFCHEM_FOLDER/WRF_CHEM_Tools/UBC/
	wget -c https://www2.acom.ucar.edu/sites/default/files/documents/8A_2_Barth_WRFWorkshop_11.pdf

	########################## MEGAN Bio Emission #################################
	# Data for MEGAN Bio Emission located in
	# $WRFCHEM_FOLDER/WRF_CHEM_Tools/megan_bio_data

	cd $WRFCHEM_FOLDER/WRF_CHEM_Tools/megan_bio_emiss
	chmod +x make_util
	export DIR=$WRFCHEM_FOLDER/WRF_CHEM_Tools/Libs

	export NETCDF_DIR=$DIR/NETCDF
	sed -i 's/"${ar_libs} -lnetcdff"/"-lnetcdff ${ar_libs}"/' make_util

	./make_util megan_bio_emiss 2>&1 | tee make.bio.log
	./make_util megan_xform 2>&1 | tee make.xform.log
	./make_util surfdata_xform 2>&1 | tee make.surfdata.log

	############################# Anthroprogenic Emissions #########################

	cd $WRFCHEM_FOLDER/WRF_CHEM_Tools/ANTHRO_EMIS/ANTHRO/src
	chmod +x make_anthro
	export DIR=$WRFCHEM_FOLDER/WRF_CHEM_Tools/Libs

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
	cd $WRFCHEM_FOLDER/WRF_CHEM_Tools/EPA_ANTHRO_EMIS/src
	chmod +x make_anthro
	export DIR=$WRFCHEM_FOLDER/WRF_CHEM_Tools/Libs

	export NETCDF_DIR=$DIR/NETCDF
	sed -i 's/"${ar_libs} -lnetcdff"/"-lnetcdff ${ar_libs}"/' make_anthro

	./make_anthro 2>&1 | tee make.log

	######################### Weseley EXO Coldens ##################################
	cd $WRFCHEM_FOLDER/WRF_CHEM_Tools/wes_coldens
	chmod +x make_util
	export DIR=$WRFCHEM_FOLDER/WRF_CHEM_Tools/Libs

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
	brew install wget
	brew install git
	brew install gcc@12
	brew install libtool
	brew install automake
	brew install autoconf
	brew install make
	brew install m4
	brew install java
	brew install ksh
	brew install grads
	brew install ksh
	brew install tcsh
	brew install snapcraft
	brew install python@3.10
	brew install cmake
	brew install xorgproto
	brew install xorgrgb
	brew install xauth
	brew install curl
	brew install flex
	brew install byacc
	brew install bison
	brew install gnu-sed

	##############################Directory Listing############################

	export HOME=$(
		cd
		pwd
	)
	mkdir $HOME/WRFCHEM
	export WRFCHEM_FOLDER=$HOME/WRFCHEM
	cd $WRFCHEM_FOLDER/
	mkdir Downloads
	mkdir WRFDA
	mkdir Libs
	mkdir -p Libs/grib2
	mkdir -p Libs/NETCDF
	mkdir -p Tests/Environment
	mkdir -p Tests/Compatibility
	mkdir $WRFCHEM_FOLDER/WRF_CHEM_Tools
	mkdir $WRFCHEM_FOLDER/WRF_CHEM_Tools/Libs
	mkdir $WRFCHEM_FOLDER/WRF_CHEM_Tools/Libs/grib2
	mkdir $WRFCHEM_FOLDER/WRF_CHEM_Tools/Libs/NETCDF
	mkdir $WRFCHEM_FOLDER/WRF_CHEM_Tools/Downloads
	mkdir $WRFCHEM_FOLDER/WRF_CHEM_Tools/mozbc
	mkdir $WRFCHEM_FOLDER/WRF_CHEM_Tools/megan_bio_emiss
	mkdir $WRFCHEM_FOLDER/WRF_CHEM_Tools/megan_bio_data
	mkdir $WRFCHEM_FOLDER/WRF_CHEM_Tools/wes_coldens
	mkdir $WRFCHEM_FOLDER/WRF_CHEM_Tools/ANTHRO_EMIS
	mkdir $WRFCHEM_FOLDER/WRF_CHEM_Tools/EDGAR_HTAP
	mkdir $WRFCHEM_FOLDER/WRF_CHEM_Tools/EPA_ANTHRO_EMIS
	mkdir $WRFCHEM_FOLDER/WRF_CHEM_Tools/UBC
	mkdir $WRFCHEM_FOLDER/WRF_CHEM_Tools/Aircraft
	mkdir $WRFCHEM_FOLDER/WRF_CHEM_Tools/FINN

	export DIR=$WRFCHEM_FOLDER/WRF_CHEM_Tools/Libs

	#############################Core Management####################################
	export CPU_CORE=$(sysctl -n hw.ncpu) # number of available threads on system
	export CPU_6CORE="6"
	export CPU_HALF=$(($CPU_CORE / 2))
	#1/2 of availble cores on system
	export CPU_HALF_EVEN=$(($CPU_HALF - ($CPU_HALF % 2)))
	#Forces CPU cores to even number to avoid partial core export. ie 7 cores would be 3.5 cores.

	if [ $CPU_CORE -le $CPU_6CORE ]; then #If statement for low core systems.  Forces computers to only use 1 core if there are 4 cores or less on the system.
		export CPU_HALF_EVEN="2"
	else
		export CPU_HALF_EVEN=$(($CPU_HALF - ($CPU_HALF % 2)))
	fi

	echo "##########################################"
	echo "Number of Threads being used $CPU_HALF_EVEN"
	echo "##########################################"
	echo " "

	##############################Downloading Libraries############################

	cd $WRFCHEM_FOLDER/WRF_CHEM_Tools/Downloads
	wget -c https://github.com/madler/zlib/archive/refs/tags/v$Zlib_Version.tar.gz
	wget -c https://github.com/HDFGroup/hdf5/archive/refs/tags/hdf5-$HDF5_Version.tar.gz
	wget -c https://github.com/Unidata/netcdf-c/archive/refs/tags/v$Netcdf_C_Version.tar.gz
	wget -c https://github.com/Unidata/netcdf-fortran/archive/refs/tags/v$Netcdf_Fortran_Version.tar.gz
	wget -c https://download.sourceforge.net/libpng/libpng-$Libpng_Version.tar.gz
	wget -c https://www.ece.uvic.ca/~frodo/jasper/software/jasper-$Jasper_Version.zip
	wget -c https://github.com/pmodels/mpich/releases/download/v$Mpich_Version/mpich-$Mpich_Version.tar.gz
	wget -c https://parallel-netcdf.github.io/Release/pnetcdf-$Pnetcdf_Version.tar.gz

	echo " "

	#############################Compilers############################

	#Symlink to avoid clang conflicts with compilers
	#default gcc path /usr/bin/gcc
	#default homebrew path /usr/local/bin

	echo $PASSWD | sudo -S ln -sf /usr/local/bin/gcc-12 /usr/local/bin/gcc
	echo $PASSWD | sudo -S ln -sf /usr/local/bin/g++-12 /usr/local/bin/g++
	echo $PASSWD | sudo -S ln -sf /usr/local/bin/gfortran-12 /usr/local/bin/gfortran
	echo $PASSWD | sudo -S ln -sf /usr/local/bin/python3.10 /usr/local/bin/python3

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

	export FFLAGS="$fallow_argument -m64"
	export FCFLAGS="$fallow_argument -m64"

	echo "##########################################"
	echo "FFLAGS = $FFLAGS"
	echo "FCFLAGS = $FCFLAGS"
	echo "##########################################"

	echo " "

	#############################zlib############################
	#Uncalling compilers due to comfigure issue with zlib1.2.12
	#With CC & CXX definied ./configure uses different compiler Flags

	cd $WRFCHEM_FOLDER/WRF_CHEM_Tools/Downloads
	tar -xvzf v$Zlib_Version.tar.gz
	cd zlib-$Zlib_Version/
	autoreconf -i -f 2>&1 | tee autoreconf.log
	./configure --prefix=$DIR/grib2 2>&1 | tee configure.log
	automake -a -f 2>&1 | tee automake.log
	make -j $CPU_HALF_EVEN 2>&1 | tee make.log
	make -j $CPU_HALF_EVEN install 2>&1 | tee make.install.log
	#make check

	echo " "

	##############################MPICH############################
	cd $WRFCHEM_FOLDER/WRF_CHEM_Tools/Downloads
	tar -xvzf mpich-$Mpich_Version.tar.gz
	cd mpich-$Mpich_Version/
	autoreconf -i -f 2>&1 | tee autoreconf.log
	F90= ./configure --prefix=$DIR/MPICH --with-device=ch3 FFLAGS="$fallow_argument -m64" FCFLAGS="$fallow_argument -m64" 2>&1 | tee configure.log
	automake -a -f 2>&1 | tee automake.log
	make -j $CPU_HALF_EVEN 2>&1 | tee make.log
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
	cd $WRFCHEM_FOLDER/WRF_CHEM_Tools/Downloads
	export LDFLAGS=-L$DIR/grib2/lib
	export CPPFLAGS=-I$DIR/grib2/include
	tar -xvzf libpng-$Libpng_Version.tar.gz
	cd libpng-$Libpng_Version/
	autoreconf -i -f 2>&1 | tee autoreconf.log
	CC=$MPICC FC=$MPIFC F77=$MPIF77 F90=$MPIF90 CXX=$MPICXX ./configure --prefix=$DIR/grib2 2>&1 | tee configure.log
	automake -a -f 2>&1 | tee automake.log
	make -j $CPU_HALF_EVEN 2>&1 | tee make.log
	make -j $CPU_HALF_EVEN install 2>&1 | tee make.install.log
	#make check
	#make check

	echo " "
	#############################JasPer############################

	cd $WRFCHEM_FOLDER/WRF_CHEM_Tools/Downloads
	unzip jasper-$Jasper_Version.zip
	cd jasper-$Jasper_Version/
	autoreconf -i -f 2>&1 | tee autoreconf.log
	CC=$MPICC FC=$MPIFC F77=$MPIF77 F90=$MPIF90 CXX=$MPICXX ./configure --prefix=$DIR/grib2 2>&1 | tee configure.log
	automake -a -f 2>&1 | tee automake.log
	make -j $CPU_HALF_EVEN 2>&1 | tee make.log
	make -j $CPU_HALF_EVEN install 2>&1 | tee make.install.log
	export JASPERLIB=$DIR/grib2/lib
	export JASPERINC=$DIR/grib2/include

	echo " "
	#############################hdf5 library for netcdf4 functionality############################

	cd $WRFCHEM_FOLDER/WRF_CHEM_Tools/Downloads
	tar -xvzf hdf5-$HDF5_Version.tar.gz
	cd hdf5-hdf5-$HDF5_Version
	autoreconf -i -f 2>&1 | tee autoreconf.log
	CC=$MPICC FC=$MPIFC F77=$MPIF77 F90=$MPIF90 CXX=$MPICXX ./configure --prefix=$DIR/grib2 --with-zlib=$DIR/grib2 --enable-hl --enable-fortran --enable-parallel 2>&1 | tee configure.log
	automake -a -f 2>&1 | tee automake.log
	make -j $CPU_HALF_EVEN 2>&1 | tee make.log
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
	cd $WRFCHEM_FOLDER/WRF_CHEM_Tools/Downloads
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
	make -j $CPU_HALF_EVEN install 2>&1 | tee make.install.log
	#make check

	export PNETCDF=$DIR/grib2

	##############################Install NETCDF C Library############################
	cd $WRFCHEM_FOLDER/WRF_CHEM_Tools/Downloads
	tar -xzvf v$Netcdf_C_Version.tar.gz
	cd netcdf-c-$Netcdf_C_Version/
	export CPPFLAGS=-I$DIR/grib2/include
	export LDFLAGS=-L$DIR/grib2/lib
	export LIBS="-lhdf5_hl -lhdf5 -lz -lcurl -lgfortran -lgcc -lm -ldl -lpnetcdf"
	autoreconf -i -f 2>&1 | tee autoreconf.log
	CC=$MPICC FC=$MPIFC CXX=$MPICXX F90=$MPIF90 F77=$MPIF77 ./configure --prefix=$DIR/NETCDF --disable-dap --enable-netcdf-4 --enable-netcdf4 --enable-shared --enable-static--enable-pnetcdf --enable-cdf5 --enable-parallel-tests 2>&1 | tee configure.log
	automake -a -f 2>&1 | tee automake.log
	make -j $CPU_HALF_EVEN 2>&1 | tee make.log
	make -j $CPU_HALF_EVEN install 2>&1 | tee make.make.log
	#make check

	export PATH=$DIR/NETCDF/bin:$PATH
	export NETCDF=$DIR/NETCDF
	echo " "

	##############################NetCDF fortran library############################
	cd $WRFCHEM_FOLDER/WRF_CHEM_Tools/Downloads
	tar -xvzf v$Netcdf_Fortran_Version.tar.gz
	cd netcdf-fortran-$Netcdf_Fortran_Version/
	export LD_LIBRARY_PATH=$DIR/NETCDF/lib:$LD_LIBRARY_PATH
	export CPPFLAGS="-I$DIR/NETCDF/include -I$DIR/grib2/include"
	export LDFLAGS="-L$DIR/NETCDF/lib -L$DIR/grib2/lib"
	export LIBS="-lnetcdf -lpnetcdf -lcurl -lhdf5_hl -lhdf5 -lz -lm -ldl -lgcc -lgfortran"
	autoreconf -i -f 2>&1 | tee autoreconf.log
	CC=$MPICC FC=$MPIFC CXX=$MPICXX F90=$MPIF90 F77=$MPIF77 ./configure --prefix=$DIR/NETCDF --enable-netcdf-4 --enable-netcdf4 --enable-shared --enable-static--enable-parallel-tests --enable-hdf5 2>&1 | tee configure.log
	automake -a -f 2>&1 | tee automake.log
	make -j $CPU_HALF_EVEN 2>&1 | tee make.log
	make -j $CPU_HALF_EVEN install 2>&1 | tee make.install.log
	#make check

	echo " "

	# Downloading WRF-CHEM Tools and untarring files
	cd $WRFCHEM_FOLDER/WRF_CHEM_Tools/Downloads

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
	tar -xvf mozbc.tar -C $WRFCHEM_FOLDER/WRF_CHEM_Tools/mozbc
	echo ""
	echo "Unpacking MEGAN Bio Emission."
	tar -xvf megan_bio_emiss.tar -C $WRFCHEM_FOLDER/WRF_CHEM_Tools/megan_bio_emiss
	echo ""
	echo "Unpacking MEGAN Bio Emission Data."
	tar -xzvf megan.data.tar.gz -C $WRFCHEM_FOLDER/WRF_CHEM_Tools/megan_bio_data
	echo ""
	echo "Unpacking Wes Coldens"
	tar -xvf wes-coldens.tar -C $WRFCHEM_FOLDER/WRF_CHEM_Tools/wes_coldens
	echo ""
	echo "Unpacking Unpacking ANTHRO Emission."
	tar -xvf ANTHRO.tar -C $WRFCHEM_FOLDER/WRF_CHEM_Tools/ANTHRO_EMIS
	echo ""
	echo "Unpacking EDGAR-HTAP."
	tar -xzvf EDGAR-HTAP.tgz -C $WRFCHEM_FOLDER/WRF_CHEM_Tools/EDGAR_HTAP
	echo ""
	echo "Unpacking EPA ANTHRO Emission."
	tar -xzvf EPA_ANTHRO_EMIS.tgz -C $WRFCHEM_FOLDER/WRF_CHEM_Tools/EPA_ANTHRO_EMIS
	echo ""
	echo "Unpacking Upper Boundary Conditions."
	tar -xvf UBC_inputs.tar -C $WRFCHEM_FOLDER/WRF_CHEM_Tools/UBC
	echo ""
	echo "Unpacking Aircraft Preprocessor Files."
	echo ""
	tar -xvf aircraft_preprocessor_files.tar -C $WRFCHEM_FOLDER/WRF_CHEM_Tools/Aircraft
	echo ""
	echo "Unpacking Fire INventory from NCAR (FINN)"
	tar -xzvf fire_emis.tgz -C $WRFCHEM_FOLDER/WRF_CHEM_Tools/FINN
	tar -xvf fire_emis_input.tar
	tar -zxvf grass_from_img.nc.tgz -C $WRFCHEM_FOLDER/WRF_CHEM_Tools/FINN/grid_finn_fire_emis_v2020/src
	tar -zxvf tempfor_from_img.nc.tgz -C $WRFCHEM_FOLDER/WRF_CHEM_Tools/FINN/grid_finn_fire_emis_v2020/src
	tar -zxvf shrub_from_img.nc.tgz -C $WRFCHEM_FOLDER/WRF_CHEM_Tools/FINN/grid_finn_fire_emis_v2020/src
	tar -zxvf tropfor_from_img.nc.tgz -C $WRFCHEM_FOLDER/WRF_CHEM_Tools/FINN/grid_finn_fire_emis_v2020/src

	mv $WRFCHEM_FOLDER/WRF_CHEM_Tools/Downloads/FINNv2.4_MOD_MOZART_2020_c20210617.txt.gz $WRFCHEM_FOLDER/WRF_CHEM_Tools/FINN
	mv $WRFCHEM_FOLDER/WRF_CHEM_Tools/Downloads/FINNv2.4_MOD_MOZART_2013_c20210617.txt.gz $WRFCHEM_FOLDER/WRF_CHEM_Tools/FINN
	mv $WRFCHEM_FOLDER/WRF_CHEM_Tools/Downloads/FINNv2.4_MODVRS_MOZART_2019_c20210615.txt.gz $WRFCHEM_FOLDER/WRF_CHEM_Tools/FINN

	unzip TrashEmis.zip
	mv $WRFCHEM_FOLDER/WRF_CHEM_Tools/Downloads/ALL_Emiss_04282014.nc $WRFCHEM_FOLDER/WRF_CHEM_Tools/FINN/grid_finn_fire_emis_v2020/src

	cd $WRFCHEM_FOLDER/WRF_CHEM_Tools/FINN

	gunzip FINNv2.4_MOD_MOZART_2020_c20210617.txt.gz
	gunzip FINNv2.4_MOD_MOZART_2013_c20210617.txt.gz
	gunzip FINNv2.4_MODVRS_MOZART_2019_c20210615.txt.gz
	############################Installation of Mozbc #############################
	export fallow_argument=-fallow-argument-mismatch
	export boz_argument=-fallow-invalid-boz

	# Recalling variables from install script to make sure the path is right

	cd $WRFCHEM_FOLDER/WRF_CHEM_Tools/mozbc
	chmod +x make_mozbc
	export DIR=$WRFCHEM_FOLDER/WRF_CHEM_Tools/Libs
	export FC=gfortran
	export NETCDF_DIR=$DIR/NETCDF
	sed -i'' -e 's/"${ar_libs} -lnetcdff"/"-lnetcdff ${ar_libs}"/' make_mozbc
	sed -i'' -e '8s/FFLAGS = --g/FFLAGS = --g ${fallow_argument}/' Makefile
	sed -i'' -e '10s/FFLAGS = -g/FFLAGS = -g ${fallow_argument}/' Makefile
	./make_mozbc 2>&1 | tee make.log

	################## Information on Upper Boundary Conditions ###################

	cd $WRFCHEM_FOLDER/WRF_CHEM_Tools/UBC/
	wget -c https://www2.acom.ucar.edu/sites/default/files/documents/8A_2_Barth_WRFWorkshop_11.pdf

	########################## MEGAN Bio Emission #################################
	# Data for MEGAN Bio Emission located in
	# $WRFCHEM_FOLDER/WRF_CHEM_Tools/megan_bio_data

	cd $WRFCHEM_FOLDER/WRF_CHEM_Tools/megan_bio_emiss
	chmod +x make_util
	export DIR=$WRFCHEM_FOLDER/WRF_CHEM_Tools/Libs
	export FC=gfortran
	export NETCDF_DIR=$DIR/NETCDF
	sed -i'' -e 's/"${ar_libs} -lnetcdff"/"-lnetcdff ${ar_libs}"/' make_util
	sed -i'' -e '8s/FFLAGS = --g/FFLAGS = --g ${fallow_argument}/' Makefile
	sed -i'' -e '10s/FFLAGS = -g/FFLAGS = -g ${fallow_argument}/' Makefile
	./make_util megan_bio_emiss 2>&1 | tee make.bio.log
	./make_util megan_xform 2>&1 | tee make.xform.log
	./make_util surfdata_xform 2>&1 | tee make.surfdata.log

	############################# Anthroprogenic Emissions #########################

	cd $WRFCHEM_FOLDER/WRF_CHEM_Tools/ANTHRO_EMIS/ANTHRO/src
	chmod +x make_anthro
	export DIR=$WRFCHEM_FOLDER/WRF_CHEM_Tools/Libs
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
	cd $WRFCHEM_FOLDER/WRF_CHEM_Tools/EPA_ANTHRO_EMIS/src
	chmod +x make_anthro
	export DIR=$WRFCHEM_FOLDER/WRF_CHEM_Tools/Libs
	export FC=gfortran
	export NETCDF_DIR=$DIR/NETCDF
	sed -i'' -e 's/"${ar_libs} -lnetcdff"/"-lnetcdff ${ar_libs}"/' make_anthro
	sed -i'' -e '8s/FFLAGS = --g/FFLAGS = --g ${fallow_argument}/' Makefile
	sed -i'' -e '10s/FFLAGS = -g/FFLAGS = -g ${fallow_argument}/' Makefile
	./make_anthro 2>&1 | tee make.log

	######################### Weseley EXO Coldens ##################################
	cd $WRFCHEM_FOLDER/WRF_CHEM_Tools/wes_coldens
	chmod +x make_util
	export DIR=$WRFCHEM_FOLDER/WRF_CHEM_Tools/Libs
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
	brew install wget
	brew install git
	brew install gcc@12
	brew install libtool
	brew install automake
	brew install autoconf
	brew install make
	brew install m4
	brew install java
	brew install ksh
	brew install grads
	brew install ksh
	brew install tcsh
	brew install snapcraft
	brew install python@3.10
	brew install cmake
	brew install xorgproto
	brew install xorgrgb
	brew install xauth
	brew install curl
	brew install flex
	brew install byacc
	brew install bison
	brew install gnu-sed

	##############################Directory Listing############################

	export HOME=$(
		cd
		pwd
	)
	mkdir $HOME/WRFCHEM
	export WRFCHEM_FOLDER=$HOME/WRFCHEM
	cd $WRFCHEM_FOLDER/
	mkdir Downloads
	mkdir WRFDA
	mkdir Libs
	mkdir -p Libs/grib2
	mkdir -p Libs/NETCDF
	mkdir -p Tests/Environment
	mkdir -p Tests/Compatibility
	mkdir $WRFCHEM_FOLDER/WRF_CHEM_Tools
	mkdir $WRFCHEM_FOLDER/WRF_CHEM_Tools/Libs
	mkdir $WRFCHEM_FOLDER/WRF_CHEM_Tools/Libs/grib2
	mkdir $WRFCHEM_FOLDER/WRF_CHEM_Tools/Libs/NETCDF
	mkdir $WRFCHEM_FOLDER/WRF_CHEM_Tools/Downloads
	mkdir $WRFCHEM_FOLDER/WRF_CHEM_Tools/mozbc
	mkdir $WRFCHEM_FOLDER/WRF_CHEM_Tools/megan_bio_emiss
	mkdir $WRFCHEM_FOLDER/WRF_CHEM_Tools/megan_bio_data
	mkdir $WRFCHEM_FOLDER/WRF_CHEM_Tools/wes_coldens
	mkdir $WRFCHEM_FOLDER/WRF_CHEM_Tools/ANTHRO_EMIS
	mkdir $WRFCHEM_FOLDER/WRF_CHEM_Tools/EDGAR_HTAP
	mkdir $WRFCHEM_FOLDER/WRF_CHEM_Tools/EPA_ANTHRO_EMIS
	mkdir $WRFCHEM_FOLDER/WRF_CHEM_Tools/UBC
	mkdir $WRFCHEM_FOLDER/WRF_CHEM_Tools/Aircraft
	mkdir $WRFCHEM_FOLDER/WRF_CHEM_Tools/FINN

	export DIR=$WRFCHEM_FOLDER/WRF_CHEM_Tools/Libs

	#############################Core Management####################################
	export CPU_CORE=$(sysctl -n hw.ncpu) # number of available threads on system
	export CPU_6CORE="6"
	export CPU_HALF=$(($CPU_CORE / 2))
	#1/2 of availble cores on system
	export CPU_HALF_EVEN=$(($CPU_HALF - ($CPU_HALF % 2)))
	#Forces CPU cores to even number to avoid partial core export. ie 7 cores would be 3.5 cores.

	if [ $CPU_CORE -le $CPU_6CORE ]; then #If statement for low core systems.  Forces computers to only use 1 core if there are 4 cores or less on the system.
		export CPU_HALF_EVEN="2"
	else
		export CPU_HALF_EVEN=$(($CPU_HALF - ($CPU_HALF % 2)))
	fi

	echo "##########################################"
	echo "Number of Threads being used $CPU_HALF_EVEN"
	echo "##########################################"
	echo " "

	##############################Downloading Libraries############################

	cd $WRFCHEM_FOLDER/WRF_CHEM_Tools/Downloads
	wget -c https://github.com/madler/zlib/archive/refs/tags/v$Zlib_Version.tar.gz
	wget -c https://github.com/HDFGroup/hdf5/archive/refs/tags/hdf5-$HDF5_Version.tar.gz
	wget -c https://github.com/Unidata/netcdf-c/archive/refs/tags/v$Netcdf_C_Version.tar.gz
	wget -c https://github.com/Unidata/netcdf-fortran/archive/refs/tags/v$Netcdf_Fortran_Version.tar.gz
	wget -c https://download.sourceforge.net/libpng/libpng-$Libpng_Version.tar.gz
	wget -c https://www.ece.uvic.ca/~frodo/jasper/software/jasper-$Jasper_Version.zip
	wget -c https://github.com/pmodels/mpich/releases/download/v$Mpich_Version/mpich-$Mpich_Version.tar.gz
	wget -c https://parallel-netcdf.github.io/Release/pnetcdf-$Pnetcdf_Version.tar.gz

	echo " "

	#############################Compilers############################
	#Symlink to avoid clang conflicts with compilers
	#default gcc path /usr/bin/gcc
	#default homebrew path /usr/local/bin
	echo $PASSWD | sudo -S unlink /opt/homebrew/bin/gfortran
	echo $PASSWD | sudo -S unlink /opt/homebrew/bin/gcc
	echo $PASSWD | sudo -S unlink /opt/homebrew/bin/g++

	source ~./bashrc
	gcc --version
	g++ --version
	gfortran --version

	cd /opt/homebrew/bin

	echo $PASSWD | sudo -S ln -sf gcc-12 gcc
	echo $PASSWD | sudo -S ln -sf g++-12 g++
	echo $PASSWD | sudo -S ln -sf gfortran-12 gfortran

	source ~/.bashrc
	source ~/.bash_profile

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

	export FFLAGS="$fallow_argument -m64"
	export FCFLAGS="$fallow_argument -m64"

	echo "##########################################"
	echo "FFLAGS = $FFLAGS"
	echo "FCFLAGS = $FCFLAGS"
	echo "##########################################"

	echo " "

	#############################zlib############################
	#Uncalling compilers due to comfigure issue with zlib1.2.12
	#With CC & CXX definied ./configure uses different compiler Flags

	cd $WRFCHEM_FOLDER/WRF_CHEM_Tools/Downloads
	tar -xvzf v$Zlib_Version.tar.gz
	cd zlib-$Zlib_Version/
	autoreconf -i -f 2>&1 | tee autoreconf.log
	./configure --prefix=$DIR/grib2 2>&1 | tee configure.log
	automake -a -f 2>&1 | tee automake.log
	make -j $CPU_HALF_EVEN 2>&1 | tee make.log
	make -j $CPU_HALF_EVEN install 2>&1 | tee make.install.log
	#make check

	echo " "

	##############################MPICH############################
	cd $WRFCHEM_FOLDER/WRF_CHEM_Tools/Downloads
	tar -xvzf mpich-$Mpich_Version.tar.gz
	cd mpich-$Mpich_Version/
	autoreconf -i -f 2>&1 | tee autoreconf.log
	F90= ./configure --prefix=$DIR/MPICH --with-device=ch3 FFLAGS="$fallow_argument -m64" FCFLAGS="$fallow_argument -m64" 2>&1 | tee configure.log
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
	cd $WRFCHEM_FOLDER/WRF_CHEM_Tools/Downloads
	export LDFLAGS=-L$DIR/grib2/lib
	export CPPFLAGS=-I$DIR/grib2/include
	tar -xvzf libpng-$Libpng_Version.tar.gz
	cd libpng-$Libpng_Version/
	autoreconf -i -f 2>&1 | tee autoreconf.log
	CC=$MPICC FC=$MPIFC F77=$MPIF77 F90=$MPIF90 CXX=$MPICXX ./configure --prefix=$DIR/grib2 2>&1 | tee configure.log
	automake -a -f 2>&1 | tee automake.log
	make -j $CPU_HALF_EVEN 2>&1 | tee make.log
	make -j $CPU_HALF_EVEN install 2>&1 | tee make.install.log
	#make check
	#make check

	echo " "
	#############################JasPer############################

	cd $WRFCHEM_FOLDER/WRF_CHEM_Tools/Downloads
	unzip jasper-$Jasper_Version.zip
	cd jasper-$Jasper_Version/
	autoreconf -i -f 2>&1 | tee autoreconf.log
	CC=$MPICC FC=$MPIFC F77=$MPIF77 F90=$MPIF90 CXX=$MPICXX ./configure --prefix=$DIR/grib2 2>&1 | tee configure.log
	automake -a -f 2>&1 | tee automake.log
	make -j $CPU_HALF_EVEN 2>&1 | tee make.log
	make -j $CPU_HALF_EVEN install 2>&1 | tee make.install.log
	export JASPERLIB=$DIR/grib2/lib
	export JASPERINC=$DIR/grib2/include

	echo " "
	#############################hdf5 library for netcdf4 functionality############################

	cd $WRFCHEM_FOLDER/WRF_CHEM_Tools/Downloads
	tar -xvzf hdf5-$HDF5_Version.tar.gz
	cd hdf5-hdf5-$HDF5_Version
	autoreconf -i -f 2>&1 | tee autoreconf.log
	CC=$MPICC FC=$MPIFC F77=$MPIF77 F90=$MPIF90 CXX=$MPICXX ./configure --prefix=$DIR/grib2 --with-zlib=$DIR/grib2 --enable-hl --enable-fortran --enable-parallel 2>&1 | tee configure.log
	automake -a -f 2>&1 | tee automake.log
	make -j $CPU_HALF_EVEN 2>&1 | tee make.log
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
	cd $WRFCHEM_FOLDER/WRF_CHEM_Tools/Downloads
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
	make -j $CPU_HALF_EVEN install 2>&1 | tee make.install.log
	#make check

	export PNETCDF=$DIR/grib2

	##############################Install NETCDF C Library############################
	cd $WRFCHEM_FOLDER/WRF_CHEM_Tools/Downloads
	tar -xzvf v$Netcdf_C_Version.tar.gz
	cd netcdf-c-$Netcdf_C_Version/
	export CPPFLAGS=-I$DIR/grib2/include
	export LDFLAGS=-L$DIR/grib2/lib
	export LIBS="-lhdf5_hl -lhdf5 -lz -lcurl -lgfortran -lgcc -lm -ldl -lpnetcdf"
	autoreconf -i -f 2>&1 | tee autoreconf.log
	CC=$MPICC FC=$MPIFC CXX=$MPICXX F90=$MPIF90 F77=$MPIF77 ./configure --prefix=$DIR/NETCDF --disable-dap --enable-netcdf-4 --enable-netcdf4 --enable-shared --enable-static--enable-pnetcdf --enable-cdf5 --enable-parallel-tests 2>&1 | tee configure.log
	automake -a -f 2>&1 | tee automake.log
	make -j $CPU_HALF_EVEN 2>&1 | tee make.log
	make -j $CPU_HALF_EVEN install 2>&1 | tee make.install.log
	#make check

	export PATH=$DIR/NETCDF/bin:$PATH
	export NETCDF=$DIR/NETCDF
	echo " "

	##############################NetCDF fortran library############################
	cd $WRFCHEM_FOLDER/WRF_CHEM_Tools/Downloads
	tar -xvzf v$Netcdf_Fortran_Version.tar.gz
	cd netcdf-fortran-$Netcdf_Fortran_Version/
	export LD_LIBRARY_PATH=$DIR/NETCDF/lib:$LD_LIBRARY_PATH
	export CPPFLAGS="-I$DIR/NETCDF/include -I$DIR/grib2/include"
	export LDFLAGS="-L$DIR/NETCDF/lib -L$DIR/grib2/lib"
	export LIBS="-lnetcdf -lpnetcdf -lcurl -lhdf5_hl -lhdf5 -lz -lm -ldl -lgcc -lgfortran"
	autoreconf -i -f 2>&1 | tee autoreconf.log
	CC=$MPICC FC=$MPIFC CXX=$MPICXX F90=$MPIF90 F77=$MPIF77 ./configure --prefix=$DIR/NETCDF --enable-netcdf-4 --enable-netcdf4 --enable-shared --enable-static--enable-parallel-tests --enable-hdf5 2>&1 | tee configure.log
	automake -a -f 2>&1 | tee automake.log
	make -j $CPU_HALF_EVEN 2>&1 | tee make.log
	make -j $CPU_HALF_EVEN install 2>&1 | tee make.install.log
	#make check

	echo " "

	# Downloading WRF-CHEM Tools and untarring files
	cd $WRFCHEM_FOLDER/WRF_CHEM_Tools/Downloads

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
	tar -xvf mozbc.tar -C $WRFCHEM_FOLDER/WRF_CHEM_Tools/mozbc
	echo ""
	echo "Unpacking MEGAN Bio Emission."
	tar -xvf megan_bio_emiss.tar -C $WRFCHEM_FOLDER/WRF_CHEM_Tools/megan_bio_emiss
	echo ""
	echo "Unpacking MEGAN Bio Emission Data."
	tar -xzvf megan.data.tar.gz -C $WRFCHEM_FOLDER/WRF_CHEM_Tools/megan_bio_data
	echo ""
	echo "Unpacking Wes Coldens"
	tar -xvf wes-coldens.tar -C $WRFCHEM_FOLDER/WRF_CHEM_Tools/wes_coldens
	echo ""
	echo "Unpacking Unpacking ANTHRO Emission."
	tar -xvf ANTHRO.tar -C $WRFCHEM_FOLDER/WRF_CHEM_Tools/ANTHRO_EMIS
	echo ""
	echo "Unpacking EDGAR-HTAP."
	tar -xzvf EDGAR-HTAP.tgz -C $WRFCHEM_FOLDER/WRF_CHEM_Tools/EDGAR_HTAP
	echo ""
	echo "Unpacking EPA ANTHRO Emission."
	tar -xzvf EPA_ANTHRO_EMIS.tgz -C $WRFCHEM_FOLDER/WRF_CHEM_Tools/EPA_ANTHRO_EMIS
	echo ""
	echo "Unpacking Upper Boundary Conditions."
	tar -xvf UBC_inputs.tar -C $WRFCHEM_FOLDER/WRF_CHEM_Tools/UBC
	echo ""
	echo "Unpacking Aircraft Preprocessor Files."
	echo ""
	tar -xvf aircraft_preprocessor_files.tar -C $WRFCHEM_FOLDER/WRF_CHEM_Tools/Aircraft
	echo ""
	echo "Unpacking Fire INventory from NCAR (FINN)"
	tar -xzvf fire_emis.tgz -C $WRFCHEM_FOLDER/WRF_CHEM_Tools/FINN
	tar -xvf fire_emis_input.tar
	tar -zxvf grass_from_img.nc.tgz -C $WRFCHEM_FOLDER/WRF_CHEM_Tools/FINN/grid_finn_fire_emis_v2020/src
	tar -zxvf tempfor_from_img.nc.tgz -C $WRFCHEM_FOLDER/WRF_CHEM_Tools/FINN/grid_finn_fire_emis_v2020/src
	tar -zxvf shrub_from_img.nc.tgz -C $WRFCHEM_FOLDER/WRF_CHEM_Tools/FINN/grid_finn_fire_emis_v2020/src
	tar -zxvf tropfor_from_img.nc.tgz -C $WRFCHEM_FOLDER/WRF_CHEM_Tools/FINN/grid_finn_fire_emis_v2020/src

	mv $WRFCHEM_FOLDER/WRF_CHEM_Tools/Downloads/FINNv2.4_MOD_MOZART_2020_c20210617.txt.gz $WRFCHEM_FOLDER/WRF_CHEM_Tools/FINN
	mv $WRFCHEM_FOLDER/WRF_CHEM_Tools/Downloads/FINNv2.4_MOD_MOZART_2013_c20210617.txt.gz $WRFCHEM_FOLDER/WRF_CHEM_Tools/FINN
	mv $WRFCHEM_FOLDER/WRF_CHEM_Tools/Downloads/FINNv2.4_MODVRS_MOZART_2019_c20210615.txt.gz $WRFCHEM_FOLDER/WRF_CHEM_Tools/FINN

	unzip TrashEmis.zip
	mv $WRFCHEM_FOLDER/WRF_CHEM_Tools/Downloads/ALL_Emiss_04282014.nc $WRFCHEM_FOLDER/WRF_CHEM_Tools/FINN/grid_finn_fire_emis_v2020/src

	cd $WRFCHEM_FOLDER/WRF_CHEM_Tools/FINN

	gunzip FINNv2.4_MOD_MOZART_2020_c20210617.txt.gz
	gunzip FINNv2.4_MOD_MOZART_2013_c20210617.txt.gz
	gunzip FINNv2.4_MODVRS_MOZART_2019_c20210615.txt.gz
	############################Installation of Mozbc #############################
	export fallow_argument=-fallow-argument-mismatch
	export boz_argument=-fallow-invalid-boz

	# Recalling variables from install script to make sure the path is right

	cd $WRFCHEM_FOLDER/WRF_CHEM_Tools/mozbc
	chmod +x make_mozbc
	export DIR=$WRFCHEM_FOLDER/WRF_CHEM_Tools/Libs
	export FC=gfortran
	export NETCDF_DIR=$DIR/NETCDF
	sed -i'' -e 's/"${ar_libs} -lnetcdff"/"-lnetcdff ${ar_libs}"/' make_mozbc
	sed -i'' -e '8s/FFLAGS = --g/FFLAGS = --g ${fallow_argument}/' Makefile
	sed -i'' -e '10s/FFLAGS = -g/FFLAGS = -g ${fallow_argument}/' Makefile
	./make_mozbc 2>&1 | tee make.log

	################## Information on Upper Boundary Conditions ###################

	cd $WRFCHEM_FOLDER/WRF_CHEM_Tools/UBC/
	wget -c https://www2.acom.ucar.edu/sites/default/files/documents/8A_2_Barth_WRFWorkshop_11.pdf

	########################## MEGAN Bio Emission #################################
	# Data for MEGAN Bio Emission located in
	# $WRFCHEM_FOLDER/WRF_CHEM_Tools/megan_bio_data

	cd $WRFCHEM_FOLDER/WRF_CHEM_Tools/megan_bio_emiss
	chmod +x make_util
	export DIR=$WRFCHEM_FOLDER/WRF_CHEM_Tools/Libs
	export FC=gfortran
	export NETCDF_DIR=$DIR/NETCDF
	sed -i'' -e 's/"${ar_libs} -lnetcdff"/"-lnetcdff ${ar_libs}"/' make_util
	sed -i'' -e '8s/FFLAGS = --g/FFLAGS = --g ${fallow_argument}/' Makefile
	sed -i'' -e '10s/FFLAGS = -g/FFLAGS = -g ${fallow_argument}/' Makefile
	./make_util megan_bio_emiss 2>&1 | tee make.bio.log
	./make_util megan_xform 2>&1 | tee make.xform.log
	./make_util surfdata_xform 2>&1 | tee make.surfdata.log

	############################# Anthroprogenic Emissions #########################

	cd $WRFCHEM_FOLDER/WRF_CHEM_Tools/ANTHRO_EMIS/ANTHRO/src
	chmod +x make_anthro
	export DIR=$WRFCHEM_FOLDER/WRF_CHEM_Tools/Libs
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
	cd $WRFCHEM_FOLDER/WRF_CHEM_Tools/EPA_ANTHRO_EMIS/src
	chmod +x make_anthro
	export DIR=$WRFCHEM_FOLDER/WRF_CHEM_Tools/Libs
	export FC=gfortran
	export NETCDF_DIR=$DIR/NETCDF
	sed -i'' -e 's/"${ar_libs} -lnetcdff"/"-lnetcdff ${ar_libs}"/' make_anthro
	sed -i'' -e '8s/FFLAGS = --g/FFLAGS = --g ${fallow_argument}/' Makefile
	sed -i'' -e '10s/FFLAGS = -g/FFLAGS = -g ${fallow_argument}/' Makefile
	./make_anthro 2>&1 | tee make.log

	######################### Weseley EXO Coldens ##################################
	cd $WRFCHEM_FOLDER/WRF_CHEM_Tools/wes_coldens
	chmod +x make_util
	export DIR=$WRFCHEM_FOLDER/WRF_CHEM_Tools/Libs
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
