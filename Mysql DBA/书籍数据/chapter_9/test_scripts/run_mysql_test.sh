#!/bin/bash
## /root/script/run_mysql_test.sh
## 测试指引:
## 1. 主要用于对比版本和衡量软硬件调整的效果,对于整个应用系统的测试没有什么参考意义,整个应用系统基准测试会比单个mysql测试模型更全面准确;
## 2. 现实中对数据库的访问是很复杂的,而基准测试模型是简单的,很难反映现实应用系统的发展;
## 3. 如果是ssd盘,建议文件最大空间不超过总空间的85%,以避免ssd硬盘空间占比可能带来的性能下降;
## 3. 除了考虑吞吐率(TPS),还需要考虑响应时间(response time);
## 4. 只测试innodb,不对比myisam,因为生产环境不建议使用myisam.
## 
## mysql基准测试模型介绍.
##     组合以下不同条件:测试类型,线程数,表个数,表记录数(大小) 进行测试
##　   ================================开始测试====================================================
##     测试逻辑 : 
##　　    对每种测试类型
##　   　　   对各种并发线程数
##                对指定的表个数
##                    对不同表大小
##                          prepare
##                           sysbench 测试 ,默认测试1200秒
##                          cleanup
## ===================================结束测试=========================================================
##
## 准备测试环境
source $HOME/.bash_profile
dir_script=$(cd $(dirname $0) ; pwd)
mail_file="${dir_script}/mail_list"
if [  -s ${mail_file} ];then
  mail_list=`grep -v "^#" ${mail_file}`
else
  mail_list="dba_group@domain.com"
  # echo   "check $mail_file failed."
  # exit 1
fi
export PATH=/opt/MegaRAID/MegaCli:/usr/local/bin:$PATH
cd $dir_script
## 解压test_scripts.tar.gz到/root目录下. 即使用root用户进行测试,所有脚本,安装包都在/root/test_scripts下. 
## 包内有部分自动安装脚本,我是在RHEL5.4 64bit下验证通过的,如果其他OS不兼容,请手动安装
## 自动安装脚本默认把源码解压到/usr/local/src/xxxx_name ,或者当前目录下执行安装.
## root用户下: cd ; tar zxvf test_scripts.tar.gz ;cd test_scripts
## 1.安装mysql
##      略
which mysql > /dev/null 2>&1
if [ "$?" != 0 ];then
   echo "please install mysql server"
   echo "you can run command to install mysql server  : sh install_mysql_binary_muti.sh 3306 "  
   exit 88
fi
## 2.安装sysbench0.5
##      安装包sysbench0.5.zip
which sysbench > /dev/null 2>&1
if [ "$?" != 0 ];then
    echo "install sysbench 0.5 automatically for mysql offically binary version"
    cd /usr/local/src
    rm -rf sysbench0.5
    tar zxf $dir_script/sysbench0.5.tar.gz  
    cd sysbench0.5
    sh ./autogen.sh     > /dev/null
    ./configure --with-mysql-includes=/usr/local/mysql/include --with-mysql-libs=/usr/local/mysql/lib    > /dev/null
    make > /dev/null  && make install > /dev/null
    ## (如果是Percona版本,路径不一样,请修正)
    if [ "$?" != "0" ];then
     echo " install sysbench failed "
     exit 88
    else
      echo "install sysbench successful"
    fi
    cd $dir_script
fi
## 3.安装MegaCli,新版smartctl
##      安装包install_MegaCli_and_smartmontools.tar.gz
##　　　解压包,运行包内的install.sh脚本安装
which MegaCli64 > /dev/null 2>&1
if [ "$?" != 0 ];then
    echo "install MegaCli64 and smartmontools  automatically "
    cd /usr/local/src
    rm -rf install_MegaCli_and_smartmontools
    tar zxf $dir_script/install_MegaCli_and_smartmontools.tar.gz
    cd install_MegaCli_and_smartmontools
    sh install.sh > /tmp/install_MegaCli_and_smartmontools$$.log
    if [ "$?" != "0" ];then
        echo "install MegaCli64 and smartmontools failed"
        echo "please check log /tmp/install_MegaCli_and_smartmontools$$.log"
        exit 88
    else 
        echo "install  MegaCli64 and smartmontools  successful"
    fi
    cd $dir_script
