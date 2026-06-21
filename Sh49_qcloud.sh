#!/bin/sh
#copyright by hiboy
source /etc/storage/script/init.sh
qcloud_enable=`nvram get qcloud_enable`
[ -z $qcloud_enable ] && qcloud_enable=0 && nvram set qcloud_enable=0
if [ "$qcloud_enable" != "0" ] ; then
#nvramshow=`nvram showall | grep '=' | grep qcloud | awk '{print gensub(/'"'"'/,"'"'"'\"'"'"'\"'"'"'","g",$0);}'| awk '{print gensub(/=/,"='\''",1,$0)"'\'';";}'` && eval $nvramshow

qcloud_interval=`nvram get qcloud_interval`
qcloud_ak=`nvram get qcloud_ak`
qcloud_sk=`nvram get qcloud_sk`
qcloud_domain=`nvram get qcloud_domain`
qcloud_name=`nvram get qcloud_name`
qcloud_domain2=`nvram get qcloud_domain2`
qcloud_name2=`nvram get qcloud_name2`
qcloud_domain6=`nvram get qcloud_domain6`
qcloud_name6=`nvram get qcloud_name6`
qcloud_ttl=`nvram get qcloud_ttl`

IPv6=0
domain_type=""
hostIP=""
domain=""
name=""
name1=""
timestamp=`date +%s`
qcloud_record_id=""
[ -z $qcloud_interval ] && qcloud_interval=600 && nvram set qcloud_interval=$qcloud_interval
[ -z $qcloud_ttl ] && qcloud_ttl=600 && nvram set qcloud_ttl=$qcloud_ttl
qcloud_renum=`nvram get qcloud_renum`

fi

if [ ! -z "$(echo $scriptfilepath | grep -v "/tmp/script/" | grep qcloud)" ]  && [ ! -s /tmp/script/_qcloud ]; then
    mkdir -p /tmp/script
    { echo '#!/bin/sh' ; echo $scriptfilepath '"$@"' '&' ; } > /tmp/script/_qcloud
    chmod 777 /tmp/script/_qcloud
fi

qcloud_restart () {

relock="/var/lock/qcloud_restart.lock"
if [ "$1" = "o" ] ; then
	nvram set qcloud_renum="0"
	[ -f $relock ] && rm -f $relock
	return 0
fi
if [ "$1" = "x" ] ; then
	if [ -f $relock ] ; then
		logger -t "【qcloud】" "多次尝试启动失败，等待【"`cat $relock`"分钟】后自动尝试重新启动"
		exit 0
	fi
	qcloud_renum=${qcloud_renum:-"0"}
	qcloud_renum=`expr $qcloud_renum + 1`
	nvram set qcloud_renum="$qcloud_renum"
	if [ "$qcloud_renum" -gt "2" ] ; then
		I=19
		echo $I > $relock
		logger -t "【qcloud】" "多次尝试启动失败，等待【"`cat $relock`"分钟】后自动尝试重新启动"
		while [ $I -gt 0 ]; do
			I=$(($I - 1))
			echo $I > $relock
			sleep 60
			[ "$(nvram get qcloud_renum)" = "0" ] && exit 0
			[ $I -lt 0 ] && break
		done
		nvram set qcloud_renum="0"
	fi
	[ -f $relock ] && rm -f $relock
fi
nvram set qcloud_status=0
eval "$scriptfilepath &"
exit 0
}

qcloud_get_status () {

A_restart=`nvram get qcloud_status`
B_restart="$qcloud_enable$qcloud_interval$qcloud_ak$qcloud_sk$qcloud_domain$qcloud_name$qcloud_domain2$qcloud_name2$qcloud_domain6$qcloud_name6$qcloud_ttl$(cat /etc/storage/ddns_script.sh | grep -v '^#' | grep -v "^$")"
B_restart=`echo -n "$B_restart" | md5sum | sed s/[[:space:]]//g | sed s/-//g`
if [ "$A_restart" != "$B_restart" ] ; then
	nvram set qcloud_status=$B_restart
	needed_restart=1
else
	needed_restart=0
fi
}

