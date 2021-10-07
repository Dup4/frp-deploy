#! /usr/bin/env bash

function get_now_time() {
	if [[ "$(uname)" == "${OS_MACOS}" ]]; then
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

uninstall_frpc() {
	sudo systemctl stop frpc
	sudo systemctl disable frpc
	sudo systemctl daemon-reload

	if [[ -x "/usr/bin/frpc" ]]; then
		rm -rf "/usr/bin/frpc"
	fi

	INFO "uninstall frpc success"
}

uninstall_frps() {
	sudo systemctl stop frps
	sudo systemctl disable frps
	sudo systemctl daemon-reload

	if [[ -x "/usr/bin/frps" ]]; then
		rm -rf "/usr/bin/frps"
	fi

	INFO "uninstall frps success"
}

while getopts ":i:" o; do
	case "${o}" in
	i | *)
		i=${OPTARG}
		;;
	esac
done

if [[ ${i} != "frpc" && ${i} != "frps" ]]; then
	ERROR "${ERROR_MSG_SUPPORT_INSTALL_OPTS}"
fi

if [[ ${i} == "frpc" ]]; then
	uninstall_frpc
elif [[ ${i} == "frps" ]]; then
	uninstall_frps
fi
