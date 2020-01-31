#!/usr/bin/ksh
######################################################################
# Copyright (c)  2007 by Oracle Corporation
# OSWatcher.sh
# This is the main OSW program. This program is started by running 
# startOSW.sh
######################################################################
# Modifications Section:
######################################################################
##     Date        File            Changes
######################################################################
##  04/18/2005                      Baseline version 1.2.1 
##				              
##  05/19/2005     OSWatcher.sh     Add -x option to iostat on linux 
##  V1.3.1                          Add code to write pwd to /tmp/osw.hb
##                                  for rac_ddt to find osw archive 
##                                  files
##                                 
##  V1.3.2         OSWatcher.sh     Remove -f flag from $TOP for HP Conf
##                                  section. Append -f flag to $TOP when
##                                  running the HP top cmd   
##
##  09/29/2006     OSWatcher.sh     Added $PLATFORM key and OSW version 
##  V2.0.0                          info to header of all files. This 
##                                  will enable parsing by PTA and 
##                                  OSWg  
##
##  10/03/2006     OSWg.jar         Fixed format problem for device names 
##  V2.0.1                          greater than 30 characters   
##                                  
##  10/06/2006     OSWg.jar         Fixed linux flag to detect linux
##  V2.0.2                          archive files. Fixed bug  with
##                                  empty lists causing exceptions
##                                  when graphing data on platforms
##                                  other than solaris   
##  07/24/2007     OSWatcher.sh     Added enhancements requested by
##  V2.1.0                          linux bde. These include using a
##                                  environment variable to control the
##                                  amount of ps data, changes to top
##                                  and iostat commands, change format
##                                  of filenames to yy.mm.dd, add 
##                                  optional flag to compress files.
##                                  Added -D flag for aix iostat  
##  07/24/2007     oswlnxtop.sh     Created new file for linux top
##  V2.1.0                          collection.
##  07/24/2007     oswlnxio.sh      Created new file for linux iostat
##  V2.1.0                          collection.   
##  07/24/2007     startOSW.sh      Added optional 3rd parameter to 
##  V2.1.0                          compress files           
##  11/26/2007     oswlnxtop.sh     Fixed bug with awk script. Bug caused 
##  V2.1.1                          no output on some linux platforms 
##  12/16/2008     OSWg.jar         Fixed problem reading aix
##  V2.1.2                          iostat files
######################################################################

typeset -i snapshotInterval=$1
typeset -i archiveInterval=$2
typeset -i zipfiles=0
typeset -i status=0
typeset -i ZERO=0
typeset -i PS_MULTIPLIER_COUNTER=0
zip=$3
lasthour="0"
PLATFORM=`/bin/uname`
hostn=`hostname`

######################################################################
# Loading input variables
######################################################################
test $1
if [ $? = 1 ]; then
    echo
    echo "Info...You did not enter a value for snapshotInterval."
    echo "Info...Using default value = 30"
    snapshotInterval=30   
fi 
test $2
if [ $? = 1 ]; then
    echo "Info...You did not enter a value for archiveInterval."
    echo "Info...Using default value = 48"
    archiveInterval=48
fi  
test $3
if [ $? != 1 ]; then
       echo "Info...Zip option IS specified. " 
       echo "Info...OSW will use "$zip" to compress files."
       zipfiles=1
fi      


######################################################################
# Now check to see if snapshotInterval and archiveInterval are valid
######################################################################
test $snapshotInterval
if [ snapshotInterval -lt 1 ]; then
    echo "Warning...Invalid value for snapshotInterval. Overriding with default value = 30"
    snapshotInterval=30     
fi
test $archiveInterval 
if [ archiveInterval -lt 1 ]; then
    echo "Warning...Invalid value for archiveInterval . Overriding with default value = 48"
    archiveInterval=48      
fi  

######################################################################
# Now check to see if unix environment variable
# OSW_PS_SAMPLE_MULTIPLIER has been set
######################################################################
PS_MULTIPLIER=`env | grep OSW_PS_SAMPLE_MULTIPLIER | wc -c`
if [ $PS_MULTIPLIER = $ZERO ];
then
  OSW_PS_SAMPLE_MULTIPLIER=0 
fi

