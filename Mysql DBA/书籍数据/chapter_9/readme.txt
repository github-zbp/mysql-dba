这个是一个简单的压测脚本，仅供参考，读者需要修改为合适自己的形式。压缩文件是目录的副本，以方便下载。
在MySQL 5.1和RHEL5.4下运行通过。

具体说明，请参考 run_mysql_test.sh 文件。
实际测试的时候，先安装好MySQL，然后运行run_mysql_test.sh脚本进行测试。

备注：
测试脚本运行的时候，会调用osw。osw是一个Oracle开发的记录系统性能的小工具，
启动方式是：startOSW.sh
关闭方式是：stopOSW.sh
在不测试的时候，记得检查osw是否还在运行（脚本正常结束时会自动关闭osw的），如果仍然在运行，需关闭osw，不记录数据。
脚本结束运行的时候，会自动绘图。
笔者的环境是有Raid卡的，install_MegaCli_and_smartmontools.tar.gz 是用来安装Raid监控工具的。