fi
##
## 4.安装收集OS信息的工具pt-summary ,收集Mysql实例的工具pt-mysql-summary 
##     安装一个收集os信息的工具包osw            #已经在包内,需要先安装好 sysstat 包  . rpm -qa |grep sysstat
##           确认安装了sysstat这个包,因为有osw脚本会调用iostat,vmstat,mpstat,top这些工具收集测试过程的os信息.
##     wget   percona.com/get/pt-summary         #已经在包内
##     wget   percona.com/get/pt-mysql-summary   #已经在包内
##     chmod  u+x pt-summary pt-mysql-summary    
rpm -qa |grep sysstat > /dev/null
if [ "$?" != "0" ];then
   uname -a |grep el5 |grep x86_64 |grep Linux
   if [ "$?" != "0" ];then
      echo "install sysstat tools automatically"
      rpm -U  $dir_script/sysstat-7.0.2-3.el5.x86_64.rpm
      if [ "$?" != "0" ];then 
          echo "install sysstat tools failed"
          exit 88
      fi
   else
      echo " please install sysstat tools "
      exit 88
   fi
fi
## 5.了解硬件(raid,条带等),OS信息,文件系统,IO调度器等信息 . 
##     可运行脚本./hostinfo.sh 收集主机,OS信息
##     可运行脚本./raidinfo.sh 收集raid级别,raid卡等信息
## 6.配置好mysql基础环境(版本, innodb or innodb plugin, 社区版 or 企业版, pagesize块大小, 独立表空间 or 共享表空间, 文件分布, numa策略);
##   具体配置参考相关文档
##   可运行脚本mysqlinfo.sh记录当前的Mysql实例配置信息
## 7 在要测试的mysql实例中,如果实例中不存在库sbtest,此脚本会自动创建库 sbtest 供测试.由于脚本内有代码查询sbtest库,所以请不要指定其他数据库做测试
## 8. 安装gnuplot画图.最新为4.6版本,这里自动安装的是4.0版本的.你也可以使用excel画图.
which gnuplot > /dev/null 2>&1
if [ "$?" != 0 ];then
    echo "install gnuplot 4.0  automatically "
    install_log=/tmp/install_gnuplot$$.log
    cd /usr/local/src
    rm -rf gnuplot-4.0.0
    tar zxf $dir_script/gnuplot-4.0.0.tar.gz
    cd gnuplot-4.0.0
    ./configure > $install_log
    make >> $install_log && make install >> $install_log
    if [ "$?" != "0" ];then
       echo " install gnuplot  failed "
       exit 88
    else
       echo "install gnuplot successful" 
    fi
fi
##
## 开始测试
## 步骤 : 
## 1. 检查传递的参数,检查测试环境,确定环境变量.
## 2. 收集主机信息和Mysql实例信息
## 3. 开始sysbench测试
## 4. 结果处理,生成csv文件,画图.
## 5. 邮件通知DBA测试结束,并打包测试结果发送给DBA.
# 测试模型lua脚本所在的目录
lua_dir=$dir_script/sysbench_lua_script

