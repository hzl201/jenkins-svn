#! /bin/bash
#====================================================================
# trans_cleanup.sh
#
# Copyright (c) 2011, WangYan <webmaster@wangyan.org>
# All rights reserved.
# Distributed under the GNU General Public License, version 3.0.
#
# Monitor disk space, If the Over, delete some files.
#
# See: http://wangyan.org/blog/trans_cleanup.html
#
# V0.2, since 2012-10-29
#====================================================================

# The transmission remote login username
USERNAME="hzl201"

# The transmission remote login password
PASSWORD="123456"

# The transmission download dir
DLDIR="/home/box123/downloads"

# The maximum allowed disk (%)
DISK_USED_MAX="80"

# Enable auto shutdown support (Disable=0, Enable=1)
ENABLE_AUTO_SHUTDOWN="0"

# Log path settings
LOG_PATH="/var/log/trans_cleanup.log"

# Date time format setting
DATA_TIME=$(date +"%y-%m-%d %H:%M:%S")

#====================================================================

dist_check()
{
    DISK_USED=`df -h $DLDIR | grep -v Mounted | awk '{print $5}' | cut -d '%' -f 1`
    DISK_OVER=`awk 'BEGIN{print('$DISK_USED'>'$DISK_USED_MAX')}'`
}

dist_check

#/usr/bin/transmission-remote -n hzl201:hzl63155680  -t all -AS

if [ "$DISK_OVER" = "1" ];then
    printf "transmission on speed\n"
	 /usr/bin/transmission-remote -n hzl201:123456  -t all -as
fi
    printf "transmission off speed\n"
