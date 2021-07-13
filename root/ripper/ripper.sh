#!/bin/bash

set -euo pipefail

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

# Startup Info
echo "$(date "+%d.%m.%Y %T") : Starting Ripper. Optical Discs will be detected and ripped within 60 seconds."

BAD_THRESHOLD=5
BAD_RESPONSE=0

# delete MakeMKV temp files
rm -rfv /tmp/*.tmp

# get disk info through makemkv and pass output to INFO
INFO="$(makemkvcon -r --cache=1 info disc:9999 | grep DRV:0)"

# Check for trouble and respond if found
EXPECTED="${EMPTY}${OPEN}${LOADING}${BD1}${BD2}${DVD}${CD1}${CD2}"
if [ "x$EXPECTED" == 'x' ]; then
 echo "$(date "+%d.%m.%Y %T") : Unexpected makemkvcon output: $INFO"
 let BAD_RESPONSE++
else
 BAD_RESPONSE=0
fi
if (( $BAD_RESPONSE >= $BAD_THRESHOLD )); then
 echo "$(date "+%d.%m.%Y %T") : Too many errors, ejecting disk and aborting"
 # Run makemkvcon once more with full output, to potentially aid in debugging
 makemkvcon -r --cache=1 info disc:9999
 eject $DRIVE || eject -s $DRIVE
 exit 1
fi

if [[ "${INFO}" = 'DRV:0,1,999,0,"*' ]]; then
 echo "$(date "+%d.%m.%Y %T") : Disk tray open"
fi
if [[ "${INFO}" = 'DRV:0,3,999,0,"*' ]]; then
 echo "$(date "+%d.%m.%Y %T") : Disc still loading"
fi

# Disklabel is in the same field for all disk types
QUOTED_DISKLABEL=$(echo "${INFO}" | cut -d, -f6)
QD_1="${QUOTED_DISKLABEL#\"}"
DISKLABEL="${QD_1%\"}"

if [[ "${INFO}" = 'DRV:0,2,999,12,"*' || "${INFO}" = 'DRV:0,2,999,28,"*' ]]; then
 BDPATH="${STORAGE_BD}/in_progress/${DISKLABEL}"
 BLURAYNUM=$(echo "${INFO}" | grep "${DRIVE}" | cut -c5)
 mkdir -p "$BDPATH"
 echo "$(date "+%d.%m.%Y %T") : BluRay detected: Saving MKV"
 makemkvcon --profile=/config/default.mmcp.xml -r --decrypt --minlength=600 --messages="${BDPATH}/makemkv.log" mkv disc:"$BLURAYNUM" all "$BDPATH"
 BDFINISH="${STORAGE_BD}/finished/${DISKLABEL}"
 mv_to_unique_dir "$BDPATH" "$BDFINISH"
 echo "$(date "+%d.%m.%Y %T") : Done! Ejecting Disk"
 eject $DRIVE || eject -s $DRIVE
 # permissions
 chown -R nobody:users "$STORAGE_BD" && chmod -R g+rw "$STORAGE_BD"
fi

if [[ "${INFO}" = 'DRV:0,2,999,1,"*' ]]; then
 DVDPATH="${STORAGE_DVD}/in_progress/${DISKLABEL}"
 DVDNUM=$(echo "${INFO}" | cut -c5)
 mkdir -p "$DVDPATH"
 echo "$(date "+%d.%m.%Y %T") : DVD detected: Saving MKV"
 makemkvcon --profile=/config/default.mmcp.xml -r --decrypt --minlength=600 --messages="${DVDPATH}/makemkv.log" mkv disc:"$DVDNUM" all "$DVDPATH"
 DVDFINISH="${STORAGE_DVD}/finished/${DISKLABEL}"
 mv_to_unique_dir "$DVDPATH" "$DVDFINISH"
 echo "$(date "+%d.%m.%Y %T") : Done! Ejecting Disk"
 eject $DRIVE || eject -s $DRIVE
 # permissions
 chown -R nobody:users "$STORAGE_DVD" && chmod -R g+rw "$STORAGE_DVD"
fi

if [[ "${INFO}" = 'DRV:0,2,999,0,"*' ]]; then
    if [[ "${INFO}" = '*","","'$DRIVE'"*' ]]; then
	echo "$(date "+%d.%m.%Y %T") : CD detected: Saving MP3 and FLAC"
	/usr/bin/abcde -d "$DRIVE" -c /ripper/abcde.conf -N -x -l
	echo "$(date "+%d.%m.%Y %T") : Done! Ejecting Disk"
	eject $DRIVE || eject -s $DRIVE
	# permissions
	chown -R nobody:users "$STORAGE_CD" && chmod -R g+rw "$STORAGE_CD"
    else
	ISOPATH="$STORAGE_DATA"/"$DISKLABEL"/"$DISKLABEL".iso
	mkdir -p "$STORAGE_DATA"/"$DISKLABEL"
	echo "$(date "+%d.%m.%Y %T") : Data-Disk detected: Saving ISO"
	ddrescue $DRIVE $ISOPATH 
	echo "$(date "+%d.%m.%Y %T") : Done! Ejecting Disk"
	eject $DRIVE || eject -s $DRIVE
	# permissions
	chown -R nobody:users "$STORAGE_DATA" && chmod -R g+rw "$STORAGE_DATA"
    fi
fi

