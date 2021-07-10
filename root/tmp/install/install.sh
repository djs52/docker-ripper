#!/bin/bash -x
#Install script for applications
#MakeMKV-RDP

#####################################
#   Install dependencies            #
#                                   #
#####################################

apt-get update -qq
buildDeps='
  autoconf
  automake
  autopoint
  build-essential
  cmake
  cmake-curses-gui
  cpanminus
  git
  libavcodec-dev
  libass-dev
  libbz2-dev
  libc6-dev
  libcurl4-gnutls-dev
  libexpat1-dev
  libfontconfig1-dev
  libfdk-aac-dev
  libfreetype6-dev
  libfribidi-dev
  libgl1-mesa-dev
  libharfbuzz-dev
  libjansson-dev
  libleptonica-dev
  liblzma-dev
  libmp3lame-dev
  libnuma-dev
  libogg-dev
  libopus-dev
  libsamplerate-dev
  libspeex-dev
  libssl-dev
  libtesseract-dev
  libtheora-dev
  libtool
  libtool-bin
  libvorbis-dev
  libvpx-dev
  libx264-dev
  libx265-dev
  libxml2-dev
  m4
  make
  meson
  mpv
  nasm
  ninja-build
  patch
  pkg-config
  qt5-default
  texinfo
  unzip
  wget
  yasm
  zlib1g-dev
'

apt-get install -qy --allow-unauthenticated --no-install-recommends ${buildDeps}

cpanm MP3::Tag
cpanm WebService::MusicBrainz


#####################################
#   Download sources and extract    #
#####################################

# Grab makemkv latest version
MAKEMKV_VERSION=$(curl --silent 'https://www.makemkv.com/forum/viewtopic.php?f=3&t=224' | grep MakeMKV.*for.Linux.is | head -n 1 | sed -e 's/.*MakeMKV //g' -e 's/ .*//g')
# https://github.com/donmelton/video_transcoding/releases
GEM_VERSION=0.25.3
# https://handbrake.fr/downloads.php
HANDBRAKE_VERSION=1.3.3

mkdir -p /tmp/sources
wget -O /tmp/sources/makemkv-bin.tar.gz http://www.makemkv.com/download/makemkv-bin-$MAKEMKV_VERSION.tar.gz
wget -O /tmp/sources/makemkv-oss.tar.gz http://www.makemkv.com/download/makemkv-oss-$MAKEMKV_VERSION.tar.gz
wget -O /tmp/sources/handbrake.tar.bz2 https://github.com/HandBrake/HandBrake/releases/download/${HANDBRAKE_VERSION}/HandBrake-${HANDBRAKE_VERSION}-source.tar.bz2

pushd /tmp/sources/
tar xvzf /tmp/sources/makemkv-bin.tar.gz
tar xvzf /tmp/sources/makemkv-oss.tar.gz
tar xvjf /tmp/sources/handbrake.tar.bz2
git clone https://github.com/mp4v2/mp4v2.git
popd

#####################################
#   Compile and install             #
#                                   #
#####################################

# mp4v2-utils
pushd /tmp/sources/mp4v2
autoreconf -i
./configure --prefix=/usr
make CXXFLAGS='-fpermissive'
make install
popd

# HandbrakeCLI
pushd /tmp/sources/HandBrake-$HANDBRAKE_VERSION
./configure --launch-jobs=$(nproc) --disable-gtk --launch --prefix=/usr
cd build
make install
popd

# Makemkv-oss
pushd /tmp/sources/makemkv-oss-$MAKEMKV_VERSION
PKG_CONFIG_PATH=/tmp/ffmpeg/lib/pkgconfig CFLAGS="-std=gnu++11" ./configure
make
make install
popd

# Makemkv-bin
pushd /tmp/sources/makemkv-bin-$MAKEMKV_VERSION
/bin/echo -e "yes" | make install
popd


#####################################
#       Remove unneeded packages    #
#                                   #
#####################################

apt-get purge -y --auto-remove $buildDeps
apt-get clean
rm -rf /var/lib/apt/lists/* /var/tmp/*

#####################################
#     Install video-transcoding     #
#                                   #
#####################################
gem install video_transcoding -v "$GEM_VERSION"


#####################################
#   Replace metadata for ffmpeg     #
#   so it works with Apple Music    #
#   and Quicktime                   #
#####################################
sed -i 's/author/artist/g' /usr/bin/ripit
sed -i 's/day/year/g' /usr/bin/ripit
