FROM phusion/passenger-ruby27:1.0.12
MAINTAINER djs52

# Set correct environment variables
ENV HOME /root
ENV DEBIAN_FRONTEND noninteractive
ENV LC_ALL C.UTF-8
ENV LANG en_US.UTF-8
ENV LANGUAGE en_US.UTF-8

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
RUN chmod 1777 /tmp/

# Install required packages
RUN apt-get update \
 && apt-get -y --allow-unauthenticated install --no-install-recommends \
 gddrescue eject lame curl tesseract-ocr ripit mkvtoolnix ffmpeg libjansson4 ccextractor \
 abcde eyed3 flac lame mkcue speex vorbis-tools vorbisgain id3 id3v2 wget

# Skip cache for the following install script (output is random invalidating docker cache for the next steps)
ADD "https://www.random.org/cgi-bin/randbyte?nbytes=10&format=h" skipcache
 
# Set up MakeMKV, HandbrakeCLI, video-transcode, and others
RUN chmod +x /tmp/install/install.sh && /tmp/install/install.sh

# Clean up temp files
RUN rm -rf \
    	/tmp/* \
    	/var/lib/apt/lists/* \
    	/var/tmp/*
