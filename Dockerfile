FROM phusion/passenger-ruby27:1.0.12
MAINTAINER djs52

# Set correct environment variables
ENV HOME /root
ENV DEBIAN_FRONTEND noninteractive
ENV LC_ALL C.UTF-8
ENV LANG en_US.UTF-8
ENV LANGUAGE en_US.UTF-8
# https://github.com/donmelton/video_transcoding/releases
ENV GEM_VERSION=0.25.3
# https://handbrake.fr/downloads.php
ENV HANDBRAKE_VERSION=1.3.3
# https://ffmpeg.org/download.html#releases
ENV FFMPEG_VERSION=4.3.1
# https://bitbucket.org/multicoreware/x265_git
ENV LIBX265_VERSION=3.3

# Use baseimage-docker's init system
CMD ["/sbin/my_init"]

# Configure user nobody to match unRAID's settings
 RUN \
 usermod -u 99 nobody && \
 usermod -g 100 nobody && \
 usermod -d /home nobody && \
 chown -R nobody:users /home

# Move Files
COPY root/ /
RUN chmod +x /etc/my_init.d/*.sh

# Install software
RUN apt-get update \
 && apt-get -y --allow-unauthenticated install --no-install-recommends gddrescue wget eject lame curl default-jre cpanminus make \
 build-essential pkgconf cmake automake autoconf git gcc tesseract-ocr libtesseract-dev libleptonica-dev libcurl4-gnutls-dev

# Install ripit beta that uses gnudb instead of freedb (to detect disks)
RUN wget http://ftp.br.debian.org/debian/pool/main/r/ripit/ripit_4.0.0~rc20161009-1_all.deb -O /tmp/install/ripit_4.0.0~rc20161009-1_all.deb \
 && apt install -y --allow-unauthenticated /tmp/install/ripit_4.0.0~rc20161009-1_all.deb \
 && rm /tmp/install/ripit_4.0.0~rc20161009-1_all.deb
 
# Install & update perl modules
RUN cpanm MP3::Tag \
 && cpanm WebService::MusicBrainz


# Install ccextractor
RUN git clone https://github.com/CCExtractor/ccextractor.git && \
    cd ccextractor/linux && \
    ./autogen.sh && \
    ./configure --enable-ocr && \
    make && \
    make install

 # Disable SSH
RUN rm -rf /etc/service/sshd /etc/my_init.d/00_regen_ssh_host_keys.sh

# Skip cache for the following install script (output is random invalidating docker cache for the next steps)
ADD "https://www.random.org/cgi-bin/randbyte?nbytes=10&format=h" skipcache
 
# MakeMKV/FFMPEG setup by github.com/tobbenb
RUN chmod +x /tmp/install/install.sh && sleep 1 && \
    /tmp/install/install.sh

# install build dependencies to compile ffmpeg from master
RUN set -ex \
  && buildDeps=' \
    autoconf \
    automake \
    autopoint \
    build-essential \
    cmake \
    cmake-curses-gui \
    curl \
    git \
    libass-dev \
    libbz2-dev \
    libfontconfig1-dev \
    libfreetype6-dev \
    libfribidi-dev \
    libharfbuzz-dev \
    libjansson-dev \
    liblzma-dev \
    libmp3lame-dev \
    libnuma-dev \
    libogg-dev \
    libopus-dev \
    libsamplerate-dev \
    libspeex-dev \
    libtheora-dev \
    libtool \
    libtool-bin \
    libvorbis-dev \
    libvpx-dev \
    libx264-dev \
    libxml2-dev \
    m4 \
    make \
    mercurial \
    meson \
    mkvtoolnix \
    mpv \
    nasm \
    ninja-build \
    patch \
    pkg-config \
    python \
    ruby-full \
    tar \
    texinfo \
    unzip \
    wget \
    yasm \
    zlib1g-dev \
  ' \
  && apt-get update \
  && apt-get install -y --no-install-recommends $buildDeps \
  && mkdir -p /usr/src/ffmpeg/bin \
  && mkdir -p /usr/src/ffmpeg/build \
  && PATH="/usr/src/ffmpeg/bin:$PATH" \
  && cd /usr/src/ffmpeg \
  # mp4v2-utils
  && git clone https://github.com/mp4v2/mp4v2.git \
  && cd mp4v2 \
  && autoreconf -i && ./configure \
  && make CXXFLAGS='-fpermissive' && make install \
  # libx265
  && wget -O x265.tar.gz https://bitbucket.org/multicoreware/x265_git/downloads/x265_$LIBX265_VERSION.tar.gz \
  && tar xzvf x265.tar.gz \
  && cd x265_$LIBX265_VERSION/build/linux \
  && PATH="/usr/src/ffmpeg/bin:$PATH" cmake -G "Unix Makefiles" -DCMAKE_INSTALL_PREFIX="/usr/src/ffmpeg/build" -DENABLE_SHARED:bool=off ../../source \
  && PATH="/usr/src/ffmpeg/bin:$PATH" make -j"$(nproc)" \
  && make install \
  && cd /usr/src/ffmpeg \
  && rm -rf x265 \
  # HandbrakeCli Release
  && wget https://github.com/HandBrake/HandBrake/releases/download/${HANDBRAKE_VERSION}/HandBrake-${HANDBRAKE_VERSION}-source.tar.bz2 \
  && tar xvjf HandBrake-$HANDBRAKE_VERSION-source.tar.bz2 \
  && cd HandBrake-$HANDBRAKE_VERSION \
  && ./configure --launch-jobs=$(nproc) --disable-gtk --launch \
  && cd build && make install \
  && cd /usr/src/ffmpeg \
  && rm -rf HandBrake-$HANDBRAKE_VERSION HandBrake-$HANDBRAKE_VERSION-source.tar.bz2 \
  # FFmpeg
  && wget -O ffmpeg.tar.gz https://github.com/FFmpeg/FFmpeg/archive/n$FFMPEG_VERSION.tar.gz \
  && tar zxvf ffmpeg.tar.gz \
  && mv FFmpeg* ffmpeg_src \
  && cd ffmpeg_src \
  && PATH="/usr/src/ffmpeg/bin:$PATH" PKG_CONFIG_PATH="/usr/src/ffmpeg/build/lib/pkgconfig" ./configure \
    --prefix="/usr/src/ffmpeg/build" \
    --pkg-config-flags="--static" \
    --extra-cflags="-I/usr/src/ffmpeg/build/include" \
    --extra-ldflags="-L/usr/src/ffmpeg/build/lib" \
    --bindir="/usr/src/ffmpeg/bin" \
    --extra-libs=-lpthread \
    --enable-gpl \
    --enable-libass \
    --enable-libfreetype \
    --enable-libmp3lame \
    --enable-libopus \
    --enable-libtheora \
    --enable-libvorbis \
    --enable-libvpx \
    --enable-libx264 \
    --enable-libx265 \
    --enable-nonfree \
  && PATH="/usr/src/ffmpeg/bin:$PATH" make -j"$(nproc)" \
  && make install \
  && hash -r \
  && cd / \
  && mv /usr/src/ffmpeg/bin/ff* /usr/local/bin \
  && rm -rf /usr/src/ffmpeg \
  && apt-get clean \
  && rm -rf \
    /tmp/* \
    /var/lib/apt/lists/* \
    /var/tmp/*

RUN set -ex \
  # Install application dependencies
  && apt-get purge -y --auto-remove $buildDeps \
  && rm -rf /var/lib/apt/lists/* \
  && gem install video_transcoding -v "$GEM_VERSION" \
  && mkdir /data

# Clean up temp files
RUN rm -rf \
    	/tmp/* \
    	/var/lib/apt/lists/* \
    	/var/tmp/*
