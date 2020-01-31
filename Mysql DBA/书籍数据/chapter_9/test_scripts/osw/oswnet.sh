#!/usr/bin/ksh
######################################################################
# oswnet.sh
# This script is called by OSWatcher.sh. This script runs the two
# netstat commands back to back.
#
######################################################################
echo "zzz"`date` >> $1
netstat -a -i -n >> $1  
netstat -s >> $1