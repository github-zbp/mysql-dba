#!/usr/bin/ksh
######################################################################
# Copyright (c)  2007 by Oracle Corporation
# oswlnxio.sh
# This script is called by OSWatcher.sh. This script is the generic
# data collector shell for collecting linux iostat data. $1 is the output
# filename for the data collector. This script takes 3 samples of iostat
# but disregards the first sample, sending only 2 samples to the file
######################################################################
echo "zzz ***"`date` >> $1
iostat -x 3 3|awk 'BEGIN{skip=0; pr=0}
/^avg-cpu: /{if (skip==1) { pr=1} else {skip=1}}
pr == 1 {print}' >> $1