###############################################################################################
# 一些函数.
check_mysql_status () {
ERROR_MSG=`$mysql --connect_timeout=5 -e "show databases;" 2>/dev/null`
# Check the output. If it is not empty then everything is fine.Else exit it.
if [ "$ERROR_MSG" != "" ]
then
        # mysql is fine
        echo -e "MySQL is running."
else
        # mysql is not fine
        warn=true
        echo -e "****** MySQL is *down or no privilege*.******"
        exit 90
fi
}
mysql_variable () {
        #local variable=$($mysql -Bse "show /*!50000 global */ variables like $1")
        local variable
        variable=$($mysql -Bse "show /*!50000 global */ variables like $1")
        if [ "$?" != "0" ];then
           echo "get variable $1 failed" 
           warn=true
        else
          variable=`echo $variable | awk '{ print $2 }'`
          export "$2"=$variable
        fi
}
check_mysql_version () {
## -- Print Version Info -- ##
        mysql_variable \'version\' mysql_version
        mysql_variable \'version_compile_machine\' mysql_version_compile_machine
        echo "MySQL Version $mysql_version $mysql_version_compile_machine"
}
show_mysql_instance_info () {
 check_mysql_version
 mysql_variable \'innodb_buffer_pool_size\' innodb_buffer_pool_size
 mysql_variable \'sync_binlog\' sync_binlog
 mysql_variable \'innodb_flush_log_at_trx_commit\' innodb_flush_log_at_trx_commit
 mysql_variable \'innodb_max_dirty_pages_pct\' innodb_max_dirty_pages_pct
 echo "innodb_buffer_pool_size=$innodb_buffer_pool_size" 
 echo "sync_binlog=$sync_binlog" 
 echo "innodb_flush_log_at_trx_commit=$innodb_flush_log_at_trx_commit" 
 echo "innodb_max_dirty_pages_pct=$innodb_max_dirty_pages_pct"
}
get_total_size_of () {
      mysql_variable \'innodb_buffer_pool_size\' innodb_buffer_pool_size
	  total_size=`$mysql -e "select sum(DATA_LENGTH+INDEX_LENGTH ) from information_schema.tables where table_schema='sbtest';"|grep -v "sum"`
      echo "total size of sbtest database = `expr $total_size / 1024 / 1024`M"
      echo "innodb_buffer_pool_size = $innodb_buffer_pool_size"
      total_size_to_ibf=`echo "scale=4;$total_size/$innodb_buffer_pool_size"|bc`
      echo "total size/innodb_buffer_pool_size = $total_size_to_ibf"
}
#############################################################################################

## 1.检查传递的参数, 检查测试环境,确定环境变量.
## 调用示例
## ./run_mysql_test.sh --socket=/usr/local/mysql/tmp/3306/mysql.sock --user=root --password=111111 
## 如果指定ip,则为远程连接进行测试,如果不指定ip,则为本地连接,使用sockfile连接.
usage () {
   cat <<EOF
Usage: $0 [OPTIONS]
--socket             ：socket file,默认为/tmp/mysql.sock
--basedir            ：mysql server安装路径 ,默认/usre/local/mysql/
--user               : 备份用户,默认 root
--password           : 用户密码,默认 111111
--host               : 远程主机名 ,默认localhost
--port               : 远程端口 ,默认3306
--test_type          : 测试类型.默认为oltp (oltp insert delete select update_index update_non_index select_random_ranges select_random_points)
--numthreads         : 线程数
--table_count        : 表个数, 表个数必须是线程数的倍数!!!!某老外说的.
--table_size         : 表大小
--max_time           : 单个测试类型的执行时间,默认是600秒.
EOF
        exit 0
}
#echo "$@"
parse_arguments() {
  for arg do
    opts_value=`echo "$arg" | sed -e 's/^[^=]*=//'`
    case "$arg" in
      --socket=*)  socket=$opts_value ;;
      --basedir=*)  basedir=$opts_value ;;
      --user=*)  user=$opts_value ;;
      --password=*)  password=$opts_value ;;
      --host=*)  host=$opts_value ;;
      --port=*)  port=$opts_value ;;
      --test_type=*) test_type=$opts_value ;;
      --numthreads=*)  numthreads=$opts_value ;;
      --table_count=*)  table_count=$opts_value ;;
      --table_size=*)  table_size=$opts_value ;;
      --max_time=*)  max_time=$opts_value ;;
      --help)     usage ;;
      *)
      echo "Usage:`basename $0` --help   "
      exit 1 ;;
    esac
  done
}
parse_arguments $@
if [ -z $basedir ];then
    basedir=/usr/local/mysql/
    if ! [ -x $basedir/bin/mysql ];then
       echo "Not exist mysql program In $basedir/bin"
       exit 99
    fi
