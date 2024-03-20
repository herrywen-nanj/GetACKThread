#!/bin/bash

########################################################
### 获取环境参数
### 
### 2024-03-13 herryzhou
##########################################################

# 工作目录
WORKPLACE="$( cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIGURATIONFILE="$(find $WORKPLACE -type f -name "*.conf")"

Is_FileExsit() {
	if [ ! -f "$CONFIGURATIONFILE" ]
	then
		echo "${CONFIGURATIONFILE}不存在!!!!"
		exit 1
	fi
}


Is_Blank() {
	if  [ ! -n "`cat $CONFIGURATIONFILE`" ]
	then
		echo "${CONFIGURATIONFILE}为空白文件!!!!!"
		exit 1
	fi
}


ReadConfigurationFile() {
	Is_FileExsit
	Is_Blank
	awk -F='{print "export " $1"="$2}' ${CONFIGURATIONFILE} | while read line; do eval "${line}"; done
}


ReadConfigurationFile