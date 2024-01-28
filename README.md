### WRF CHEM TOOLS Multi Operational System Install Toolkit
This is a BASH script that provides options to install the following WRF CHEM Tools packages in 64-bit systems:

- Mozbc
- Megan Bio Emiss
- Megan Bio Data
- Wes Coldens
- ANTHRO EMIS
- EDGAR HTAP
- EPA ANTHO EMIS
- UBC
- Aircraft
- FINN
---
### System Requirements
- 64-bit system
    - Darwin (MacOS)
    - Linux Debian Distro (Ubuntu, Mint, etc)
    - Linux Fedora Distro (CentOS, Fedora, etc)
    - Windows Subsystem for Linux (Debian Distro, Ubuntu, Mint, etc)

---
---
### Libraries Installed (Latest libraries as of 10/01/2023)
- Libraries are manually installed in sub-folders utilizing either Intel or GNU Compilers.
    - Libraries installed with GNU compilers
        - zlib (1.2.13)
        - MPICH (4.1.2)
        - libpng (1.6.39)
        - JasPer (1.900.1)
        - HDF5 (1.14.2)
        - PHDF5 (1.14.2)
        - Parallel-NetCDF (1.12.3)
        - NetCDF-C (4.9.2)
        - NetCDF-Fortran (4.6.1)
        - Miniconda
    - Libraries installed with Intel compilers
        - zlib (1.2.13)
        - libpng (1.6.39)
        - JasPer (1.900.1)
        - HDF5 (1.14.2)
        - PHDF5 (1.14.2)
        - Parallel-NetCDF (1.12.3)
        - NetCDF-C (4.9.2)
        - NetCDF-Fortran (4.6.1)
        - Miniconda
        - Intel-Basekit
        - Intel-HPCKIT
        - Intel-AIKIT


---
### MacOS Installation
- Make sure to download and Homebrew before moving to installation.
> /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/master/install.sh)"

### Installation
- (Make sure to download folder into your Home Directory): cd $HOME


> git clone https://github.com/HathewayWill/WRFCHEM-TOOLS-MOSIT.git

> cd $HOME/WRFCHEM-TOOLS-MOSIT

> chmod 775 *.sh
>
> ./WRFCHEM_TOOLS_MOSIT.sh

- Script will check for System Architecture Type.

--

  ##### *** Tested on Ubuntu 20.04.5 LTS,  Ubuntu 22.04.1 LTS, MacOS Ventura, Windows Sub-Linux Ubuntu, CentOS***
- Built 64-bit system.

---

### Sponsorships and donations accepted but not required
Click here!
[![](https://img.shields.io/static/v1?label=Sponsor&message=%E2%9D%A4&logo=GitHub&color=%23fe8e86)](https://github.com/sponsors/HathewayWill)

- Sponsorships help the author push updates to the end user faster, maintain and update code, develop new code, provide end user support, and end user consulting.
---
#### Estimated Run Time ~ 10 to 30 Minutes @ 10mbps download speed.

---
### Special thanks to:
- Youtube's meteoadriatic
- GitHub user jamal919
- University of Manchester's  Doug L
- University of Tunis El Manar's Hosni S.
- GSL's Jordan S.
- NCAR's Mary B., Christine W., & Carl D.
- DTC's Julie P., Tara J., George M., & John H.
- UCAR's Katelyn F., Jim B., Jordan P., Kevin M.,.
---
#### Citation:
#### Hatheway, W. (2023). WRF CHEM Tools Multi Operational System Install Toolkit (Version 1.1) [Computer software]

---
#### References:
- "We acknowledge use of the WRF-Chem preprocessor tool {name of tool} provided by the Atmospheric Chemistry Observations and Modeling Lab (ACOM) of NCAR."
- Peckham, S., G. A. Grell, S. A. McKeen, M. Barth, G. Pfister, C. Wiedinmyer, J. D. Fast, W. I. Gustafson, R. Zaveri, R. C. Easter, J. Barnard, E. Chapman, M. Hewson, R. Schmitz, M. Salzmann, S. Freitas, 2011: WRF-Chem Version 3.3 User's Guide. NOAA Technical Memo., 98 pp.
