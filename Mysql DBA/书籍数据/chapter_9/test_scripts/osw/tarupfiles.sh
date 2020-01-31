tar cvf osw_archive.tar archive
compress osw_archive.tar
hour=`date +'%m%d%y%H%M.tar.Z'`
mv osw_archive.tar.Z osw_archive_$hour