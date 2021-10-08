#! /usr/bin/env bash

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
		is_root='n'
	fi
}

uninstall() {
	PACKAGE="${1}"

	if [[ "${is_root}" = "y" ]]; then
		systemctl stop "${PACKAGE}"
		systemctl disable "${PACKAGE}"
		systemctl daemon-reload

		if [[ -f /lib/systemd/system/"${PACKAGE}".service ]]; then
			rm -rf /lib/systemd/system/"${PACKAGE}".service
		fi
	else
		systemctl --user stop "${PACKAGE}"
		systemctl --user disable "${PACKAGE}"
		systemctl --user daemon-reload

		if [[ -f ~/.config/systemd/user/"${PACKAGE}".service ]]; then
			rm -rf ~/.config/systemd/user/"${PACKAGE}".service
		fi
	fi

	if [[ -x "/usr/bin/${PACKAGE}" ]]; then
		rm -rf "/usr/bin/${PACKAGE:?}"
	fi

	INFO "uninstall ${PACKAGE} success"
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

check_root

uninstall "${i}"
