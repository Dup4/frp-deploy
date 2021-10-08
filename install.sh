#! /usr/bin/env bash

OS_CENTOS="CentOS"
OS_DEBIAN="Debian"
OS_UBUNTU="Ubuntu"
OS_FEDORA="Fedora"

ERROR_MSG_MUST_ROOT="This script must be run as root!"
ERROR_MSG_SUPPORT_OS="This script only supports CentOS 6,7 or Debian or Ubuntu or Fedor!"
ERROR_MSG_NEED_WGET="This script requires wget to run!"
ERROR_MSG_DOWNLOAD_FAILED="download frp failed."
ERROR_MSG_SUPPORT_INSTALL_OPTS="only support frpc or frps."

function get_now_time() {
	if [[ "$(uname)" == "Darwin" ]]; then
		NOW_TIME=$(date)
	else
		# https://unix.stackexchange.com/questions/120484/what-is-a-standard-command-for-printing-a-date-in-rfc-3339-format
		NOW_TIME=$(date --rfc-3339=ns | sed 's/ /T/; s/\(\....\).*\([+-]\)/\1\2/g')
	fi

	echo "${NOW_TIME}"
}

function INFO() {
	echo -e "\033[0;32m$(get_now_time) [INFO]: $*\033[0m"
}

function ERROR() {
	echo -e "\033[0;31m$(get_now_time) [ERROR]: $*\033[0m"
}

# Check if user is root
check_root() {
	sudo su
	if [[ $EUID -ne 0 ]]; then
		ERROR "${ERROR_MSG_MUST_ROOT}"
		exit 1
	fi
}

# Check OS
check_os() {
	if grep -Eqi ${OS_CENTOS} /etc/issue || grep -Eq ${OS_CENTOS} /etc/*-release; then
		OS=${OS_CENTOS}
	elif grep -Eqi ${OS_DEBIAN} /etc/issue || grep -Eq ${OS_DEBIAN} /etc/*-release; then
		OS=${OS_DEBIAN}
	elif grep -Eqi ${OS_UBUNTU} /etc/issue || grep -Eq ${OS_UBUNTU} /etc/*-release; then
		OS=${OS_UBUNTU}
	elif grep -Eqi ${OS_FEDORA} /etc/issue || grep -Eq ${OS_FEDORA} /etc/*-release; then
		OS=${OS_FEDORA}
	else
		ERROR "${ERROR_MSG_SUPPORT_OS}"
		exit 1
	fi
}

# Check OS bit
check_os_bit() {
	ARCHS=""

	if [[ $(getconf WORD_BIT) = '32' && $(getconf LONG_BIT) = '64' ]]; then
		is_64bit='y'
		ARCHS="amd64"
	else
		# shellcheck disable=SC2034
		is_64bit='n'
		ARCHS="386"
	fi
}

# Get version
get_version() {
	if [[ -s /etc/redhat-release ]]; then
		grep -oE "[0-9.]+" /etc/redhat-release
	else
		grep -oE "[0-9.]+" /etc/issue
	fi
}

# CentOS version
is_centos_version() {
	local code=$1

	local version
	version="$(get_version)"

	local main_ver=${version%%.*}

	if [ "$main_ver" == "$code" ]; then
		return 0
	else
		return 1
	fi
}

check_centos_version() {
	if is_centos_version 5; then
		ERROR "${ERROR_MSG_SUPPORT_OS}"
		exit 1
	fi
}

check_wget() {
	if [[ ! -x "wget" ]]; then
		ERROR "${ERROR_MSG_NEED_WGET}"
		exit 1
	fi
}

get_latest_frp_version() {
	FRP_LATEST_VERSION=$(wget -qO- -t1 -T2 "https://api.github.com/repos/fatedier/frp/releases/latest" | grep "tag_name" | head -n 1 | awk -F ":" '{print $2}' | sed 's/\"//g;s/,//g;s/ //g')
	INFO "frp latest version: ${FRP_LATEST_VERSION}"
}

clean() {
	if [[ -d "./${PACKAGE_NAME}" ]]; then
		rm -rf "./${PACKAGE_NAME}"
	fi

	if [[ -f "./${BINARY_PACKAGE_NAME}" ]]; then
		rm -rf "./${BINARY_PACKAGE_NAME}"
	fi
}

download_frp() {
	PACKAGE_NAME="frp_${FRP_LATEST_VERSION:1}_${OS}_${ARCHS}"
	BINARY_PACKAGE_NAME="${PACKAGE_NAME}.tar.gz"
	BINARY_PACKAGE_DOWNLOAD_URL="${DOWNLOAD_URL}/${FRP_LATEST_VERSION}/BINARY_PACKAGE_NAME"

	clean

	INFO "download frp from ${BINARY_PACKAGE_DOWNLOAD_URL}"

	if ! wget -q "${BINARY_PACKAGE_DOWNLOAD_URL}" -O "./${BINARY_PACKAGE_NAME}"; then
		ERROR "${ERROR_MSG_DOWNLOAD_FAILED}"
		exit 1
	fi

	tar zxf "./${BINARY_PACKAGE_NAME}"

	INFO "download frp success"
}

install_frpc() {
	cd "./${PACKAGE_NAME}" || exit 1

	cp -f frps /usr/bin/frpc

	if [[ ! -f "/etc/frp/frpc.ini" ]]; then
		cp frpc.ini /etc/frp/frpc.ini
	fi

	cp -f ./systemd/frpc.service /lib/systemd/system/frpc.service
	sudo systemctl daemon-reload
	sudo systemctl enable frpc
	sudo systemctl start frpc

	INFO "install frpc success"
	INFO "you can modify frpc.ini from /etc/frp/frpc.ini"
}

install_frps() {
	cd "./${PACKAGE_NAME}" || exit 1

	cp -f frps /usr/bin/frps

	if [[ ! -f "/etc/frp/frps.ini" ]]; then
		cp frps.ini /etc/frp/frps.ini
	fi

	sudo cp -f ./systemd/frps.service /lib/systemd/system/frps.service
	sudo systemctl daemon-reload
	sudo systemctl enable frps
	sudo systemctl start frps

	INFO "install frps success"
	INFO "you can modify frps.ini from /etc/frp/frps.ini"
}

GITHUB_HOST="github.com"
DOWNLOAD_URL="https://${GITHUB_HOST}/fatedier/frp/releases/download"

while getopts ":p:i:" o; do
	case "${o}" in
	p)
		GITHUB_HOST=${OPTARG}
		;;
	i | *)
		i=${OPTARG}
		;;
	esac
done

if [[ ${i} != "frpc" && ${i} != "frps" ]]; then
	ERROR "${ERROR_MSG_SUPPORT_INSTALL_OPTS}"
	exit 1
fi

check_root
check_os

if [[ ${OS} = "${OS_CENTOS}" ]]; then
	check_centos_version
fi

check_wget

get_latest_frp_version
download_frp

if [[ ${i} == "frpc" ]]; then
	install_frpc
elif [[ ${i} == "frps" ]]; then
	install_frps
fi

clean
