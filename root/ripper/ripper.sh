#!/bin/bash

set -euo pipefail

# Inexplicably, eject doesn't work if PWD is not root
cd /

# Rename dir $1 to $2 by optionally appending a numerical suffix to $2
mv_to_unique_dir() {
    if [[ ! -e "${2}" ]]; then
	mv -v "${1}" "${2}"
	return $?
    fi
    num=$(ls -d "${2}"* | wc -l)
    inc=$((num + 1))
    mv -v "${1}" "${2}.${inc}"
    return $?
}

BAD_THRESHOLD=5
BAD_RESPONSE=0

# delete MakeMKV temp files
rm -rfv /tmp/*.tmp

# get disk info through makemkv and pass output to INFO
INFO="$(makemkvcon -r --cache=1 info disc:9999 | grep DRV:0)"

if [[ "${INFO}" = DRV:0,0,999,0,\"* ]]; then
    # Empty
    exit 0
fi
if [[ "${INFO}" = DRV:0,1,999,0,\"* ]]; then
 echo "Disk tray open"
 exit 0
fi
if [[ "${INFO}" = DRV:0,3,999,0,\"* ]]; then
 echo "Disc still loading"
 exit 0
fi

# Disklabel is in the same field for all disk types
QUOTED_DISKLABEL=$(echo "${INFO}" | cut -d, -f6)
QD_1="${QUOTED_DISKLABEL#\"}"
DISKLABEL="${QD_1%\"}"

if [[ "${INFO}" = DRV:0,2,999,12,\"* || "${INFO}" = DRV:0,2,999,28,\"* ]]; then
 BDPATH="${STORAGE_BD}/in_progress/${DISKLABEL}"
 BLURAYNUM=$(echo "${INFO}" | grep "${DRIVE}" | cut -c5)
 mkdir -p "$BDPATH"
 echo "BluRay detected: Saving MKV"
 makemkvcon --profile=/config/default.mmcp.xml -r --decrypt --minlength=600 --messages="${BDPATH}/makemkv.log" mkv disc:"$BLURAYNUM" all "$BDPATH"
 BDFINISH="${STORAGE_BD}/finished/${DISKLABEL}"
 mv_to_unique_dir "$BDPATH" "$BDFINISH"
 echo "Done! Ejecting Disk"
 eject -v $DRIVE
 # permissions
 chown -R nobody:users "$STORAGE_BD" && chmod -R g+rw "$STORAGE_BD"
 exit 0
fi

if [[ "${INFO}" = DRV:0,2,999,1,\"* ]]; then
 DVDPATH="${STORAGE_DVD}/in_progress/${DISKLABEL}"
 DVDNUM=$(echo "${INFO}" | cut -c5)
 mkdir -p "$DVDPATH"
 echo "DVD detected: Saving MKV"
 makemkvcon --profile=/config/default.mmcp.xml -r --decrypt --minlength=600 --messages="${DVDPATH}/makemkv.log" mkv disc:"$DVDNUM" all "$DVDPATH"
 DVDFINISH="${STORAGE_DVD}/finished/${DISKLABEL}"
 mv_to_unique_dir "$DVDPATH" "$DVDFINISH"
 echo "Done! Ejecting Disk"
 eject -v $DRIVE
 # permissions
 chown -R nobody:users "$STORAGE_DVD" && chmod -R g+rw "$STORAGE_DVD"
 exit 0
fi

if [[ "${INFO}" = DRV:0,2,999,0,\"* ]]; then
    if [[ "${INFO}" = '*","","'$DRIVE'"*' ]]; then
	echo "CD detected: Saving MP3 and FLAC"
	/usr/bin/abcde -d "$DRIVE" -c /ripper/abcde.conf -N -x -l
	echo "Done! Ejecting Disk"
	eject $DRIVE || eject -s $DRIVE
	# permissions
	chown -R nobody:users "$STORAGE_CD" && chmod -R g+rw "$STORAGE_CD"
    else
	ISOPATH="$STORAGE_DATA"/"$DISKLABEL"/"$DISKLABEL".iso
	mkdir -p "$STORAGE_DATA"/"$DISKLABEL"
	echo "Data-Disk detected: Saving ISO"
	ddrescue $DRIVE $ISOPATH 
	echo "Done! Ejecting Disk"
	eject -v $DRIVE
	# permissions
	chown -R nobody:users "$STORAGE_DATA" && chmod -R g+rw "$STORAGE_DATA"
    fi
    exit 0
fi

# If we got to here, nothing matched
echo "Disk not recognized; aborting"
# Run makemkvcon once more with full output, to potentially aid in debugging
makemkvcon -r --cache=1 info disc:9999
eject -v $DRIVE
exit 1

