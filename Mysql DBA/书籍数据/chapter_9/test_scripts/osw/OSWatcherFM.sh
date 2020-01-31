#!/usr/bin/ksh
######################################################################
# OSWatcherFM.sh
# This is the file manager program called by OSWatcher.sh. This program
# wakes up once a minute to look to see if the hour has changed. If we
# are starting a new hour we look to see how many files we have in
# archive and remove any that are greated than what was specified by
# $1 archiveInterval
######################################################################
# Check each log subdirectory so that only the last archiveInterval number
# of hours of data are kept
######################################################################
#echo "Starting File Manager Process"
PLATFORM=`/bin/uname`
typeset -i archiveInterval=$1
typeset -i numberToDelete=0
archiveInterval=archiveInterval+1
check=0
######################################################################
# Loop indefinitely until killed by stopOSW
######################################################################
until [ check -eq 1 ]
do
######################################################################
# Wake up every 60 seconds to see if hour rollover has occured
######################################################################
sleep 60

######################################################################
# VMSTAT
######################################################################
numberOfFiles=`ls -t archive/oswvmstat | wc -l`
numberToDelete=$numberOfFiles-$archiveInterval
if [ $numberOfFiles -gt $archiveInterval ]
  then
    ls -t archive/oswvmstat/* | tail -$numberToDelete | xargs rm
fi
######################################################################
# MPSTAT
######################################################################
numberOfFiles=`ls -t archive/oswmpstat | wc -l`
numberToDelete=$numberOfFiles-$archiveInterval
if [ $numberOfFiles -gt $archiveInterval ]
  then
    ls -t archive/oswmpstat/* | tail -$numberToDelete | xargs rm
fi
######################################################################
# NETSTAT
######################################################################
numberOfFiles=`ls -t archive/oswnetstat | wc -l`
numberToDelete=$numberOfFiles-$archiveInterval
if [ $numberOfFiles -gt $archiveInterval ]
  then
    ls -t archive/oswnetstat/* | tail -$numberToDelete | xargs rm
fi
######################################################################
# IOSTAT
######################################################################
numberOfFiles=`ls -t archive/oswiostat | wc -l`
numberToDelete=$numberOfFiles-$archiveInterval
if [ $numberOfFiles -gt $archiveInterval ]
  then
    ls -t archive/oswiostat/* | tail -$numberToDelete | xargs rm
fi
######################################################################
# TOP
######################################################################
numberOfFiles=`ls -t archive/oswtop | wc -l`
numberToDelete=$numberOfFiles-$archiveInterval
if [ $numberOfFiles -gt $archiveInterval ]
  then
    ls -t archive/oswtop/* | tail -$numberToDelete | xargs rm
fi
######################################################################
# PS -ELF
######################################################################
numberOfFiles=`ls -t archive/oswps | wc -l`
numberToDelete=$numberOfFiles-$archiveInterval
if [ $numberOfFiles -gt $archiveInterval ]
  then
    ls -t archive/oswps/* | tail -$numberToDelete | xargs rm
fi
######################################################################
# Private Networks
######################################################################
numberOfFiles=`ls -t archive/oswprvtnet | wc -l`
numberToDelete=$numberOfFiles-$archiveInterval
if [ $numberOfFiles -gt $archiveInterval ]
  then
    ls -t archive/oswprvtnet/* | tail -$numberToDelete | xargs rm
fi
######################################################################
# LINUX only
######################################################################
case $PLATFORM in
  Linux)
    numberOfFiles=`ls -t archive/oswmeminfo | wc -l`
    numberToDelete=$numberOfFiles-$archiveInterval
    if [ $numberOfFiles -gt $archiveInterval ]
     then
       ls -t archive/oswmeminfo/* | tail -$numberToDelete | xargs rm
    fi
    numberOfFiles=`ls -t archive/oswslabinfo | wc -l`
    numberToDelete=$numberOfFiles-$archiveInterval
    if [ $numberOfFiles -gt $archiveInterval ]
     then
       ls -t archive/oswslabinfo/* | tail -$numberToDelete | xargs rm
    fi
esac 
done 
