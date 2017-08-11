#!/bin/bash
echo "Installing prerequisite binary packages"
apt install -y \
  autoconf \
  g++ \
  git \
  libssl-dev \
  libtool \
  make \
  pkg-config \
  doxygen \
  libncurses5-dev \
  libreadline-dev \
  libbz2-dev \
  python-dev \
  perl \
  python3 \
  python3-jinja2 \
  wget \
  build-essential \
  automake \
  autotools-dev

echo "Building and installing Cmake 3"
tar xf /cmake-3.2.2.tar.gz
cd cmake-3.2.2
./configure
make -j$(nproc)
make install

echo "Building and installing Boost 1.60"
export BOOST_ROOT=$HOME/opt/boost_1_60_0
tar xjf /boost_1_60_0.tar.bz2
cd boost_1_60_0
./bootstrap.sh "--prefix=$BOOST_ROOT"
./b2 install

mkdir build && cd build

cd /calibrd
mkdir build
cd build

echo "Running Cmake autoconfiguration"
cmake -DCMAKE_BUILD_TYPE=Release ..

echo "building steemd (soon to be renamed calibrd)"
make -j$(nproc) steemd

bash -i
# echo "Building cli_wallet"
# make -j$(nproc) cli_wallet