######################################################################
# Create log subdirectories if they don't exist
######################################################################
if [ ! -d archive ]; then
        mkdir archive
fi        
if [ ! -d archive/oswps ]; then
        mkdir -p archive/oswps
fi        
if [ ! -d archive/oswtop ]; then
        mkdir -p archive/oswtop
fi       
if [ ! -d archive/oswnetstat ]; then
        mkdir -p archive/oswnetstat
fi  
if [ ! -d archive/oswiostat ]; then
        mkdir -p archive/oswiostat
fi
if [ ! -d archive/oswvmstat ]; then
        mkdir -p archive/oswvmstat
fi 
if [ ! -d archive/oswmpstat ]; then
        mkdir -p archive/oswmpstat
fi  
if [ ! -d archive/oswprvtnet ]; then
        mkdir -p archive/oswprvtnet
fi  

######################################################################
# Create additional linux subdirectories if they don't exist
######################################################################
case $PLATFORM in
  Linux)
    mkdir -p archive/oswmeminfo
    mkdir -p archive/oswslabinfo
  ;;
esac   

######################################################################
# Remove lock.file if it exists 
######################################################################
if [ -f lock.file ]; then
  rm lock.file
fi

######################################################################
# CONFIGURATION  Determine Host Platform
######################################################################
case $PLATFORM in
  Linux)
######################################################################
#   The parameters for linux iostat are now configured in file 
#   oswlnxxio.sh and supercede the following value for iostat
######################################################################
    IOSTAT='iostat -x 1 3'
    VMSTAT='vmstat 1 3'
######################################################################
#   The parameters for linux top are now configured in file 
#   oswlnxxtop.sh and supercede the following value for top
######################################################################
    TOP='eval top -b -n 1 | head -50'
    PSELF='ps -elf'
    MPSTAT='mpstat 1 3'
    MEMINFO='cat /proc/meminfo'
    SLABINFO='cat /proc/slabinfo'
    ;;
  HP-UX|HI-UX)
    IOSTAT='iostat 1 3'
    VMSTAT='vmstat 1 3'
    TOP='top -d 1'
    PSELF='ps -elf'
    MPSTAT='sar -A -S 1 3'  
    ;;
  SunOS)
    IOSTAT='iostat -xn 1 3'
    VMSTAT='vmstat 1 3 '
    TOP='top -d1'
    PSELF='ps -elf'
    MPSTAT='mpstat 1 3'    
    ;;
  AIX)
    IOSTAT='iostat -D 1 3'
    VMSTAT='vmstat 1 3'
    TOP='top -Count 1'
    PSELF='ps -elf'
    MPSTAT='mpstat 1 3'  
    ;;
  OSF1)
    IOSTAT='iostat 1 3'
    VMSTAT='vmstat 1 3'
    TOP='top -d1'
    PSELF='ps -elf'
    MPSTAT='sar -S'  
    ;;
esac

######################################################################
# Test for discovery of os utilities. Notify if not found.
######################################################################
echo ""
echo "Testing for discovery of OS Utilities..."
echo ""

$VMSTAT > /dev/null 2>&1
if [ $? = 0 ]; then
  echo "VMSTAT found on your system."
  VMFOUND=1
else
  echo "Warning... VMSTAT not found on your system. No VMSTAT data will be collected."
  VMFOUND=0
fi

$IOSTAT > /dev/null 2>&1
if [ $? = 0 ]; then
  echo "IOSTAT found on your system."
  IOFOUND=1
else
  echo "Warning... IOSTAT not found on your system. No IOSTAT data will be collected."
  IOFOUND=0
fi

$MPSTAT > /dev/null 2>&1
if [ $? = 0 ]; then
  echo "MPSTAT found on your system."
  MPFOUND=1
else
  echo "Warning... MPSTAT not found on your system. No MPSTAT data will be collected."
  MPFOUND=0
fi

netstat > /dev/null 2>&1
if [ $? = 0 ]; then
  echo "NETSTAT found on your system."
  NETFOUND=1
else
  echo "Warning... NETSTAT not found on your system. No NETSTAT data will be collected."
  NETFOUND=0
fi

