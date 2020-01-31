#!/bin/bash
## 收集mysql实例基础信息
usage () {
   cat <<EOF
Usage: $0 [OPTIONS]
--socket             ：socket file,默认为/tmp/mysql.sock
--user               : 备份用户,默认 root
--password           : 用户密码,默认 111111 
--host               : 远程主机名 ,默认localhost
--port               : 远程端口 ,默认3306
EOF
        exit 0
}     
#echo "$@"
parse_arguments() {
  for arg do
    opts_value=`echo "$arg" | sed -e 's/^[^=]*=//'`
    case "$arg" in
      --socket=*)  socket=$opts_value ;;
      --user=*)  user=$opts_value ;;
      --password=*)  password=$opts_value ;;
      --host=*)  host=$opts_value ;;
      --port=*)  port=$opts_value ;;
      --help)     usage ;;
      *)
      echo "Usage:`basename $0` --help   "
      exit 1 ;;
    esac
  done
}
parse_arguments $@
if [ -z $host ];then
   host=localhost
fi
if [ -z $port ];then
   port=3306
fi

if [ -z $user ];then
      user=root
fi
if [ -z $password ];then
      password="111111"
fi
if [ -z "$socket" ];then
   pt_mysql_summary_opts="  --user=$user --password=$password --host=$host --port=$port " 
else
   pt_mysql_summary_opts="  --user=$user --password=$password --socket=$socket " 
fi

dir_script=`dirname $0`
if [ -x $dir_script/pt-mysql-summary ];then
 rf=`mktemp`
 $dir_script/pt-mysql-summary --databases=sbtest  --sleep=0 -- ${pt_mysql_summary_opts} > $rf
## 输出部分关注的信息
  echo "部分信息摘要"
  egrep -A 11 "Report On Port" $rf 
  egrep -A 1  "Table cache"  $rf 
  egrep -A 2 "\# InnoDB "  $rf 
  egrep  "File Per Table|Page Size|Log File Size|Flush Log At Commit|Thread Concurrency|Txn Isolation Level|sync_binlog \|" $rf 
  egrep  "log-bin.*=|innodb_data_home_dir|innodb_log_group_home_dir|innodb_max_dirty_pages_pct"  $rf 
echo ""
echo ""
echo "全部信息"
## 输出所有收集到的信息
cat $rf
rm $rf
else
 echo "please install pt-mysql-summary, wget  percona.com/get/pt-mysql-summary;chmod u+x pt-mysql-summary"
 exit 99
fi
