#!/bin/bash

########################################################
### 获取当前阿里云ACK集群下CPU使用率大于90%的POD线程堆栈日志，POD内为springboot应用
### 注意有些由于初始CPU设置过小的应用，会在启动初期将CPU打满，需要设置这些应用的StartupProbe探针的initialDelaySeconds参数，参数由监控观察得来
### 
### 2024-03-13 herryzhou
##########################################################
# 环境参数获取
. ./GetEnvironmentVariables.sh
  

# 命名空间  
NAMESPACE="default" 
  
# CPU 使用率阈值  
THRESHOLD=90  
  
# 获取命名空间中所有 Pod 的 CPU 使用率  
PODS=$(kubectl  --kubeconfig  $kubeconfig  get pods -n $NAMESPACE -o jsonpath='{.items[*].metadata.name}')  

# 工作目录
WORKPLACE="$( cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
 

# OSS远程存储路径
OSS_PATH="oss://xxxxxx/jvm-dump/"


 
for POD in $PODS; do  
	# 查询pod是否就绪,限制条件只适合pod内只有一个容器
	STATUS_PHASE=$(kubectl  --kubeconfig  $kubeconfig get pods  -o=jsonpath="{.items[?(@.metadata.name == '$POD')].status.phase}")
	STATUS_READY=$(kubectl  --kubeconfig  $kubeconfig get pods -o=jsonpath="{.items[?(@.metadata.name == '$POD')].status.containerStatuses}"| sed "s/[][]//g" | jq ".ready")
	if [[ $STATUS_PHASE == "Running" ]] && [[ $STATUS_READY == "true" ]];then 
		# 从 Prometheus 查询 Pod 的 CPU 使用率  
		CPU_USAGE=`curl  -H "Authorization: Bearer $TOKEN" -s  "$PROMETHEUS_URL/api/v1/query_range?query=sum(irate(container_cpu_usage_seconds_total\{pod=~\"$POD\",namespace=\"$NAMESPACE\"\}\[1m\]))by(pod)&start=$(date -d '1 minute ago' +%s)&end=$(date +%s)&step=10"| jq -r '.data.result[].values[-1][1]'`
		[ -z $CPU_USAGE ] && continue
		CPU_USAGE_TOTAL=`curl -s  "$PROMETHEUS_URL/api/v1/query_range?query=max(container_spec_cpu_quota\{pod=~\"$POD\",namespace=\"$NAMESPACE\"\})&start=$(date -d '1 minute ago' +%s)&end=$(date +%s)&step=61" | jq -r '.data.result[].values[-1][1]'`
		[ -z $CPU_USAGE_TOTAL ] && continue
		CPU_USAGE_PERCENT=`echo "${CPU_USAGE} *1000*100*100/$CPU_USAGE_TOTAL" |bc `
		echo $CPU_USAGE_PERCENT
		  
		# 检查 CPU 使用率是否超过阈值,需要提前设置ACK中应用的StartupProbe探针的initialDelaySeconds参数为3m即设置180s，启动完成程序会占用较高CPU，运行大概3m会趋近正常  
		if [[ "$CPU_USAGE_PERCENT" -gt "$THRESHOLD" ]]; then  
			echo "$(date +"%Y-%m-%d-%H:%M")    Pod $POD CPU使用率为$CPU_USAGE_PERCENT超过 $THRESHOLD%，正在重启 Pod"   >> $(date +%F)_delete_pod.txt
			kubectl  --kubeconfig  $kubeconfig exec -it $POD -- sh<dump_jvm.sh > /dev/null 2>&1
			if [[ $? -eq 0 ]]; then
			# 拷贝dump文件
				kubectl  --kubeconfig  $kubeconfig exec -it $POD -- ls>$POD.txt
				DUMPFILENAME=$(cat $POD.txt | grep "$POD"|awk '{print $1}')
				TIMESTAMP=`date "+%Y-%m-%d-%H-%M-%S"`
				kubectl  --kubeconfig  $kubeconfig cp $POD:$DUMPFILENAME $DUMPPATH$POD$TIMESTAMP.hrpof
			fi
			echo "Pod $POD CPU 使用率超过 $THRESHOLD%，正在重启 Pod"  
			# 删除 Pod，Kubernetes 会根据 Replicaset 或 Deployment 自动重启		 
			kubectl  --kubeconfig $kubeconfig  delete pod $POD --namespace $NAMESPACE 
			sleep 10
		# 上传到ossbucket
		#[ -e "${DUMPPATH}/${DUMPFILENAME}" ] && ossutil64 cp -r -u "${DUMPPATH}/${DUMPFILENAME}" ${OSS_PATH} || echo "Can't find ${DUMPFILENAME} in ${DUMPPATH}!"
		fi
	fi
done

# 清理dump,保留3天
find $DUMPPATH -type f -mtime +3 -name "*.hprof" -exec rm -rf {} \;
# 清理pod_message.txt，保留3天
find . -type f -mtime +3 -name "*.txt" -exec rm -rf {} \;

