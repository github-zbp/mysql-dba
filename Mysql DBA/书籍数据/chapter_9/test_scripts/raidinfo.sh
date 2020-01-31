#!/bin/bash
export PATH=/opt/MegaRAID/MegaCli:$PATH
which MegaCli64 > /dev/null 2>&1
if [ "$?" != "0" ];then
   echo "please install MegaCli64"
   exit 99
fi
# 收集raid信息
echo "查看Raid级别"
MegaCli64  -LDInfo -Lall -aALL 
echo "=============================================" 
echo "" 
echo "" 
echo "" 
echo "" 
echo "查看Raid卡信息"
MegaCli64 -AdpAllInfo -aALL 