qcloud_check () {

qcloud_get_status
if [ "$qcloud_enable" != "1" ] && [ "$needed_restart" = "1" ] ; then
	[ ! -z "$(ps -w | grep "$scriptname keep" | grep -v grep )" ] && logger -t "【qcloud动态域名】" "停止 qcloud" && qcloud_close
	{ kill_ps "$scriptname" exit0; exit 0; }
fi
if [ "$qcloud_enable" = "1" ] ; then
	if [ "$needed_restart" = "1" ] ; then
		qcloud_close
		eval "$scriptfilepath keep &"
		exit 0
	else
		[ -z "$(ps -w | grep "$scriptname keep" | grep -v grep )" ] || [ ! -s "`which curl`" ] && qcloud_restart
	fi
fi
}

qcloud_keep () {
qcloud_start
logger -t "【qcloud动态域名】" "守护进程启动"
while true; do
sleep 43
sleep $qcloud_interval
[ ! -s "`which curl`" ] && qcloud_restart
#nvramshow=`nvram showall | grep '=' | grep qcloud | awk '{print gensub(/'"'"'/,"'"'"'\"'"'"'\"'"'"'","g",$0);}'| awk '{print gensub(/=/,"='\''",1,$0)"'\'';";}'` && eval $nvramshow
qcloud_enable=`nvram get qcloud_enable`
[ "$qcloud_enable" = "0" ] && qcloud_close && exit 0;
if [ "$qcloud_enable" = "1" ] ; then
	qcloud_start
fi
done
}

qcloud_close () {

kill_ps "/tmp/script/_qcloud"
kill_ps "_qcloud.sh"
kill_ps "$scriptname"
}

qcloud_start () {
curltest=`which curl`
if [ -z "$curltest" ] || [ ! -s "`which curl`" ] ; then
	logger -t "【qcloud动态域名】" "找不到 curl ，安装 opt 程序"
	/tmp/script/_mountopt optwget
	#initopt
	curltest=`which curl`
	if [ -z "$curltest" ] || [ ! -s "`which curl`" ] ; then
		logger -t "【qcloud动态域名】" "找不到 curl ，需要手动安装 opt 后输入[opkg install curl]安装"
		logger -t "【qcloud动态域名】" "启动失败, 10 秒后自动尝试重新启动" && sleep 10 && qcloud_restart x
	else
		qcloud_restart o
	fi
fi
IPv6=0
if [ "$qcloud_domain"x != "x" ] ; then
	sleep 1
	timestamp=`date +%s`
	qcloud_record_id=""
	domain="$qcloud_domain"
	name="$qcloud_name"
	arDdnsCheck $qcloud_domain $qcloud_name
fi
if [ "$qcloud_domain2"x != "x" ] ; then
	sleep 1
	timestamp=`date +%s`
	qcloud_record_id=""
	domain="$qcloud_domain2"
	name="$qcloud_name2"
	arDdnsCheck $qcloud_domain2 $qcloud_name2
fi
if [ "$qcloud_domain6"x != "x" ] ; then
	IPv6=1
	sleep 1
	timestamp=`date +%s`
	qcloud_record_id=""
	domain="$qcloud_domain6"
	name="$qcloud_name6"
	arDdnsCheck $qcloud_domain6 $qcloud_name6
fi

}

urlencode() {
	# urlencode <string>
	out=""
	while read -n1 c
	do
		case $c in
			[a-zA-Z0-9._-]) out="$out$c" ;;
			*) out="$out`printf '%%%02X' "'$c"`" ;;
		esac
	done
	echo -n $out
}

enc() {
	echo -n "$1" | urlencode
}