fi
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
## sysbench输出结果每次间隔多少秒
interval_sec=10
## 测试类型,一般选 oltp
#test_type_list="oltp insert delete select update_index update_non_index select_random_ranges select_random_points"
test_type_list="oltp"
if ! [ -z "${test_type}" ];then
  test_type_list=${test_type}
fi
#numthreads_list="2 4 8 16 32 64 128 256 512 1024 2056"
numthreads_list="2 8 16 32 64 128"
if ! [ -z "${numthreads}" ];then
  numthreads_list=${numthreads}
fi
#table_size_list="1000000 5000000 10000000"   #100万大概200M.平均行长度约235字节.
table_size_list="30000 40000 50000 100000 200000 300000" 
if ! [ -z "${table_size}" ];then
  table_size_list=${table_size}
fi
if  [ -z "$table_count" ];then
  table_count=256
fi
if  [ -z "$max_time" ];then
  #max_time=1200
  max_time=3600
fi
# 检查table_count和numthreads_list,table_count需要是numthreads的整数倍.
for numthreads in ${numthreads_list}
  do 
    if [ "$(( $table_count % $numthreads ))" = "0" ];then
       continue
  else
    echo "table_count is $table_count ,numthreads is $numthreads "
    exit 99
  fi
done

export PATH=$basedir/bin:$PATH
if [ "$host" = "localhost" ];then
  if [ -z $socket ];then
     mysql="mysql -u${user} -p${password} -S /tmp/mysql.sock"
  else
     mysql="mysql -u${user} -p${password} -S $socket"
  fi
else
  mysql="mysql -u${user} -p${password} -h $host -P $port"
fi
# 检查mysql是否允许连接.
check_mysql_status
# 如果是通过socket连接mysql,则获取Mysql的端口
if [ "$host" = "localhost" ];then
  #if ! [ -z $socket ];then
    #echo "get local mysql stance port"
    mysql_variable \'port\' port
  #fi
fi

# 确定sysbench mysql连接字符串,确定输出结果目录
date_str=`date +%Y%m%d_%H%M%S`
if [ "$host" = "localhost" ];then
  if [ -z $socket ];then
     sb_opts=" --mysql-user=$user --mysql-password=$password --mysql-socket=/tmp/mysql.sock "
     output_dir=$dir_script/sysbench_test_$host_$port_${date_str}
  else
     sb_opts=" --mysql-user=$user --mysql-password=$password --mysql-socket=$socket " 
     output_dir=$dir_script/sysbench_test_`hostname`_${port}_${date_str}
  fi
else
     sb_opts=" --mysql-user=$user --mysql-password=$password --mysql-host=$host --mysql-port=$port "
     output_dir=$dir_script/sysbench_test_$host_$port_${date_str}
fi

mkdir $output_dir  && echo "You can see sysbench benchmarking results  in the directory  $output_dir"
if [ "$?" != "0" ];then
   echo "mkdir $output_dir failed"
   exit 92
fi

## 2. 收集主机信息和Mysql实例信息
## 是否安装了sysstat包
rpm -qa |grep sysstat > /dev/null
if [ "$?" != "0" ];then
   echo "please install sysstat tools"
exit 88
fi
# 收集主机基础信息
if [ "$host" = "localhost" ];then
  $dir_script/hostinfo.sh > $output_dir/information_host.txt
fi
# 收集raid信息
if [ "$host" = "localhost" ];then
  $dir_script/raidinfo.sh > $output_dir/information_raid.txt
  if [ "$?" != "0" ];then
     echo "collect raid information error, please check file  $output_dir/information_raid.txt"
  fi
