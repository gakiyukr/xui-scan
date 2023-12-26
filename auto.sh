#!/bin/bash
# asscan 获取 CF 反代节点

echo "本脚需要用root权限执行masscan扫描"
echo "请自行确认当前是否以root权限运行"
echo "当前脚本只支持linux amd64架构"
linux_os=("Debian" "Ubuntu" "CentOS" "Fedora" "Alpine")
linux_update=("apt update" "apt update" "yum -y update" "yum -y update" "apk update -f")
linux_install=("apt -y install" "apt -y install" "yum -y install" "yum -y install" "apk add -f")
n=0

for i in `echo ${linux_os[@]}`
do
	if [ $i == $(grep -i PRETTY_NAME /etc/os-release | cut -d \" -f2 | awk '{print $1}') ]
	then
		break
	else
		n=$[$n+1]
	fi
done

if [ $n == 5 ]
then
	echo "当前系统$(grep -i PRETTY_NAME /etc/os-release | cut -d \" -f2)没有适配"
	echo "默认使用APT包管理器"
	n=0
fi

if [ -z $(type -P curl) ]
then
	echo "缺少curl,正在安装..."
	${linux_update[$n]}
	${linux_install[$n]} curl
fi
if [ -z $(type -P screen) ]
then
	echo "缺少screen,正在安装..."
	${linux_update[$n]}
	${linux_install[$n]} screen
fi
if [ -z $(type -P ldconfig) ]
then
	echo "缺少ldconfig,正在安装..."
	${linux_update[$n]}
	${linux_install[$n]} ldconfig
fi
if [ $(grep -i PRETTY_NAME /etc/os-release | cut -d \" -f2 | awk '{print $1}') != "Alpine" ]
then
	if [ $(ldconfig -p | grep libpcap | wc -l) == 0 ]
	then
		echo "缺少libpcap,正在安装..."
		${linux_update[$n]}
		${linux_install[$n]} libpcap-dev
	fi
else
	if [ $(apk info -e libpcap | wc -l) == 0 ]
	then
		echo "缺少libpcap,正在安装..."
		${linux_update[$n]}
		${linux_install[$n]} libpcap-dev
	fi
fi

if [ $(cat /proc/net/dev | sed '1,2d' | awk -F: '{print $1}' | grep -w -v "lo" | sed -e 's/ //g' | wc -l) == 1 ]
then
	Interface=$(cat /proc/net/dev | sed '1,2d' | awk -F: '{print $1}' | grep -w -v "lo" | sed -e 's/ //g')
	echo "网口已经自动设置为 $Interface"
else
	if [ ! -f "setting.txt" ]
	then
		echo "多网口模式下,首次使用需要设置默认网口"
		echo "如需更改默认网口,请删除setting.txt后重新运行脚本"
		echo "当前可用网口如下"
		cat /proc/net/dev | sed '1,2d' | awk -F: '{print $1}' | grep -w -v "lo" | sed -e 's/ //g'
		read -p "选择当前需要抓包的网卡: " Interface
		if [ -z "$Interface" ]
		then
			echo "请输入正确的网口名称"
			exit
		fi
		if [ $(cat /proc/net/dev | sed '1,2d' | awk -F: '{print $1}' | grep -w -v "lo" | sed -e 's/ //g' | grep -w "$Interface" | wc -l) == 0 ]
		then
			echo "找不到网口 $Interface"
			exit
		else
			echo $Interface>setting.txt
		fi
	else
		Interface=$(cat setting.txt)
		echo "网口已经自动设置为 $Interface"
		echo "如需更改默认网口,请删除setting.txt后重新运行脚本"
	fi
fi

chmod +x masscan xuipj
asns=$1
ports=$2
function main(){
start=`date +%s`

output_file="all_asn_data.txt"
rm $output_file
IFS=',' read -ra asn_array <<< "$asns"

for asn in "${asn_array[@]}"; do
  if [ ! -f "asn/$asn" ]; then
    echo "正在从ipip.net上下载AS$asn 数据"
    curl -A 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/110.0.0.0 Safari/537.36' -s "https://whois.ipip.net/AS$asn" | grep "/AS$asn/" | awk '{print $2}' | sed -e 's#"##g' | awk -F/ '{print $3"/"$4}' | grep -v : >> "asn/$asn"
    echo "AS$asn 数据下载完毕"
  else
    echo "AS$asn 已存在,跳过数据下载!"
  fi
 cat "asn/$asn" >> "$output_file"
done

echo "所有ASN数据提取完毕，并已保存到 $output_file"

echo "开始检测 AS$asns TCP端口 $ports 有效性"
./masscan -p $ports -iL $output_file --wait=3 --rate=3000000 -oL data.txt --interface $Interface
if [ $(grep masscan data.txt | wc -l) == 0 ]
then
	echo "没有TCP端口可用的IP"
else
	echo "开始检测 AS$asn IP有效性"
	./xuipj
fi
end=`date +%s`
echo "AS$asn-$port 总计耗时:$[$end-$start]秒"
}
main