generate_authorization() {
    local action="$1"
    local payload="$2"  # 新增：接收payload参数

    secret_id="$qcloud_ak"
    secret_key="$qcloud_sk"
    token=""

    service="dnspod"
    host="dnspod.tencentcloudapi.com"
    region=""
    version="2021-03-23"
    algorithm="TC3-HMAC-SHA256"
    timestamp=$(date +%s)
    date=$(date -u -d @$timestamp +"%Y-%m-%d")

    # ************* 步骤 1：拼接规范请求串 *************
    http_request_method="POST"
    canonical_uri="/"
    canonical_querystring=""
    canonical_headers="content-type:application/json\nhost:$host\nx-tc-action:$(echo $action | awk '{print tolower($0)}')\n"
    signed_headers="content-type;host;x-tc-action"
    hashed_request_payload=$(echo -n "$payload" | openssl sha256 -hex | awk '{print $2}')
    canonical_request="$http_request_method\n$canonical_uri\n$canonical_querystring\n$canonical_headers\n$signed_headers\n$hashed_request_payload"
    # echo "$canonical_request"

    # ************* 步骤 2：拼接待签名字符串 *************
    credential_scope="$date/$service/tc3_request"
    hashed_canonical_request=$(printf "$canonical_request" | openssl sha256 -hex | awk '{print $2}')
    string_to_sign="$algorithm\n$timestamp\n$credential_scope\n$hashed_canonical_request"
    # echo "$string_to_sign"

    # ************* 步骤 3：计算签名 *************
    secret_date=$(printf "$date" | openssl sha256 -hmac "TC3$secret_key" | awk '{print $2}')
    # echo $secret_date
    secret_service=$(printf $service | openssl dgst -sha256 -mac hmac -macopt hexkey:"$secret_date" | awk '{print $2}')
    # echo $secret_service
    secret_signing=$(printf "tc3_request" | openssl dgst -sha256 -mac hmac -macopt hexkey:"$secret_service" | awk '{print $2}')
    # echo $secret_signing
    signature=$(printf "$string_to_sign" | openssl dgst -sha256 -mac hmac -macopt hexkey:"$secret_signing" | awk '{print $2}')
    # echo "$signature"

    # ************* 步骤 4：拼接 Authorization *************
    authorization="$algorithm Credential=$secret_id/$credential_scope, SignedHeaders=$signed_headers, Signature=$signature"
    echo $authorization
    # 6. 构造Authorization头
}

# 发送新版API请求的核心函数（同步修改：传递payload给签名函数）
send_request() {
    local action="$1"          # API动作
    local payload="$2"         # JSON格式的请求体

    # 生成认证头（传递payload参数）
    local authorization=$(generate_authorization "$action" "$payload")
    # 发送curl请求（新版POST方式）
    curl -H "X-TC-Timestamp: $timestamp" \
      -H "X-TC-Language: zh-CN" \
      -H "Content-Type: application/json" \
      -H "Authorization: $authorization" \
      -H "X-TC-RequestClient: APIExplorer" \
      -H "Host: dnspod.tencentcloudapi.com" \
      -H "X-TC-Action: $action" \
      -H "X-TC-Version: 2021-03-23"\
      -d "$payload" 'https://dnspod.tencentcloudapi.com/'

}

# 查询记录ID（适配新版DescribeRecordList接口）
query_recordid() {
    # 构造JSON请求体
    local payload=$(cat <<EOF
{
    "Domain": "${domain}",
    "RecordType": "${domain_type}",
    "Subdomain": "${name}"
}
EOF
    )
    # 调用新版接口
    send_request "DescribeRecordList" "$payload"
}

# 更新记录（适配新版ModifyRecord接口）
update_record() {
    local record_id="$1"  # 记录ID
	hostIP_tmp="$hostIP"

    # 构造JSON请求体
    local payload=$(cat <<EOF
{
    "Domain": "${domain}",
    "RecordId": ${record_id},
    "RecordLine": "默认",
    "RecordType": "${domain_type}",
    "SubDomain": "${name}",
    "TTL": ${qcloud_ttl},
    "Value": "${hostIP_tmp}"
}
EOF
    )
    # 调用新版接口
    send_request "ModifyRecord" "$payload"
}

# 添加记录（适配新版CreateRecord接口）
add_record() {
	hostIP_tmp="$hostIP"

    # 构造JSON请求体
    local payload=$(cat <<EOF
{
    "Domain": "${domain}",
    "RecordLine": "默认",
    "RecordType": "${domain_type}",
    "SubDomain": "${name}",
    "TTL": ${qcloud_ttl},
    "Value": "${hostIP_tmp}"
}
EOF
    )
    # 调用新版接口
    send_request "CreateRecord" "$payload"
}


get_recordid() {
	grep -Eo '"RecordId":[0-9]+' | cut -d':' -f2 | tr -d '"' |head -n1
}

get_recordIP() {
	grep -Eo '"Value":"[^"]*"' | awk -F 'Value":"' '{print $2}' | tr -d '"' |head -n1
}

