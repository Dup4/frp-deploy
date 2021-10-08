#! /usr/bin/env bash

OS_CENTOS="CentOS"
OS_DEBIAN="Debian"
OS_UBUNTU="Ubuntu"
OS_FEDORA="Fedora"

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

check_root() {
	is_root='y'
	if [[ $EUID -ne 0 ]]; then
		# shellcheck disable=SC2034
		is_root='n'
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

	case "$(uname -i)" in
	x86)
		ARCHS="386"
		;;
	x86_64)
		ARCHS="amd64"
		;;
	aarch | aarch32)
		ARCHS="arm"
		;;
	aarch64)
		ARCHS="arm64"
		;;
	mips)
		ARCHS="mips"
		;;
	mips64)
		ARCHS="mips64"
		;;
	*)
		ERROR "$(uname -i) is unsupport"
		exit 1
		;;
	esac
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
	if [ -z "$(which wget)" ]; then
		ERROR "${ERROR_MSG_NEED_WGET}"
		exit 1
	fi
}

get_latest_frp_version() {
	local FRP_LATEST_VERSION
	FRP_LATEST_VERSION=$(wget -qO- -t1 -T2 "https://api.github.com/repos/fatedier/frp/releases/latest" | grep "tag_name" | head -n 1 | awk -F ":" '{print $2}' | sed 's/\"//g;s/,//g;s/ //g')

	echo "${FRP_LATEST_VERSION:1}"
}

clean() {
	if [[ -d "/tmp/${PACKAGE_NAME}" ]]; then
		sudo rm -rf "/tmp/${PACKAGE_NAME}"
	fi

	if [[ -f "/tmp/${BINARY_PACKAGE_NAME}" ]]; then
		sudo rm -rf "/tmp/${BINARY_PACKAGE_NAME}"
	fi
}

check_exist_frp() {
	local PACKAGE="${1}"

	if [[ -n "$(which "${PACKAGE}")" ]]; then
		local FRP_NOW_VERSION
		FRP_NOW_VERSION="$(${PACKAGE} -v)"

		INFO "${PACKAGE} already exists, the version is v${FRP_NOW_VERSION}"
		INFO "the expected version is v${FRP_VERSION}"

		if [[ "${FRP_NOW_VERSION}" = "${FRP_VERSION}" ]]; then
			INFO "The existing version is consistent with the expected version, the installation program will exit"
			exit 0
		fi

		if [[ "${ALL_Y}" = "n" ]]; then
			local IS_UPDATE
			IS_UPDATE='n'

			read -e -n 1 -r -p "do you need to change to the expected version? (y/n)" IS_UPDATE
			if [[ "${IS_UPDATE}" = "n" ]]; then
				exit 0
			fi
		fi
	fi
}

download_frp() {
	OS_PLATFORM="linux"

	DOWNLOAD_URL="https://${GITHUB_HOST}/fatedier/frp/releases/download"

	PACKAGE_NAME="frp_${FRP_VERSION}_${OS_PLATFORM}_${ARCHS}"
	BINARY_PACKAGE_NAME="${PACKAGE_NAME}.tar.gz"
	BINARY_PACKAGE_DOWNLOAD_URL="${DOWNLOAD_URL}/v${FRP_VERSION}/${BINARY_PACKAGE_NAME}"

	clean

	INFO "download frp from ${BINARY_PACKAGE_DOWNLOAD_URL}"

	if ! wget -q "${BINARY_PACKAGE_DOWNLOAD_URL}" -O "/tmp/${BINARY_PACKAGE_NAME}"; then
		ERROR "${ERROR_MSG_DOWNLOAD_FAILED}"
		exit 1
	fi

	tar -zxvf "/tmp/${BINARY_PACKAGE_NAME}" -C "/tmp/"

	INFO "download frp success"
}

install() {
	local PACKAGE="${1}"

	cd "/tmp/${PACKAGE_NAME}" || exit 1

	sudo cp -f "${PACKAGE}" /usr/bin/"${PACKAGE}"

	if [[ ! -d "/etc/frp" ]]; then
		sudo mkdir "/etc/frp"
	fi

	if [[ ! -f "/etc/frp/${PACKAGE}.ini" ]]; then
		sudo cp "${PACKAGE}".ini /etc/frp/"${PACKAGE}".ini
	fi

	sudo cp -f ./systemd/"${PACKAGE}".service /lib/systemd/system/"${PACKAGE}".service
	sudo systemctl daemon-reload
	sudo systemctl enable "${PACKAGE}"
	sudo systemctl start "${PACKAGE}"
	sudo systemctl status "${PACKAGE}"

	INFO "install ${PACKAGE} success"
	INFO "you can modify ${PACKAGE}.ini from /etc/frp/${PACKAGE}.ini"
	INFO "${PACKAGE} version: $(${PACKAGE} -v)"
}

GITHUB_HOST="github.com"
FRP_VERSION="LATEST"
ALL_Y='n'

while getopts "p:v:i:y" o; do
	case "${o}" in
	p)
		GITHUB_HOST=${OPTARG}
		;;
	v)
		FRP_VERSION=${OPTARG}
		;;
	y)
		ALL_Y='y'
		;;
	i | *)
		i=${OPTARG}
		;;
	esac
done

if [[ ${i} != "frpc" && ${i} != "frps" ]]; then
	ERROR "${ERROR_MSG_SUPPORT_INSTALL_OPTS} not support ${i}"
	exit 1
fi

check_root
check_os

if [[ ${OS} = "${OS_CENTOS}" ]]; then
	check_centos_version
fi

check_os_bit

check_wget

if [[ "${FRP_VERSION}" = "LATEST" ]]; then
	FRP_VERSION=$(get_latest_frp_version)
fi

check_exist_frp "${i}"

download_frp

install "${i}"

clean

exit 0