fi
# 收集Mysql实例信息
if [ "$host" = "localhost" ];then
  if [ -z $socket ];then 
    $dir_script/mysqlinfo.sh --user=$user --password=$password --socket=/tmp/mysql.sock  > $output_dir/information_mysql.txt
  else
    $dir_script/mysqlinfo.sh --user=$user --password=$password --socket=$socket > $output_dir/information_mysql.txt
  fi
else
    $dir_script/mysqlinfo.sh --user=$user --password=$password  --host=$host --port=$port > $output_dir/information_mysql.txt 
fi
if [ "$?" != "0" ];then
     echo "collect mysql  information error, please check file  $output_dir/information_mysql.txt"
fi

##　检查是否有数据库sbtest  ,如果没有,create database sbtest;
dbs_list=`$mysql   -e 'show databases' |grep sbtest`
if [ "$?" != "0" ];then
  echo "create test database sbtest"
  $mysql -e "create database sbtest;"
fi
which sysbench > /dev/null 2>&1
if [ "$?" != "0" ];then
  echo "please install sysbench"
  exit 93
fi

## 检查是否安装了gnuplot,画图工具.
which gnuplot > /dev/null 2>&1
if [ "$?" != "0" ];then
  echo "please install gnuplot"
fi

# 调用osw脚本收集测试期间的主机性能信息 ,注意在测试过程中失败或者结束时退出这个收集信息的后台程序.
if [ -x $dir_script/osw/startOSW.sh -a -x $dir_script/osw/stopOSW.sh ];then
  cd $dir_script/osw/
  echo "starting OSW"
  ./startOSW.sh > /dev/null
  cd $dir_script/
fi

## 3. 开始sysbench测试
curd=`pwd`
date_start=$(date +%s)
for test_type in $test_type_list
do
  for numthreads in ${numthreads_list}
  do
    for table_size in $table_size_list 
    do
      outfile=$output_dir/run.$test_type.tblcnt$table_count.thr$numthreads.tblsize$table_size.txt
      sysbench --test=$lua_dir/$test_type.lua --mysql-table-engine=innodb  --oltp-tables-count=$table_count  --oltp-table-size=$table_size $sb_opts prepare  
      if [ "$?" != "0" ];then
          echo "sysbench prepare failed"
          if [ -x $dir_script/osw/startOSW.sh -a -x $dir_script/osw/stopOSW.sh ];then
              cd $dir_script/osw/
                echo "stoping OSW"
              ./stopOSW.sh
              cd $dir_script/
          fi
          exit 99
      fi
      sync
      echo 3 > /proc/sys/vm/drop_caches
      echo "" 
      echo "Start running test :  `date`"
      show_mysql_instance_info  |tee -a $outfile
      echo "created  $table_count tables, $table_size rows a table" |tee -a $outfile
      get_total_size_of  |tee -a $outfile
      echo ""
      #sleep 10
      sleep 10
      sysbench --test=$lua_dir/$test_type.lua  --oltp-tables-count=$table_count  --oltp-table-size=$table_size $sb_opts --max-time=$max_time --max-requests=0 --num-threads=$numthreads  --report-interval=$interval_sec run | tee -a $outfile
      if [ "$?" != "0" ];then
          echo "sysbench run failed"
          if [ -x $dir_script/osw/startOSW.sh -a -x $dir_script/osw/stopOSW.sh ];then
              cd $dir_script/osw/
                 echo "stoping OSW"
              ./stopOSW.sh
              cd $dir_script/
          fi
          exit 97
      fi
      echo "End running test :  `date`"
      sysbench --test=$lua_dir/$test_type.lua  --oltp-tables-count=$table_count  --oltp-table-size=$table_size $sb_opts cleanup
      cd $curd
     # 休眠一段时间,方便调整参数继续测试.
      echo "sleep 60 seconds,you can set up some parameters"
      sleep 60
     done
   done