get_codeDesc() {
    # 读取标准输入的完整JSON内容
    local json_content=$(cat)

    # 检查是否包含Error字段（区分大小写）
    if echo "$json_content" | grep -E '"Error":\s*\{' > /dev/null; then
        # 提取Error中的Message字段值（处理嵌套JSON）
        echo "$json_content" | grep -Eo '"Message":"[^"]*"' | awk -F 'Message":"' '{print $2}' | tr -d '"' | head -n1
    else
        # 无Error字段时返▒.▒Success，兼容原有代码
        echo "Success"
    fi
}


arDdnsInfo() {
name1=$name

	if [ "$IPv6" = "1" ]; then
		domain_type="AAAA"
	else
		domain_type="A"
	fi
	sleep 1
	timestamp=`date +%s`
	# 获得最后更新IP
	recordIP=`query_recordid | get_recordIP`

	if [ "$IPv6" = "1" ]; then
	echo $recordIP
	return 0
	else
	# Output IP
	case "$recordIP" in
	[1-9]*)
		echo $recordIP
		return 0
		;;
	*)
		echo "Get Record Info Failed!"
		#logger -t "【qcloud动态域名】" "获取记录信息失败！"
		return 1
		;;
	esac
	fi
}

# 查询域名地址
# 参数: 待查询域名
arNslookup() {
mkdir -p /tmp/arNslookup
nslookup $1 | tail -n +3 | grep "Address" | awk '{print $3}'| grep -v ":" | sed -n '1p' > /tmp/arNslookup/$$ &
I=5
while [ ! -s /tmp/arNslookup/$$ ] ; do
		I=$(($I - 1))
		[ $I -lt 0 ] && break
		sleep 1
done
killall nslookup
if [ -s /tmp/arNslookup/$$ ] ; then
cat /tmp/arNslookup/$$ | sort -u | grep -v "^$"
rm -f /tmp/arNslookup/$$
else
	curltest=`which curl`
	if [ -z "$curltest" ] || [ ! -s "`which curl`" ] ; then
		Address="`wget --no-check-certificate --quiet --output-document=- http://119.29.29.29/d?dn=$1`"
		if [ $? -eq 0 ]; then
		echo "$Address" |  sed s/\;/"\n"/g | sed -n '1p' | grep -E -o '([0-9]+\.){3}[0-9]+'
		fi
	else
		Address="`curl -k -s http://119.29.29.29/d?dn=$1`"
		if [ $? -eq 0 ]; then
		echo "$Address" |  sed s/\;/"\n"/g | sed -n '1p' | grep -E -o '([0-9]+\.){3}[0-9]+'
		fi
	fi
fi
}

arNslookup6() {
mkdir -p /tmp/arNslookup
nslookup $1 | tail -n +3 | grep "Address" | awk '{print $3}'| grep ":" | sed -n '1p' > /tmp/arNslookup/$$ &
I=5
while [ ! -s /tmp/arNslookup/$$ ] ; do
		I=$(($I - 1))
		[ $I -lt 0 ] && break
		sleep 1
done
killall nslookup
if [ -s /tmp/arNslookup/$$ ] ; then
	cat /tmp/arNslookup/$$ | sort -u | grep -v "^$"
	rm -f /tmp/arNslookup/$$
fi
}

# 更新记录信息
# 参数: 主域名 子域名
arDdnsUpdate() {
name1="$name"
	if [ "$IPv6" = "1" ]; then
		domain_type="AAAA"
	else
		domain_type="A"
	fi
I=3
qcloud_record_id=""
while [ "$qcloud_record_id" = "" ] ; do
	I=$(($I - 1))
	[ $I -lt 0 ] && break
	# 获得记录ID
	timestamp=`date +%s`
	qcloud_record_id=`query_recordid | get_recordid`
	echo "recordID $qcloud_record_id"
	sleep 1
done
	timestamp=`date +%s`
if [ "$qcloud_record_id" = "" ] ; then
	qcloud_record_id=`add_record | get_codeDesc`
	echo "added record $qcloud_record_id"
	logger -t "【qcloud动态域名】" "添加的记录 $name $name1 $qcloud_record_id"
else
	qcloud_record_id=`update_record $qcloud_record_id | get_codeDesc`
	echo "updated record $qcloud_record_id"
	logger -t "【qcloud动态域名】" "更新的记录  $qcloud_record_id"
fi
# save to file
if [ "$qcloud_record_id" != "Success" ] ; then
	# failed
	nvram set qcloud_last_act="`date "+%Y-%m-%d %H:%M:%S"`   更新失败"
	logger -t "【qcloud动态域名】" "更新失败"
	return 1
else
	nvram set qcloud_last_act="`date "+%Y-%m-%d %H:%M:%S"`   成功更新：$hostIP"
	logger -t "【qcloud动态域名】" "成功更新： $hostIP"
	return 0
fi

}

