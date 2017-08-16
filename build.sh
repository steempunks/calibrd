#!/bin/bash
OUTPUTDIR="$(pwd)"
BINARYNAME="steemd"
WORKROOT="/tmp/calibrd-work"

# Colours for console output
BLK='\033[0;30m';DGY='\033[1;30';RED='\033[0;31m';LRD='\033[1;31m';GRN='\033[0;32m';LGN='\033[1;32m'
ORG='\033[0;33m';YLW='\033[1;33m';BLU='\033[0;34m';LBL='\033[1;34m';PRP='\033[0;35m';LPR='\033[1;35m'
CYN='\033[0;36m';LCY='\033[1;36m';LGY='\033[0;37m';WHT='\033[1;37m';NC='\033[0m'
PFX="###"

function prstat {
  printf "$PFX $1\n"
}
function prtrue {
  printf "$GRN$PFX $1$NC\n"
}
function prfalse {
  printf "$RED$PFX $1$NC\n"
}

# We need to trap Ctrl-C because this script bindmounts system virtual folders and must be cleaned up
trap cleanup INT

# Cleanup functions are atomic, testing for completion variables being set
function cleanup {
  # First we want to put a newline after the ^C that the console prints, for aesthetic purposes
  printf "\n"
  
  prstat "Cleaning up..."
  
  # Remove the chroot if it has been created
  if [ $MOUNTEDSYSFOLDERS ]; then
    prstat "Unmounting chroot bind mounts"
    sudo umount $WORKROOT/ubuntu14/dev/pts
    sudo umount $WORKROOT/ubuntu14/dev
    sudo umount $WORKROOT/ubuntu14/proc
    sudo umount $WORKROOT/ubuntu14/sys
  fi

  # Each step of the process has an initialising indication and
  # a completed indicator. Only initialised but incomplete steps
  # are cleaned up

  # Finally, remove the working folder if process was finished
  if [[ -f $WORKROOT/.complete ]]; then
    prstat "removing $WORKROOT"
    sudo rm -rf $WORKROOT
  fi

  # Let's blow this popstand!
  exit
}


prstat "Building $GRN$BINARYNAME$NC..."

function is_installed {
  dpkg-query -Wf'${db:Status-abbrev}' "$1" 2>/dev/null | grep -q '^i'
}

# Install a package if it has not been
function install_pkg {
  # Tests if package name in first parameter is installed, installs it if it isn't, or reports that it is
  if is_installed "$1"; then
    prtrue "$1 is installed"
  else
    prstat "Installing $1..."
    sudo apt-get install -y $1 &>/dev/null
  fi
}

prstat "Checking for necessary prerequisites..."
install_pkg 'devscripts'
install_pkg 'debootstrap'
install_pkg 'pbuilder'

# Create work directory if it does not exist
if [[ ! -d $WORKROOT ]]; then
  prstat "Creating work directory $WORKROOT"
  mkdir -p $WORKROOT
fi

prstat "Entering $WORKROOT..."
cd $WORKROOT

# Check if base image has been created
if [[ ! -f $WORKROOT/.ubuntu14.tgz ]]; then
  # Clean up mess if previous attempt was interrupted
  if [ -f $WORKROOT/ubuntu14.tgz ]; then
    prfalse "Base image creation was interrupted, cleaning up"
    rm -f $WORKROOT/ubuntu14.tgz
  fi
  prstat "Creating Ubuntu 14.04 base image"
  sudo pbuilder --create \
    --distribution trusty \
    --architecture amd64 \
    --basetgz $WORKROOT/ubuntu14.tgz \
    --debootstrapopts \
    --variant=buildd &>/dev/null
  
  # Process complete, mark it complete
  touch $WORKROOT/.ubuntu14.tgz
  prtrue "Completed creating image"
else
  prtrue "Ubuntu 14.04 image was already created"
fi

# Check if base build image was created
if [[ ! -f $WORKROOT/ubuntu14/.complete ]]; then
  # Clean up mess if previous attempt was interrupted
  if [[ -d $WORKROOT/ubuntu14 ]]; then
    prfalse "Base image unpacking was interrupted, cleaning up"
    sudo rm -rf $WORKROOT/ubuntu14
  fi

  prstat "Unpacking base build image"
  mkdir $WORKROOT/ubuntu14
  cd $WORKROOT/ubuntu14
  sudo tar zxfp ../ubuntu14.tgz
  cd ..
  
  # Process complete, mark it complete
  touch $WORKROOT/ubuntu14/.complete
  prtrue "Ubuntu 14.04 base image unpacked successfully"
else
  # Process was already completed
  prtrue "Ubuntu 14.04 base image was already unpacked"
fi

# Check if Cmake was downloaded yet
if [[ ! -f $WORKROOT/.cmake ]]; then
  # Download was not completed, clean up
  if [[ -f $WORKROOT/cmake-3.2.2.tar.gz ]]; then
    # Delete intrerrupted download
    rm -f $WORKROOT/cmake-3.2.2.tar.gz
    prfalse "Removed incomplete download of Cmake 3.2.2"
  fi
  
  prstat "Downloading Cmake 3.2.2"
  cd $WORKROOT
  # Attempt to download Cmake 3.2.2 source tarball
  if wget http://www.cmake.org/files/v3.2/cmake-3.2.2.tar.gz &>/dev/null;  then 
    cp cmake-3.2.2.tar.gz $WORKROOT/ubuntu14/

    # Process complete, mark it complete
    touch $WORKROOT/.cmake
    prtrue "Cmake 3.2.2 was downloaded and copied into chroot"
  fi
