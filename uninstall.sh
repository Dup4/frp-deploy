#! /usr/bin/env bash

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

uninstall() {
	PACKAGE="${1}"

	if [[ -z "$(which "${PACKAGE}")" ]]; then
		INFO "${PACKAGE} is not installed, the uninstaller will exit"
		exit 0
	fi

	BINARY_PACKAGE="$(which "${PACKAGE}")"

	INFO "the version of ${PACKAGE} is $(${BINARY_PACKAGE} -v)"

	sudo systemctl stop "${PACKAGE}"
	sudo systemctl disable "${PACKAGE}"
	sudo systemctl daemon-reload

	if [[ -f /lib/systemd/system/"${PACKAGE}".service ]]; then
		sudo rm -rf /lib/systemd/system/"${PACKAGE}".service
	fi

	sudo rm -rf "${BINARY_PACKAGE}"

	local IS_DELETE_CONFIGURATION_FILE
	IS_DELETE_CONFIGURATION_FILE='n'

	if [[ "${ALL_Y}" = "n" ]]; then
		read -e -n 1 -r -p "need to delete the configuration file? (y/n)" IS_DELETE_CONFIGURATION_FILE
	fi

	if [[ "${ALL_Y}" = 'y' || "${IS_DELETE_CONFIGURATION_FILE}" = 'y' ]]; then
		local CONFIGURATION_PATH="/etc/frp"
		local CONFIGURATION_FILE_PATH="${CONFIGURATION_PATH}/${PACKAGE}.ini"

		if [[ -f "${CONFIGURATION_FILE_PATH}" ]]; then
			sudo rm -rf "${CONFIGURATION_FILE_PATH}"
		fi

		if [[ -d "${CONFIGURATION_PATH}" ]]; then
			sudo rm -rf "${CONFIGURATION_PATH}"
		fi
	fi

	INFO "uninstall ${PACKAGE} success"
}

ALL_Y='n'

while getopts ":i:y" o; do
	case "${o}" in
	y)
		ALL_Y='y'
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

uninstall "${i}"

exit 0