done
date_end=$(date +%s)
echo "`date "+%Y-%m-%d %H:%M:%S"` .mysql sysbench test completed. ($((date_end-date_start)) sec)"

# 关闭osw脚本
cd $dir_script/osw
echo "stoping OSW"
./stopOSW.sh
cd $dir_script/


## 4. 结果预处理
# 生成csv文件,方便excel画图 
## 文件名example: run.oltp.tblcnt256.thr128.tblsize1000000.txt
for test_type in $test_type_list
do
  $dir_script/into_csv.sh --test_type=$test_type  --output_dir=$output_dir
done

## 4.2  gnuplot 绘图
cd $output_dir
which gnuplot > /dev/null 2>&1
ret_gnuplot="$?"
if [ "$ret_gnuplot" != "0" ];then
   echo "please install gnuplot "
else
  ## 文件名example: run.oltp.tblcnt256.thr128.tblsize1000000.txt.csv
  ## 1. 对每个csv文件进行绘图,整个图包含4个部分 ,事务吞吐,读频率,写频率,响应时间;
  for test_type in $test_type_list
  do
     for numthreads in ${numthreads_list}
     do
       for table_size in $table_size_list
       do 
          csvfile=$output_dir/run.$test_type.tblcnt$table_count.thr$numthreads.tblsize$table_size.txt.csv
          size_to_buffer=`cat $output_dir/run.$test_type.tblcnt$table_count.thr$numthreads.tblsize$table_size.txt|grep "total size/innodb_buffer_pool_size" | awk '{ print $4 }'`
          db_size=`cat $output_dir/run.$test_type.tblcnt$table_count.thr$numthreads.tblsize$table_size.txt|grep "total size of sbtest database"|awk '{ print $7}'`
          if  [ -s $csvfile ];then
          gnuplot << EOF
set terminal png size 1024,768
set output "${csvfile}.png"
set key top left
set key box
set grid
set title "$test_type,$numthreads threads,$table_count tables,$table_size rows each. $size_to_buffer * buffer = $db_size"
set datafile separator ","
set size 1,1
set origin 0,0
set multiplot
set size 0.5,0.5
set origin 0,0.5
set xlabel "time(seconds)"
set ylabel "tps"
plot [$interval_sec:$max_time] '$csvfile' using 1:3 with linespoints title "transactions per seconds"

set size 0.5,0.5
set origin 0,0
set xlabel "time(seconds)"
set ylabel "reads/s"
plot [$interval_sec:$max_time] '$csvfile' using 1:4 with linespoints title "reads per seconds"

set size 0.5,0.5
set origin 0.5,0.5
set xlabel "time(seconds)"
set ylabel "writes/s"
plot [$interval_sec:$max_time] '$csvfile' using 1:5 with linespoints title "writes per seconds"

set size 0.5,0.5
set origin 0.5,0
set xlabel "time(seconds)"
set ylabel "resonse time(ms)"
plot [$interval_sec:$max_time] '$csvfile' using 1:6 with linespoints title "response time"
unset multiplot
reset
EOF
          else
             echo "Not exist file $csvfile"
          fi
       done
     done
  done
fi
  ## 2. 对每种数据量下的线程并发画图.检查数据量一定,线程数递增,吞吐应该如何变化;事务吞吐的取值:选择csv文件最后10行记录的平均值.
  ## from yeml,  tail -20 a |gawk 'BEGIN{FS=","}{a+=$3;i+=1}END{print a/i}'
