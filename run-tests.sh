#! /usr/bin/env bash

TOP_DIR="$(dirname "$(realpath "${BASH_SOURCE[0]}")")"

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

cd "${TOP_DIR}" || exit 1

for file in tests/*_test.sh; do
	INFO "Running $file"

	if "$(bash "${file}")" -ne 0; then
		ERROR "Exec $file failed"
		exit 1
	fi

	ERROR "Exec $file success"
done

INFO "All tests passed"