case $PLATFORM in
  AIX)
    TOPFOUND=1
    ;;
  *)  
    $TOP > /dev/null 2>&1
    if [ $? = 0 ]; then
      echo "TOP found on your system."
      TOPFOUND=1
    else
     echo "Warning... TOP not found on your system. No TOP data will be collected."
     TOPFOUND=0
    fi
    ;;  
esac

case $PLATFORM in
  Linux)
    $MEMINFO > /dev/null 2>&1
    if [ $? = 0 ]; then
      MEMFOUND=1
    else
      echo "Warning... /proc/meminfo not found on your system."
      MEMFOUND=0
    fi
    $SLABINFO > /dev/null 2>&1
    if [ $? = 0 ]; then
      SLABFOUND=1
    else
      echo "Warning... /proc/slabinfo not found on your system."
      SLABFOUND=0
    fi
  ;;
esac 

echo ""
echo "Discovery completed."
echo ""
echo "Starting OSWatcher V2.1.2  on "`date` 
echo "With SnapshotInterval = "$snapshotInterval
echo "With ArchiveInterval = "$archiveInterval 
echo ""
echo "OSWatcher - Written by Carl Davis, Center of Expertise, Oracle Corporation"
echo ""
echo "Starting Data Collection..."
echo ""

######################################################################
# Start OSWFM the File Manager Process
######################################################################
./OSWatcherFM.sh $archiveInterval &
######################################################################
# Loop Forever
######################################################################

until test 0 -eq 1
do

echo "osw heartbeat:"`date` 
pwd > /tmp/osw.hb

######################################################################
# Generate generic log file string depending on what hour of the day   
# it is. Have 1 report per hour per operation.
######################################################################
#hour=`date +'%m.%d.%y.%H00.dat'`
hour=`date +'%y.%m.%d.%H00.dat'`

######################################################################
# VMSTAT
######################################################################
if [ $VMFOUND = 1 ]; then
  if [ $hour != $lasthour ]; then
    echo $PLATFORM "   OSW v2.1.2    "$hostn >> archive/oswvmstat/${hostn}_vmstat_$hour
    if [ $zipfiles = 1 ]; then
      if [ -f  archive/oswvmstat/${hostn}_vmstat_$lasthour ]; then
       $zip archive/oswvmstat/${hostn}_vmstat_$lasthour &
       fi
    fi
  fi
./oswsub.sh archive/oswvmstat/${hostn}_vmstat_$hour "$VMSTAT" &
fi

######################################################################
# MPSTAT
######################################################################
if [ $MPFOUND = 1 ]; then
  if [ $hour != $lasthour ]; then
    echo $PLATFORM "   OSW v2.1.2" >> archive/oswmpstat/${hostn}_mpstat_$hour
    if [ $zipfiles = 1 ]; then
      if [ -f  archive/oswmpstat/${hostn}_mpstat_$lasthour ]; then
        $zip archive/oswmpstat/${hostn}_mpstat_$lasthour &
      fi 
    fi    
  fi
./oswsub.sh archive/oswmpstat/${hostn}_mpstat_$hour "$MPSTAT" & 
fi

######################################################################
# NETSTAT
# NETSTAT configured in oswnet.sh file
######################################################################
if [ $NETFOUND = 1 ]; then
  if [ $hour != $lasthour ]; then
    echo $PLATFORM "   OSW v2.1.2" >> archive/oswnetstat/${hostn}_netstat_$hour
    if [ $zipfiles = 1 ]; then
      if [ -f  archive/oswnetstat/${hostn}_netstat_$lasthour ]; then
        $zip archive/oswnetstat/${hostn}_netstat_$lasthour &
      fi  
    fi     
  fi
./oswnet.sh archive/oswnetstat/${hostn}_netstat_$hour &
fi

######################################################################
# IOSTAT
######################################################################
if [ $IOFOUND = 1 ]; then
  if [ $hour != $lasthour ]; then
    echo $PLATFORM "   OSW v2.1.2" >> archive/oswiostat/${hostn}_iostat_$hour 
    if [ $zipfiles = 1 ]; then
      if [ -f  archive/oswiostat/${hostn}_iostat_$lasthour ]; then
        $zip archive/oswiostat/${hostn}_iostat_$lasthour &
      fi 
    fi      

  fi
  case $PLATFORM in
      Linux)
        ./oswlnxio.sh archive/oswiostat/${hostn}_iostat_$hour &
      ;;
      *)
        ./oswsub.sh archive/oswiostat/${hostn}_iostat_$hour "$IOSTAT" &
      ;;
  esac    
