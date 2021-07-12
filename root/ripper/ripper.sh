#!/bin/bash

set -eo pipefail

RIPPER_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"

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
let BAD_RESPONSE=0

# delete MakeMKV temp files
cwd=$(pwd)
cd /tmp
rm -r *.tmp > /dev/null 2>&1
cd $cwd

# get disk info through makemkv and pass output to INFO
INFO=$"`makemkvcon -r --cache=1 info disc:9999 | grep DRV:0`"
# check INFO for optical disk
EMPTY=`echo $INFO | grep -o 'DRV:0,0,999,0,"'`
OPEN=`echo $INFO | grep -o 'DRV:0,1,999,0,"'`
LOADING=`echo $INFO | grep -o 'DRV:0,3,999,0,"'`
BD1=`echo $INFO | grep -o 'DRV:0,2,999,12,"'`
BD2=`echo $INFO | grep -o 'DRV:0,2,999,28,"'`
DVD=`echo $INFO | grep -o 'DRV:0,2,999,1,"'`
CD1=`echo $INFO | grep -o 'DRV:0,2,999,0,"'`
CD2=`echo $INFO | grep -o '","","'$DRIVE'"'`

# Check for trouble and respond if found
EXPECTED="${EMPTY}${OPEN}${LOADING}${BD1}${BD2}${DVD}${CD1}${CD2}"
if [ "x$EXPECTED" == 'x' ]; then
 echo "$(date "+%d.%m.%Y %T") : Unexpected makemkvcon output: $INFO"
 let BAD_RESPONSE++
else
 let BAD_RESPONSE=0
fi
if (( $BAD_RESPONSE >= $BAD_THRESHOLD )); then
 echo "$(date "+%d.%m.%Y %T") : Too many errors, ejecting disk and aborting"
 # Run makemkvcon once more with full output, to potentially aid in debugging
 makemkvcon -r --cache=1 info disc:9999
 eject $DRIVE || eject -s $DRIVE
 exit 1
fi

# if [ $EMPTY = 'DRV:0,0,999,0,"' ]; then
#  echo "$(date "+%d.%m.%Y %T") : No Disc"; &>/dev/null
# fi
if [ "$OPEN" = 'DRV:0,1,999,0,"' ]; then
 echo "$(date "+%d.%m.%Y %T") : Disk tray open"
fi
if [ "$LOADING" = 'DRV:0,3,999,0,"' ]; then
 echo "$(date "+%d.%m.%Y %T") : Disc still loading"
fi

if [ "$BD1" = 'DRV:0,2,999,12,"' ] || [ "$BD2" = 'DRV:0,2,999,28,"' ]; then
 DISKLABEL=`echo $INFO | grep -o -P '(?<=",").*(?=",")'`
 BDPATH="${STORAGE_BD}/in_progress/${DISKLABEL}"
 BLURAYNUM=`echo $INFO | grep $DRIVE | cut -c5`
 mkdir -p "$BDPATH"
 ALT_RIP="${RIPPER_DIR}/BLURAYrip.sh"
 if [[ -f $ALT_RIP && -x $ALT_RIP ]]; then
    echo "$(date "+%d.%m.%Y %T") : BluRay detected: Executing $ALT_RIP"
    $ALT_RIP "$BLURAYNUM" "$BDPATH"
 else
    # BluRay/MKV
    echo "$(date "+%d.%m.%Y %T") : BluRay detected: Saving MKV"
    makemkvcon --profile=/config/default.mmcp.xml -r --decrypt --minlength=600 --messages="${BDPATH}/makemkv.log" mkv disc:"$BLURAYNUM" all "$BDPATH"
 fi
 BDFINISH="${STORAGE_BD}/finished/${DISKLABEL}"
 mv_to_unique_dir "$BDPATH" "$BDFINISH"
 echo "$(date "+%d.%m.%Y %T") : Done! Ejecting Disk"
 eject $DRIVE || eject -s $DRIVE
 # permissions
 chown -R nobody:users "$STORAGE_BD" && chmod -R g+rw "$STORAGE_BD"
fi

if [ "$DVD" = 'DRV:0,2,999,1,"' ]; then
 DISKLABEL=`echo $INFO | grep -o -P '(?<=",").*(?=",")'` 
 DVDPATH="${STORAGE_DVD}/in_progress/${DISKLABEL}"
 DVDNUM=`echo $INFO | grep $DRIVE | cut -c5`
 mkdir -p "$DVDPATH"
 ALT_RIP="${RIPPER_DIR}/DVDrip.sh"
 if [[ -f $ALT_RIP && -x $ALT_RIP ]]; then
    echo "$(date "+%d.%m.%Y %T") : DVD detected: Executing $ALT_RIP"
    $ALT_RIP "$DVDNUM" "$DVDPATH"
 else
    # DVD/MKV
    echo "$(date "+%d.%m.%Y %T") : DVD detected: Saving MKV"
    makemkvcon --profile=/config/default.mmcp.xml -r --decrypt --minlength=600 --messages="${DVDPATH}/makemkv.log" mkv disc:"$DVDNUM" all "$DVDPATH"
 fi
 DVDFINISH="${STORAGE_DVD}/finished/${DISKLABEL}"
 mv_to_unique_dir "$DVDPATH" "$DVDFINISH"
 echo "$(date "+%d.%m.%Y %T") : Done! Ejecting Disk"
 eject $DRIVE || eject -s $DRIVE
 # permissions
 chown -R nobody:users "$STORAGE_DVD" && chmod -R g+rw "$STORAGE_DVD"
fi

if [ "$CD1" = 'DRV:0,2,999,0,"' ]; then
 if [ "$CD2" = '","","'$DRIVE'"' ]; then
  ALT_RIP="${RIPPER_DIR}/CDrip.sh"
  if [[ -f $ALT_RIP && -x $ALT_RIP ]]; then
     echo "$(date "+%d.%m.%Y %T") : CD detected: Executing $ALT_RIP"
     $ALT_RIP "$DRIVE" "$STORAGE_CD"
  else
     # MP3 & FLAC
     echo "$(date "+%d.%m.%Y %T") : CD detected: Saving MP3 and FLAC"
     /usr/bin/abcde -d "$DRIVE" -c /ripper/abcde.conf -N -x -l
  fi
  echo "$(date "+%d.%m.%Y %T") : Done! Ejecting Disk"
  eject $DRIVE || eject -s $DRIVE
  # permissions
  chown -R nobody:users "$STORAGE_CD" && chmod -R g+rw "$STORAGE_CD"
 else
  DISKLABEL=`echo $INFO | grep $DRIVE | grep -o -P '(?<=",").*(?=",")'`  
  ISOPATH="$STORAGE_DATA"/"$DISKLABEL"/"$DISKLABEL".iso
  mkdir -p "$STORAGE_DATA"/"$DISKLABEL"
  ALT_RIP="${RIPPER_DIR}/DATArip.sh"
  if [[ -f $ALT_RIP && -x $ALT_RIP ]]; then
     echo "$(date "+%d.%m.%Y %T") : Data-Disk detected: Executing $ALT_RIP"
     $ALT_RIP "$DRIVE" "$ISOPATH"
  else
     # ISO
     echo "$(date "+%d.%m.%Y %T") : Data-Disk detected: Saving ISO"
     ddrescue $DRIVE $ISOPATH 
  fi
  echo "$(date "+%d.%m.%Y %T") : Done! Ejecting Disk"
  eject $DRIVE || eject -s $DRIVE
  # permissions
  chown -R nobody:users "$STORAGE_DATA" && chmod -R g+rw "$STORAGE_DATA"
 fi
fi
