#!/bin/bash

########################################################
### 检查计算器
###
### 2024-04-08 herryzhou
########################################################

Define_Default_Check_Times() {
  if  [ -z "$check_times" ] || [ "$check_times"  -eq 5 ]
  then
		check_times=5
	else
	  check_times="$check_times"
	fi
}

Check_Times_Counter() {
  Define_Default_Check_Times
  flag=1
  echo "#######正在检查CPU大于90%的记录，默认检查5次##############"
  while [ "$flag" -le "$check_times"]
  do
        let "flag++"
  done
}