fi

######################################################################
# TOP
######################################################################
if [ $TOPFOUND = 1 ]; then

  if [ $hour != $lasthour ]; then
    echo $PLATFORM "   OSW v2.1.2" >> archive/oswtop/${hostn}_top_$hour
    if [ $zipfiles = 1 ]; then
      if [ -f  archive/oswtop/${hostn}_top_$lasthour ]; then    
        $zip archive/oswtop/${hostn}_top_$lasthour &
      fi 
    fi    
  fi
  case $PLATFORM in
    Linux)
      ./oswlnxtop.sh archive/oswtop/${hostn}_top_$hour &
    ;;
    HP-UX|HI-UX) 
      $TOP -f archive/oswtop/${hostn}_top_$hour &  
    ;; 
    AIX)
      ./topaix.sh archive/oswtop/${hostn}_top_$hour
    ;;
    *)
      ./oswsub.sh archive/oswtop/${hostn}_top_$hour "$TOP" &
    ;;
  esac 
fi


######################################################################
# PS -ELF
######################################################################
  if [ $hour != $lasthour ]; then
    echo $PLATFORM "   OSW v2.1.2" >> archive/oswps/${hostn}_ps_$hour
    if [ $zipfiles = 1 ]; then
      if [ -f  archive/oswps/${hostn}_ps_$lasthour ]; then
        $zip archive/oswps/${hostn}_ps_$lasthour &
      fi 
    fi    
  fi
  if [ $OSW_PS_SAMPLE_MULTIPLIER -gt $ZERO ]; then
    let PS_MULTIPLIER_COUNTER=PS_MULTIPLIER_COUNTER+1

    if [ $PS_MULTIPLIER_COUNTER -eq $OSW_PS_SAMPLE_MULTIPLIER ]; then
        ./oswsub.sh archive/oswps/${hostn}_ps_$hour "$PSELF" &
        PS_MULTIPLIER_COUNTER=0
    fi
  else
    ./oswsub.sh archive/oswps/${hostn}_ps_$hour "$PSELF" &
  fi

######################################################################
# Additional Linux Only Collection
######################################################################
case $PLATFORM in
  Linux)
  if [ $MEMFOUND = 1 ]; then
    ./oswsub.sh archive/oswmeminfo/${hostn}_meminfo_$hour "$MEMINFO" & 
  fi  
  if [ $SLABFOUND = 1 ]; then
    ./oswsub.sh archive/oswslabinfo/${hostn}_slabinfo_$hour "$SLABINFO" & 
  fi  

  if [ $hour != $lasthour ]; then
    if [ $zipfiles = 1 ]; then
      if [ -f archive/oswmeminfo/${hostn}_meminfo_$lasthour  ]; then
        $zip archive/oswmeminfo/${hostn}_meminfo_$lasthour &
      fi 
      if [ -f archive/oswslabinfo/${hostn}_slabinfo_$lasthour  ]; then
        $zip archive/oswslabinfo/${hostn}_slabinfo_$lasthour &
      fi 
    fi    
  fi
  ;;
esac 

######################################################################
# Run traceroute for private networks in file private.net exists
######################################################################
if [ -x private.net ]; then
  if [ -f lock.file ]; then
    status=1
  else
    touch lock.file
    if [ $status = 1 ]; then
      echo "zzz ***Warning. Traceroute response is spanning snapshot intervals." >> archive/oswprvtnet/${hostn}_prvtnet_$hour & 
      status=0
    fi    
   ./private.net >> archive/oswprvtnet/${hostn}_prvtnet_$hour 2>&1 &
  fi 
  if [ $hour != $lasthour ]; then
    if [ $zipfiles = 1 ]; then
      if [ -f archive/oswprvtnet/${hostn}_prvtnet_$lasthour  ]; then
        $zip archive/oswprvtnet/${hostn}_prvtnet_$lasthour &
      fi 
    fi    
  fi
fi

######################################################################
# Sleep for specified interval and repeat
######################################################################

lasthour=$hour
sleep $snapshotInterval
done


 
