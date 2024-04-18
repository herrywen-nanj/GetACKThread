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

Check_Times_Counter_Controller() {
  Define_Default_Check_Times
  flag=1
  echo "#######正在检查CPU大于90%的记录，默认检查5次##############"
  while [ "$flag" -le "$check_times"]
	do
    # 从 Prometheus 查询 Pod 的 CPU 使用率
    CPU_USAGE=`curl  -H "Authorization: Bearer $TOKEN" -s  "$PROMETHEUS_URL/api/v1/query_range?query=sum(irate(container_cpu_usage_seconds_total\{pod=~\"$POD\",namespace=\"$NAMESPACE\"\}\[1m\]))by(pod)&start=$(date -d '1 minute ago' +%s)&end=$(date +%s)&step=10"| jq -r '.data.result[].values[-1][1]'`
		[ -z $CPU_USAGE ] && continue
		CPU_USAGE_TOTAL=`curl -s  "$PROMETHEUS_URL/api/v1/query_range?query=max(container_spec_cpu_quota\{pod=~\"$POD\",namespace=\"$NAMESPACE\"\})&start=$(date -d '1 minute ago' +%s)&end=$(date +%s)&step=61" | jq -r '.data.result[].values[-1][1]'`
		[ -z $CPU_USAGE_TOTAL ] && continue
		CPU_USAGE_PERCENT=`echo "${CPU_USAGE} *1000*100*100/$CPU_USAGE_TOTAL" |bc `
    # 检查 CPU 使用率是否超过阈值,需要提前设置ACK中应用的StartupProbe探针的initialDelaySeconds参数为3m即设置180s，启动完成程序会占用较高CPU，运行大概3m会趋近正常  
		if [[ "$CPU_USAGE_PERCENT" -gt "$THRESHOLD" ]]; then
				let "flag++"
		fi
	done
}