if [ "$ret_gnuplot" = "0" ];then
   for test_type in $test_type_list
   do
      for table_size in $table_size_list
      do 
         threads_incre_file=$output_dir/run.$test_type.tblcnt$table_count.tblsize$table_size.plot
         echo "test_type,table_count,table_size,threads,tps" > $threads_incre_file
         for numthreads in ${numthreads_list}
         do
           csvfile=$output_dir/run.$test_type.tblcnt$table_count.thr$numthreads.tblsize$table_size.txt.csv
           size_to_buffer=`cat $output_dir/run.$test_type.tblcnt$table_count.thr$numthreads.tblsize$table_size.txt |grep "total size/innodb_buffer_pool_size" | awk '{ print $4 }'`
  db_size=`cat $output_dir/run.$test_type.tblcnt$table_count.thr$numthreads.tblsize$table_size.txt |grep "total size of sbtest database"|awk '{ print $7}'`
           avg_tps=`tail -20 $csvfile |gawk 'BEGIN{FS=","}{a+=$3;i+=1}END{print a/i}'`
           echo "$test_type,$table_count,$table_size,$numthreads,$avg_tps" >> $threads_incre_file
         done
      ## 画图了...
          gnuplot << EOF
set terminal png
set output "${threads_incre_file}.png"
set key top left
set key box
set grid
set title "$test_type,$table_count tables,$table_size rows each,$size_to_buffer * buffer = $db_size"
set datafile separator ","
set xlabel "threads"
set ylabel "tps"
plot  '${threads_incre_file}' using 4:5 with linespoints title "tps of different threads"
EOF
      done
    done
fi
  ## 3. 线程数一定,数据表个数一定, 数据量(table size)变化,对于事务吞吐的影响;
if [ "$ret_gnuplot" = "0" ];then
   for test_type in $test_type_list
   do
      for numthreads in ${numthreads_list}
      do
         tblsize_incre_file=$output_dir/run.$test_type.tblcnt$table_count.thr$numthreads.plot
         echo "test_type,table_count,threads,table_size,tps,buffer_ratio" > $tblsize_incre_file
         for table_size in $table_size_list
         do
           csvfile=$output_dir/run.$test_type.tblcnt$table_count.thr$numthreads.tblsize$table_size.txt.csv
   size_to_buffer=`cat $output_dir/run.$test_type.tblcnt$table_count.thr$numthreads.tblsize$table_size.txt |grep "total size/innodb_buffer_pool_size" | awk '{ print $4 }'`
           avg_tps=`tail -10 $csvfile |gawk 'BEGIN{FS=","}{a+=$3;i+=1}END{print a/i}'`
           echo "$test_type,$table_count,$numthreads,$table_size,$avg_tps,$size_to_buffer" >> $tblsize_incre_file
         done
      ## 画图了...
          gnuplot << EOF
set terminal png size 
set output "${tblsize_incre_file}.png"
set label "from  ucgary \n 2012" at graph 0.5,0.5 center font "Symbol,24"
set key top left
set key box
set grid
set title "$test_type  ,$table_count tables ,$numthreads threads "
set datafile separator ","
set xlabel "table rows"
set ylabel "tps"
plot  '${tblsize_incre_file}' using 4:5 with linespoints title "tps of different table size"
EOF
      done
    done
fi

cd -

## 5. 邮件通知DBA测试结束,并打包测试结果发送给DBA.
cd $dir_script
file_tgz="${output_dir}.tar.gz"
tar czf $file_tgz  $output_dir
echo "mysql sysbench test finished,running sysbench on `hostname`"|mutt -s "sysbench test report." $mail_list -a $file_tgz -c your_mail@domain.com

## 脚本附加解释
## --max-time 最大执行时间,0为无限
## --max-requests 访问请求,0为无限
## --report-interval  每隔多少秒报告一次统计.之前的sysbench的版本0.4没有这个选项,只能在测试结束后输出统计报告.
## --test=oltp.lua oltp.lua 所执行的操作有,对于单个表执行 1.几个基于主键的查询;2.主键范围查找;3.主键范围查找+聚合函数;4.主键范围查找+文件排序;5.主键范围查找+
## 临时表+文件排序;6.更新操作(基于主键查询);7.删除操作(基于主键查询);8.插入操作. commit . 没有复杂的查询,join操作.
