#!/bin/bash

# Transcode files in the "finished" directory which don't appear in
# the "complete" directory using Don Melton's video-transcode
# (https://github.com/donmelton/video_transcoding). Files in the
# .../finished/ directories are converted and put in .../converted/.
# A "foo.mkv.done" file is created on successful completion so we
# don't try again.

source $(/usr/local/rvm/bin/rvm env --path)

find "${STORAGE_DVD}/finished/" -name '*.mkv' -print0 | \
    while IFS= read -r -d '' source; do 
    
    source_rel="${source#${STORAGE_DVD}/finished/}"
    out="${STORAGE_DVD}/converted/${source_rel}"

    if [ -e "${out}.done" ] ; then
	echo "${source_rel} already converted; skipping"
	continue
    fi
    
    mkdir -p "$(dirname """${out}""")"
    transcode-video -o "${out}" \
	--crop detect --fallback-crop minimal \
	--add-audio all \
	--burn-subtitle scan \
	"${source}" && touch "${out}.done"
done
