#!/usr/bin/ksh
######################################################################
# oswsub.sh
# This script is called by OSWatcher.sh. This script is the generic
# data collector shell. $1 is the output filename for the data
# collector. $2 is the data collector shell script to execute.
#
######################################################################
echo "zzz ***"`date` >> $1
$2 >> $1

