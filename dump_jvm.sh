#!/bin/bash

########################################################
### 查找占用CPU资源过高的线程详细信息
### 
### 2024-03-13 herryzhou
##########################################################

# 文件名称定义
filename="`date "+%F_%T"`-`hostname`-heapdump.hprof"

#Step1 打印占用CPU过高的JAVA进程ID
v_pid=`ps -eo pid,pcpu,cmd | sort -nk 2| grep -E "java|jar"| tail -n 1 | awk '{print $1}'`
[ -z "$v_pid" ]  && exit 1
echo "######   v_pid是${v_pid}     #####"

#Step2 打印进程中占用CPU过高的线程ID
v_tid=`top -b -d3 -n1 -H -p $v_pid | awk '/PID/,0' | awk 'NR==2 {print $1}'`
[ -z "$v_tid" ]  && exit 1
echo "######   v_tid是${v_tid}     #####"
#Step3 将线程ID转为16进制
#echo 'ibase=10;obase=16;$v_tid' | bc
v_tid16=`printf %x $v_tid`
echo "thread id[hexadecimal] is : 0x${v_tid16}"
echo ""

#Step4 打印CPU占用过高的进程的线程栈
echo "wait 5 seconds, please..."
jstack  $v_pid > ./_thread_stack.out
sleep 5s

#Step5 在 _thread_stack.out 中查找线程执行的具体代码,打印改行及其之后30行,并高亮显示匹配内容
cat ./_thread_stack.out | grep  -A 30 -i 0x${v_tid16} > ${filename}
