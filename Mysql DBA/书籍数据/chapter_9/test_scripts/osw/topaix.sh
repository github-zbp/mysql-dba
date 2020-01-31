######################################################################
# topaix.sh
# This script is called by OSWatcher.sh. This script runs in place of 
# top on aix platforms. This script could also be used in place of top
# on other unix platforms.
#
######################################################################
echo "zzz"`date` >> $1
ps vg | head -1 >> $1
ps vg | sed 1d | sort -r -n +10 >> $1 
