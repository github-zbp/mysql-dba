#!/bin/bash
# 收集主机基础信息
dir_script=`dirname $0`
if [ -x $dir_script/pt-summary ];then
  rf=`mktemp`
  $dir_script/pt-summary > $rf
## 输出部分关注的信息
  echo "部分信息摘要"
  egrep  "Hostname|Release|Processors|Models|Total|Controller" $rf |grep -v "Ethernet"
  grep -A 5 "Disk Schedulers"  $rf |egrep -v "Disk Partioning|Device"
echo ""
echo ""
echo "全部信息"
## 输出所有收集到的信息
cat $rf
rm $rf
else
 echo "please install pt-summary, wget  percona.com/get/pt-summary;chmod u+x pt-summary"
 exit 99
fi
