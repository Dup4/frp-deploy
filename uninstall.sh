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
		# shellcheck disable=SC2034
		is_root='n'
	fi
}

uninstall() {
	PACKAGE="${1}"

	sudo systemctl stop "${PACKAGE}"
	sudo systemctl disable "${PACKAGE}"
	sudo systemctl daemon-reload

	if [[ -f /lib/systemd/system/"${PACKAGE}".service ]]; then
		sudo rm -rf /lib/systemd/system/"${PACKAGE}".service
	fi

	if [[ -n "$(which "${PACKAGE}")" ]]; then
		sudo rm -rf "$(which "${PACKAGE}")"
	fi

	INFO "uninstall ${PACKAGE} success"
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

exit 0