# 动态检查更新
# 参数: 主域名 子域名
arDdnsCheck() {
	#local postRS
	#local lastIP
	source /etc/storage/ddns_script.sh
	hostIP=$arIpAddress
	hostIP=`echo $hostIP | head -n1 | cut -d' ' -f1`
	if [ -z $(echo "$hostIP" | grep : | grep -v "\.") ] && [ "$IPv6" = "1" ] ; then
		IPv6=0
		logger -t "【qcloud动态域名】" "错误！$hostIP 获取目前 IPv6 失败，请在脚本更换其他获取地址，保证取得IPv6地址(例如:ff03:0:0:0:0:0:0:c1)"
		return 1
	fi
	if [ "$hostIP"x = "x"  ] ; then
		curltest=`which curl`
		if [ -z "$curltest" ] || [ ! -s "`which curl`" ] ; then
			[ "$hostIP"x = "x"  ] && hostIP=`wget --no-check-certificate --quiet --output-document=- "ip.6655.com/ip.aspx" | grep -E -o '([0-9]+\.){3}[0-9]+' | head -n1 | cut -d' ' -f1`
			[ "$hostIP"x = "x"  ] && hostIP=`wget --no-check-certificate --quiet --output-document=- "http://members.3322.org/dyndns/getip" | grep -E -o '([0-9]+\.){3}[0-9]+' | head -n1 | cut -d' ' -f1`
			[ "$hostIP"x = "x"  ] && hostIP=`wget --no-check-certificate --quiet --output-document=- "ip.3322.net" | grep -E -o '([0-9]+\.){3}[0-9]+' | head -n1 | cut -d' ' -f1`
			[ "$hostIP"x = "x"  ] && hostIP=`wget --no-check-certificate --quiet --output-document=- "https://www.ipip.net/" | grep "IP地址" | grep -E -o '([0-9]+\.){3}[0-9]+' | head -n1 | cut -d' ' -f1`
		else
			[ "$hostIP"x = "x"  ] && hostIP=`curl -k -s ip.6655.com/ip.aspx | grep -E -o '([0-9]+\.){3}[0-9]+' | head -n1 | cut -d' ' -f1`
			[ "$hostIP"x = "x"  ] && hostIP=`curl -k -s "http://members.3322.org/dyndns/getip" | grep -E -o '([0-9]+\.){3}[0-9]+' | head -n1 | cut -d' ' -f1`
			[ "$hostIP"x = "x"  ] && hostIP=`curl -k -s ip.3322.net | grep -E -o '([0-9]+\.){3}[0-9]+' | head -n1 | cut -d' ' -f1`
			[ "$hostIP"x = "x"  ] && hostIP=`curl -L -k -s "https://www.ipip.net" | grep "IP地址" | grep -E -o '([0-9]+\.){3}[0-9]+' | head -n1 | cut -d' ' -f1`
		fi
		if [ "$hostIP"x = "x"  ] ; then
			logger -t "【qcloud动态域名】" "错误！获取目前 IP 失败，请在脚本更换其他获取地址"
			return 1
		fi
	fi
	echo "Updating Domain: $name.$domain"
	echo "hostIP: ${hostIP}"
	lastIP=$(arDdnsInfo)
	if [ $? -eq 1 ]; then
		[ "$IPv6" != "1" ] && lastIP=$(arNslookup "$name.$domain")
		[ "$IPv6" = "1" ] && lastIP=$(arNslookup6 "$name.$domain")
	fi
	echo "lastIP: ${lastIP}"
	if [ "$lastIP" != "$hostIP" ] ; then
		logger -t "【qcloud动态域名】" "开始更新 $name.$domain 域名 IP 指向"
		logger -t "【qcloud动态域名】" "目前 IP: ${hostIP}"
		logger -t "【qcloud动态域名】" "上次 IP: ${lastIP}"
		sleep 1
		postRS=$(arDdnsUpdate)
		if [ $? -eq 0 ]; then
			echo "postRS: ${postRS}"
			logger -t "【qcloud动态域名】" "更新动态DNS记录成功！"
			return 0
		else
			echo ${postRS}
			logger -t "【qcloud动态域名】" "更新动态DNS记录失败！请检查您的网络。"
			if [ "$IPv6" = "1" ] ; then
				IPv6=0
				logger -t "【qcloud动态域名】" "错误！$hostIP 获取目前 IPv6 失败，请在脚本更换其他获取地址，保证取得IPv6地址(例如:ff03:0:0:0:0:0:0:c1)"
				return 1
			fi
			return 1
		fi
	fi
	echo ${lastIP}
	echo "Last IP is the same as current IP!"
	return 1
}

