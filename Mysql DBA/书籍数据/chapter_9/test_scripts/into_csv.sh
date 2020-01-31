#!/bin/bash
# 转换sysbench测试结果为csv文件,以方便用excel画图.
usage () {
   cat <<EOF
Usage: $0 [OPTIONS]
--test_type         ：测试类型
--output_dir        : 文件目录
EOF
        exit 0
}
#echo "$@"
parse_arguments() {
  for arg do
    opts_value=`echo "$arg" | sed -e 's/^[^=]*=//'`
    case "$arg" in
      --test_type=*)  test_type=$opts_value ;;
      --output_dir=*)  output_dir=$opts_value ;;
      --help)     usage ;;
      *)
      echo "Usage:`basename $0` --help   "
      exit 1 ;;
    esac
  done
}
parse_arguments $@
if [ -z "$output_dir" ];then
  output_dir="./" 
fi
curd=`pwd`
cd $output_dir 
for file in `ls run*$test_type*txt`
do
 #echo "deal with $test_type files $file  in the directory $output_dir"
 grep "^\[" $file  | sed -e  's/^\[[ \t]*//g' | gawk 'BEGIN{print ",threads,tps,reads/s,writes/s,response time";}{t=$1;gsub("s]","",t);threads=$3;gsub(",","",threads);tps=$5;gsub(",","",tps);reads=$7;gsub(",","",reads);writes=$9;gsub(",","",writes);response=$12;gsub("ms","",response);print t "," threads "," tps "," reads "," writes  "," response}'  > ${file}.csv
done
cd $curd