else
  # Process was already completed
  prtrue "Cmake 3.2.2 was already installed and copied into chroot"
fi

# Check if AppImageKit was downloaded and copied into chroot
# and that the AppImage folder skeleton was copied over
if [[ ! -f $WORKROOT/.appimage ]]; then
  # Clean up mess if previous attempt was interrupted
  if [[ -f $WORKROOT/appimagetool-x86_64.AppImage ]]; then
    # remove previous incomplete download
    rm -f $WORKROOT/appimagetool-x86_64.AppImage
    prfalse "Removed incomplete download of AppImage tool"
  fi
  # Clean up previous AppImage skeleton copy if it was interrupted
  if [[ ! -d $WORKROOT/calibrd/calibrd.AppDir ]]; then
    # Remove previous incomplete folder
    rm -rf $WORKROOT/calibrd/calibrd.AppDir
    prtrue "Removed improperly copied AppDir skeleton"
  fi

  # Download AppImageKit
  cd $WORKROOT
  prstat "Downloading AppImageKit"
  wget -c "https://github.com/AppImage/AppImageKit/releases/download/continuous/appimagetool-x86_64.AppImage" &>/dev/null
  # Make file executable
  chmod a+x appimagetool-x86_64.AppImage
  # Copy into chroot
  cp appimagetool-x86_64.AppImage $WORKROOT/ubuntu14/

  # Copy AppDir skeleton into chroot
  prstat "Copying AppDir skeleton to chroot"
  cp -rf $WORKROOT/calibrd/calibrd.AppDir $WORKROOT/ubuntu14/

  # Process completed successfully, mark complete
  touch $WORKROOT/.appimage
  prtrue "Completed download of AppImageKit and copied with AppDir skeleton into chroot"
else
  # Process was already completed
  prtrue "AppImageKit already downloaded and copied into chroot"
fi

if [[ ! -f $WORKROOT/.boost ]]; then
fi

# Check if boost download was already done
if [ ! -f $WORKROOT/.boost ]; then
  # Remove incomplete download if it was started and not finished
  if [[ -f $WORKROOT/boost_1_60_0.tar.bz2 ]]; then
    # Delete incomplete download
    rm -f $WORKROOT/boost_1_60_0.tar.bz2
    prfalse "Removed incomplete download of Boost source"
  fi

  # Download Boost
  prstat "Downloading boost 1.60..."
  URL='http://sourceforge.net/projects/boost/files/boost/1.60.0/boost_1_60_0.tar.bz2/download'
  wget -c "$URL" -O $WORKROOT/boost_1_60_0.tar.bz2 &>/dev/null
  
  # Check that download was correct
  [ $( sha256sum boost_1_60_0.tar.bz2 | cut -d ' ' -f 1 ) == \
    "686affff989ac2488f79a97b9479efb9f2abae035b5ed4d8226de6857933fd3b" ] \
    || ( prfalse 'Corrupt download' ; exit 1 )

  # Copy source tarball into chroot
  cp $WORKROOT/boost_1_60_0.tar.bz2 $WORKROOT/ubuntu14/
  # Mark process complete
  touch $WORKROOT/.boost
  prtrue "Completed download of boost and placed into chroot"
else
  # Process was already completed
  prtrue "Already have Boost downloaded and moved into chroot"
fi 

# Check if clone of calibrd repository was completed
if [[ ! -d $WORKROOT/calibrd/.complete ]]; then
  # If cloning was interrupted, clean it out
  if [[ ! -f $WORKROOT/calibrd ]]; then
    prfalse "Cloning was interrupted, removing incomplete folder"
    rm -rf $WORKROOT/calibrd
  fi

  # Clone the calibrd repository
  prstat "Cloning $BINARYNAME Git repository..."
  git clone https://github.com/calibrae-project/calibrd.git &>/dev/null

  cd $WORKROOT/calibrd
  # Update submodules so repo is ready to build
  prstat "Updating submodules"
  git submodule update --init --recursive &>/dev/null

  # Copy repository into chroot
  cp -rfp $WORKROOT/calibrd $WORKROOT/ubuntu14/

  # Task is complete, does not need to be repeated
  touch $WORKROOT/calibrd/.complete
  prtrue "Completed cloning repository and copied into chroot"
else
  # Process was already completed
  prtrue "$BINARYNAME repository was already cloned and copied into chroot"
fi

# Bind mount system folders and mark that procedure was started (so it can be cleaned up)
prstat "Mounting system folders inside chroot"
MOUNTEDSYSFOLDERS="1"
sudo mount -o bind /dev $WORKROOT/ubuntu14/dev
sudo mount -o bind /dev/pts $WORKROOT/ubuntu14/dev/pts
sudo mount -o bind /sys $WORKROOT/ubuntu14/sys
sudo mount -o bind /proc $WORKROOT/ubuntu14/proc
sudo cp /etc/resolv.conf $WORKROOT/ubuntu14/etc/resolv.conf

# Copy chroot build script into chroot and run it
prstat "Starting chrooted build script"
sudo cp $WORKROOT/calibrd/buildcalibrd.sh $WORKROOT/ubuntu14/
sudo chroot $WORKROOT/ubuntu14 bash /buildcalibrd.sh

# TODO: Create AppImage
# prstat "Copying out completed steemd, which will run on any version of ubuntu from 14.04 to 17.04"
# cp $WORKROOT/ubuntu14/calibrd/build/programs/steemd/steemd $OUTPUTDIR/

cleanup
# The End