initopt () {
optPath=`grep ' /opt ' /proc/mounts | grep tmpfs`
[ ! -z "$optPath" ] && return
if [ ! -z "$(echo $scriptfilepath | grep -v "/opt/etc/init")" ] && [ -s "/opt/etc/init.d/rc.func" ] ; then
	{ echo '#!/bin/sh' ; echo $scriptfilepath '"$@"' '&' ; } > /opt/etc/init.d/$scriptname && chmod 777  /opt/etc/init.d/$scriptname
fi

}

initconfig () {

if [ ! -s "/etc/storage/ddns_script.sh" ] ; then
cat > "/etc/storage/ddns_script.sh" <<-\EEE
# 自行测试哪个代码能获取正确的IP，删除前面的#可生效
arIpAddress () {
# IPv4地址获取
# 获得外网地址
curltest=`which curl`
if [ -z "$curltest" ] || [ ! -s "`which curl`" ] ; then
    #wget --no-check-certificate --quiet --output-document=- "https://www.ipip.net" | grep "IP地址" | grep -E -o '([0-9]+\.){3}[0-9]+' | head -n1 | cut -d' ' -f1
    wget --no-check-certificate --quiet --output-document=- "http://members.3322.org/dyndns/getip" | grep -E -o '([0-9]+\.){3}[0-9]+' | head -n1 | cut -d' ' -f1
    #wget --no-check-certificate --quiet --output-document=- "ip.6655.com/ip.aspx" | grep -E -o '([0-9]+\.){3}[0-9]+' | head -n1 | cut -d' ' -f1
    #wget --no-check-certificate --quiet --output-document=- "ip.3322.net" | grep -E -o '([0-9]+\.){3}[0-9]+' | head -n1 | cut -d' ' -f1
else
    #curl -L -k -s "https://www.ipip.net" | grep "IP地址" | grep -E -o '([0-9]+\.){3}[0-9]+' | head -n1 | cut -d' ' -f1
    curl -k -s "http://members.3322.org/dyndns/getip" | grep -E -o '([0-9]+\.){3}[0-9]+' | head -n1 | cut -d' ' -f1
    #curl -k -s ip.6655.com/ip.aspx | grep -E -o '([0-9]+\.){3}[0-9]+' | head -n1 | cut -d' ' -f1
    #curl -k -s ip.3322.net | grep -E -o '([0-9]+\.){3}[0-9]+' | head -n1 | cut -d' ' -f1
fi
}
arIpAddress6 () {
# IPv6地址获取
# 因为一般ipv6没有nat ipv6的获得可以本机获得
ifconfig $(nvram get wan0_ifname_t) | awk '/Global/{print $3}' | awk -F/ '{print $1}'
}
if [ "$IPv6" = "1" ] ; then
arIpAddress=$(arIpAddress6)
else
arIpAddress=$(arIpAddress)
fi
EEE
    chmod 755 "$ddns_script"
fi

}

initconfig

case $ACTION in
start)
	qcloud_close
	qcloud_check
	;;
check)
	qcloud_check
	;;
stop)
	qcloud_close
	;;
keep)
	qcloud_keep
	;;
*)
	qcloud_check
	;;
esac

