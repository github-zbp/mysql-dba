#!/usr/bin/ksh

######################################################################
# Copyright (c)  2005 by Oracle Corporation
# startOSW.sh
# This is the script that starts the OSWatcher program. It accepts 3
# arguments which control the frequency that data is collected and the 
# number of hours worth of data to archive.
#
# $1 = snapshot interval in seconds
# $2 = the number of hours of archive data to store.
# $3 = (optional) the name of the zip or compress utility you want
#      OSW to use to zip up the archive files upon completion
#
# If you do not enter any arguments the script runs with default values
# of 30 and 48 meaning collect data every 30 seconds and store the last  
# 48 hours of data.
######################################################################
# Modifications Section:
######################################################################
##     Date        File            Changes
##
##  07/24/2007     startOSW.sh      Added optional 3rd parameter to 
##  V2.1.0                          compress files  
######################################################################
# First check to see if osw is already running
######################################################################
pgrep OSWatcher >/dev/null
if [ $? -eq 0 ]; then
        echo "An OSWatcher process has been detected."
        echo "Please stop it before starting a new OSWatcher process."
        exit
fi
######################################################################
# Start OSW
######################################################################
./OSWatcher.sh $1 $2 $3 &
